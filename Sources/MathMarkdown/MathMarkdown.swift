//
//  MathMarkdown.swift
//
//
//  Created by Peter Tang on 25/9/2023.
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import Markdown

public class MathMarkdown {
    private let original: String
    private let replaced: String
    public  let document: Document

    internal private(set) var latexEntries: [SourceRange: String] = [:]
    internal private(set) var imageEntries: [SourceRange: Extractor.ImageResource] = [:]
    private var rangeLookup: [String: SourceRange] = [:]
    
    public var fontSize: CGFloat = 10 {
        didSet {
            guard oldValue != fontSize else { return }
            invalidateString = true
        }
    }
    public var textColor: SwiftMathColor = .black {
        didSet {
            guard oldValue != textColor else { return }
            invalidateString = true
        }
    }
    
    open private(set) var attributedString: NSAttributedString = .init()
    private var invalidateString = true
    private(set) var completed: Bool = false
    
    public init (parsing markdown: String) {
        self.original = markdown
        let regexer = MathRegexer()
        let reformatedResult = regexer.reformat(inputString: markdown)
        let newMarkdown = reformatedResult.textStrings.joined()
        replaced = newMarkdown
        
        document = Document(parsing: newMarkdown, options: [.parseSymbolLinks])
        // print(document.debugDescription(options: .printEverything))
        
        var extractor = Extractor()
        extractor.visitDocument(document)
        let (latexEntries, imageEntries, rangeLookup) = extractor.convert(using: reformatedResult.latexExtracts)
        self.latexEntries = Dictionary(uniqueKeysWithValues: latexEntries)
        self.imageEntries = Dictionary(uniqueKeysWithValues: imageEntries)
        self.rangeLookup = rangeLookup
    }
    
    private var errorTable: [SourceRange: NSError] = [:]
    private var asyncReturns = 0
    private var totalTasks = 0
    
    public func loadImageCache(_ completion: ImageOpCompletion & ImageResourceLocator) async {

        let latexEntries = latexEntries.map { range, latex in (range.description, latex) }

        var remoteEntries: [(String, URL)] = []
        var bundleEntries: [(String, String)] = []
        for (range, entry) in imageEntries {
            switch entry {
            case .networkResource(url: let url):
                remoteEntries.append((range.description, url))
            case .localResource(fileName: let fileName):
                bundleEntries.append((range.description, fileName))
            }
        }
        
        asyncReturns = 0
        totalTasks = latexEntries.count + remoteEntries.count + bundleEntries.count
        
        let notification = ImageOp(mathMarkDown: self, count: totalTasks, completer: completion)

        ImageDataService.shared.latexImages(latexEntries, fontSize: fontSize, textColor: textColor,
                                            notify: notification)
        ImageDataService.shared.networkImages(remoteEntries,
                                              notify: notification)
        ImageDataService.shared.localImages(bundleEntries,
                                             notify: notification)
    }
    public func invalidateAttributedString() {
        invalidateString = true
    }
    public func asyncAttributedString() {
        func wrapImage(markup: Markdown.Markup, original: String? = nil, error: NSError?, image: SwiftMathImage?) -> ImageResult {
            if let codeblock = markup as? Markdown.CodeBlock {
                return ImageResult(source: original ?? codeblock.code, error: error, image: image)
            } else if let inline = markup as? Markdown.InlineCode {
                return ImageResult(source: original ?? inline.code, error: error, image: image)
            } else if let imageMarkup = markup as? Markdown.Image {
                return ImageResult(source: imageMarkup.plainText, error: nil, image: image)
            } else {
                fatalError("\(#function) unexpected markup \(markup)")
            }
        }
        
        var swiftMathDown = SwiftMathDown(baseFontSize: fontSize) { [weak self] (markup: Markdown.Markup) in
            guard let range = markup.range else { fatalError("\(#function) expected nil SourceRange \(markup)") }
            let latexEntry = self?.latexEntries[range]
            if let error = self?.errorTable[range] {
                return wrapImage(markup: markup, original: latexEntry, error: error, image: nil)
            } else if let image = ImageCacheManager.shared.get(key: range.description) {
                return wrapImage(markup: markup, original: latexEntry, error: nil, image: image)
            } else {
                return wrapImage(markup: markup, original: latexEntry, error: nil, image: nil)
            }
        }
        attributedString = swiftMathDown.attributedString(from: document)
    }
    private actor ImageOp: ImageOpNotification, ImageResourceLocator {
        private let totalTasks: Int
        private var asyncReturns: Int = 0
        private let completer: ImageOpCompletion & ImageResourceLocator

        private weak var mathMarkDown: MathMarkdown?
        init(mathMarkDown: MathMarkdown? = nil, count: Int, completer: ImageOpCompletion & ImageResourceLocator) {
            self.mathMarkDown = mathMarkDown
            self.completer = completer
            self.totalTasks = count
        }
        func notify(key: String, error: NSError?) async {
            guard let range = mathMarkDown?.rangeLookup[key] else { return }
            mathMarkDown?.errorTable[range] = error
            asyncReturns += 1
            if asyncReturns >= totalTasks {
                await completer.completion()
            }
        }
        func fileUrl(resource: String) async -> URL? {
            await completer.fileUrl(resource: resource)
        }
    }
}
internal struct Extractor: MarkupWalker {
    private var latexBlocks = [(SourceRange, String)]()
    private var latexInlines = [(SourceRange, UUID)]()
    private var imageEntries = [(SourceRange, ImageResource)]()
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        guard codeBlock.language == "math", let codeRange = codeBlock.range else { return }
        let entry = (codeRange, codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines))
        latexBlocks.append(entry)
    }
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
        guard let uuid = UUID(uuidString: inlineCode.code), let codeRange = inlineCode.range else { return }
        let entry = (codeRange, uuid)
        latexInlines.append(entry)
    }
    mutating func visitImage(_ image: Image) -> () {
        guard let imageSource = image.source, let codeRange = image.range else { return }
        if let url = URL(string: imageSource), ["http", "https"].contains(url.scheme) {
            let entry = (codeRange, ImageResource.networkResource(url: url))
            imageEntries.append(entry)
        } else {
            let entry = (codeRange, ImageResource.localResource(fileName: imageSource))
            imageEntries.append(entry)
        }
    }
    func convert(using extracts: [(UUID, Substring)]) -> (latexEntries: [(SourceRange, String)], imageEntries: [(SourceRange, ImageResource)], rangeXRef: [String: SourceRange]) {
        var inlines = Dictionary(uniqueKeysWithValues: extracts)
        let initalInlines = inlines.count
        var latexEntries: [(SourceRange, String)] = []
        var rangeXRef: [String: SourceRange] = [:]
        for (range, uuid) in latexInlines {
            guard let inline = inlines[uuid] else { continue }
            inlines.removeValue(forKey: uuid)
            latexEntries.append((range, String(inline)))
            rangeXRef[range.description] = range
        }
        for (range, _) in latexBlocks {
            rangeXRef[range.description] = range
        }
        for (range, _) in imageEntries {
            rangeXRef[range.description] = range
        }
        assert(inlines.count == 0, "Markdown parsing missed previously inserted UUIDs \(inlines.count) out of \(initalInlines) entries.\n\(inlines.values)")
        return (latexEntries + latexBlocks, imageEntries, rangeXRef)
    }
    enum ImageResource {
        case localResource(fileName: String)
        case networkResource(url: URL)
    }
}

internal struct MathRegexer {
    // https://developer.apple.com/documentation/foundation/nsregularexpression#//apple_ref/c/econst/NSRegularExpressionDotMatchesLineSeparators
    // https://www.hackingwithswift.com/articles/154/advanced-regular-expression-matching-with-nsregularexpression
    private static let defaultPattern = [     // Note: the (?sm: -- pattern -- ), does not apply to other patterns.
        #"(?sm:^\$\$$.*?^\$\$$)"#,          // line start/end to match $$, accepts newline in dot, non-greedy match, by default regex is greedy.
        #"(?<![`\$])\$`.+?`\$(?![`\$])"#,     // Starts with $ & backtick, non-greedy, ends with backtick and $, with no line breaks,
        #"(?<![`\$])\$(?![`\$])(.+?)(?<![`\$])\$(?![`\$])"#, // Starts with $, non-greedy, ends with $, look-ahead and look-behind not to have tick & $
    ].joined(separator: "|")
    
    private let regex: NSRegularExpression?
    init(_ pattern: String? = nil) {
        // MARK: don't use .anchorsMatchLines,
        // it is suppose to scan multi lines, but end up range misaligned. range lowerbound upperbound incorrect after several matches.
        // end up uses flag setting in the regular expression like (?sm) and (?sm-)
        // MARK: no need to use .dotMatchesLineSeparators,
        // dot match includes line breaks, required for $$, now use (?sm) instead.

        self.regex = try? NSRegularExpression(pattern: pattern ?? Self.defaultPattern,
                                              options: [.useUnicodeWordBoundaries])
    }
    internal func reformat(inputString: String) -> ReplacedResult {
        let regFragments: [RegexResult] = parsing(inputString)

        let beginBlock = "``` math\n"[...]
        let endBlock = "\n```"
        
        var blocksExtracted = 0
        var latexEntries: [(UUID, Substring)] = []
        var textStrings: [Substring] = []
        for reg in regFragments {
            switch reg.type {
            case .textInline:
                textStrings.append(inputString[reg.range])
            case .latexBlock:
                var block = inputString[reg.range]
                guard block.count>4 else { continue }
                block.removeLast(2)
                block.removeFirst(2)
                let replacement = beginBlock + block.trimmingCharacters(in: .whitespacesAndNewlines) + endBlock
                textStrings.append(replacement)
                blocksExtracted += 1
            case .latexBacktick:
                let uuid = UUID()
                var latex = inputString[reg.range]
                guard latex.count>4 else { continue }
                latex.removeLast(2)
                latex.removeFirst(2)
                latexEntries.append((uuid, latex))
                let replacement = "`" + uuid.uuidString + "`"
                textStrings.append(replacement[...])
            case .latexInline:
                let uuid = UUID()
                var latex = inputString[reg.range]
                guard latex.count>2 else { continue }
                latex.removeLast(1)
                latex.removeFirst(1)
                latexEntries.append((uuid, latex))
                let replacement = "`" + uuid.uuidString + "`"
                textStrings.append(replacement[...])
            }
        }
        return ReplacedResult(latexExtracts: latexEntries, textStrings: textStrings)
    }
    internal func parsing(_ inputString: String) -> [RegexResult] {
        let fullNSRange = inputString.fullNSRange
        var lastIndex = inputString.startIndex
        var extract = [RegexResult]()
        regex?.enumerateMatches(in: inputString,
                                options: [], range: fullNSRange) { result, _, _ in
            guard let _ = result, let range: NSRange = result?.range,
                    range.lowerBound != NSNotFound, range.upperBound != NSNotFound,
                    let stringRange = Range(range, in: inputString) else { return }
            if lastIndex < stringRange.lowerBound {
                let prependRange = lastIndex ..< stringRange.lowerBound
                extract.append(RegexResult(type: .textInline, range: prependRange))
            }
            // prepend before handling matches
            if inputString[stringRange].prefix(2) == "$$", inputString[stringRange].suffix(2) == "$$" {
                extract.append(RegexResult(type: .latexBlock, range: stringRange))
                lastIndex = stringRange.upperBound
            } else if inputString[stringRange].prefix(2) == "$`", inputString[stringRange].suffix(2) == "`$"{
                extract.append(RegexResult(type: .latexBacktick, range: stringRange))
                lastIndex = stringRange.upperBound
            } else if inputString[stringRange].prefix(1) == "$", inputString[stringRange].suffix(1) == "$" {
                extract.append(RegexResult(type: .latexInline, range: stringRange))
                lastIndex = stringRange.upperBound
            }
        }
        if lastIndex < inputString.endIndex {
            let postpendRange = lastIndex ..< inputString.endIndex
            extract.append(RegexResult(type: .textInline, range: postpendRange))
        }
        return extract
    }
    internal struct ReplacedResult {
        let latexExtracts: [(UUID, Substring)]
        let textStrings: [Substring]
    }
    internal struct RegexResult {
        let type: `Type`
        let range: Range<String.Index>
    }
    internal enum `Type` {
        case textInline, latexBacktick, latexInline, latexBlock
    }
}
private extension RangeExpression where Bound == String.Index  {
    func nsRange<S: StringProtocol>(in string: S) -> NSRange { .init(self, in: string) }
}
private extension String {
    var fullRange: Range<String.Index> {
        startIndex ..< endIndex
    }
    var fullNSRange: NSRange {
        fullRange.nsRange(in: self)
    }
}
