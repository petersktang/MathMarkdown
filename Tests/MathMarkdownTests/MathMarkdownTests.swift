//
//  MathMarkdownTests.swift
//
//
//  Created by Peter Tang on 26/9/2023.
//

import XCTest
@testable import MathMarkdown
import Markdown

final class MathMarkdownTests: XCTestCase {
    // XCTest Documentation
    // https://developer.apple.com/documentation/xctest

    // Defining Test Cases and Test Methods
    // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    func testMathRegexerParsingScripts() {
        let mathString = mathInlineString.joined(separator: "\n")
        let regexer = MathRegexer()
        let regFragments = regexer.parsing(mathString)
        let combine = regFragments.map { matchResult in
            switch matchResult.type {
            case .latexBlock: return mathString[matchResult.range]
            case .latexBacktick: return mathString[matchResult.range]
            case .latexInline: return mathString[matchResult.range]
            case .textInline: return mathString[matchResult.range]
            }
        }.map { String($0) }
    }
    func testMathRegexerReformatScripts() {
        let mathString = mathInlineString.joined() + "\n" + threeBackticksBlock
        let regexer = MathRegexer()
        let result = regexer.reformat(inputString: mathString)
        XCTAssertNotNil(result)
    }
    func testMathRegexerReformatJoinedScripts() {
        let mathString = mathInlineString.joined() + "\n" + threeBackticksBlock
        let regexer = MathRegexer()
        let result = regexer.reformat(inputString: mathString)
        let refactored = result.textStrings.joined()
        let document = MathMarkdown(parsing: refactored)
        XCTAssertNotNil(document)
    }
    func testMathExtractorScripts() {
        let mathString = mathInlineString.joined() + "\n" + threeBackticksBlock
        let regexer = MathRegexer()
        let result = regexer.reformat(inputString: mathString)
        let refactored = result.textStrings.joined()
        let mathMark = MathMarkdown(parsing: refactored)
        
        var extractor = Extractor()
        extractor.visitDocument(mathMark.document)
        let (_, _, _) = extractor.convert(using: result.latexExtracts)
    }
    func testMathMarkdownAccessImageCacheScripts() {
        guard let markdown = prepareMarkdownLoading() else { return }
        markdown.fontSize = 16
        let expectation = XCTestExpectation(description: "SwiftMathImage asynchronous generation.")
        let completion = TestNotification(expectation: expectation)
        
        //FIXME: Need completion handler
        Task { await markdown.loadImageCache(completion) }
        
        wait(for: [expectation], timeout: 15.0)
        for (index, entry) in markdown.latexEntries.enumerated() {
            if let image = ImageCacheManager.shared.get(key: entry.key.description), let pngData = image.pngData() {
                saveImage(fileName: "\(index)", pngData: pngData)
            }
        }
    }
    func testMathMarkdownAccessImageCacheFlippedBoundedBoxScripts() {
        guard let markdown = prepareMarkdownLoading() else { return }
        markdown.fontSize = 16
        let expectation = XCTestExpectation(description: "SwiftMathImage asynchronous generation.")
        let completion = TestNotification(expectation: expectation)
        
        //FIXME: Need completion handler
        Task { await markdown.loadImageCache(completion) }
        
        wait(for: [expectation], timeout: 15.0)
        let testMacFlip = false
        for (index, entry) in markdown.latexEntries.enumerated() {
            if let image = ImageCacheManager.shared.get(key: entry.key.description) {
#if os(macOS)
                let newImage = NSImage(size: image.size, flipped: testMacFlip) { rect in
                    let ctx = NSGraphicsContext.current?.cgContext
                    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    ctx?.stroke(rect)
                    return true
                }
                if let pngData = newImage.pngData() {
                    saveImage(fileName: "\(index)", pngData: pngData)
                }
#else
                if let pngData = image.pngData() {
                    saveImage(fileName: "\(index)", pngData: pngData)
                }
#endif
            }
        }
    }
    func testMathMarkdownAttributedStringBeforeImageCacheLoadedScripts() {
        guard let markdown = prepareMarkdownLoading() else { return }
        markdown.fontSize = 16
        helperGenerateAttributedString(markdown: markdown, testCase: 2)
    }
    func testMathMarkdownAttributedStringAfterImageCacheLoadedScripts() {
        guard let markdown = prepareMarkdownLoading() else { return }
        markdown.fontSize = 16
        let expectation = XCTestExpectation(description: "SwiftMathImage asynchronous generation.")
        let completion = TestNotification(expectation: expectation)
        Task { await markdown.loadImageCache(completion) }
        
        wait(for: [expectation], timeout: 5.0)
        helperGenerateAttributedString(markdown: markdown, testCase: 2)
    }
    func helperGenerateAttributedString(markdown: MathMarkdown, testCase: Int)  {
        markdown.asyncAttributedString()
        
        let formatter = PDFFormatter()
        switch testCase {
#if os(iOS)
        case 1:
            let iosPDF = formatter.iosPDF(markdown.attributedString)
            let defaultPDF = formatter.pdfData(markdown.attributedString)
            savePdf(fileName: "example", defaultPdf: defaultPDF, iosPdf: iosPDF)
#endif
        default:
            let defaultPDF = formatter.pdfData(markdown.attributedString)
            savePdf(fileName: "example", defaultPdf: defaultPDF)
        }
    }
    func testMathMarkdownScripts() throws {
        let markdown = prepareMarkdownLoading()
        // print(markdown.document.debugDescription(options: .printEverything))
        XCTAssertNotNil(markdown)
    }
}
extension MathMarkdownTests {
    class TestNotification: ImageOpCompletion, ImageResourceLocator {
        func fileUrl(resource: String) -> URL? {
            guard let target = resource.split(separator: "/").last?.split(separator: "."),
                    let fileName = target.first,
                    let ext = target.last else { return nil }
            return Bundle.module.url(forResource: String(fileName), withExtension: String(ext))
        }
        
        let expectation: XCTestExpectation
        init(expectation: XCTestExpectation) {
            self.expectation = expectation
        }
        func completion() async {
            expectation.fulfill()
        }
    }
    func savePdf(fileName: String, defaultPdf: Data? = nil, iosPdf: Data? = nil, macPdf: Data? = nil) {
        if let defaultPdf = defaultPdf {
            let defaultPdfURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("\(fileName)-defaultPDF.pdf"))
            try? defaultPdf.write(to: defaultPdfURL, options: [.atomicWrite])
            print("\(defaultPdfURL.path)")
        }
        if let testPdf = iosPdf {
            let testPdfURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("\(fileName)-testPDF.pdf"))
            try? testPdf.write(to: testPdfURL, options: [.atomicWrite])
            print("\(testPdfURL.path)")
        }
        if let macPdf = macPdf {
            let macPdfURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("\(fileName)-macPDF.pdf"))
            try? macPdf.write(to: macPdfURL, options: [.atomicWrite])
            print("\(macPdfURL.path)")
        }
    }
    func saveImage(fileName: String, pngData: Data) {
        let imageFileURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("image-\(fileName).png"))
        try? pngData.write(to: imageFileURL, options: [.atomicWrite])
        print("\(#function) \(imageFileURL.path)")
    }
    func prepareMarkdownLoading(resource: String = "example") -> MathMarkdown? {
        guard let testFrameworkResourceBundleUrl = Bundle.module.url(forResource: resource, withExtension: "md"),
                let fileContent = try? String(contentsOf: testFrameworkResourceBundleUrl, encoding: .utf8) else { return nil }
        return MathMarkdown(parsing: fileContent)
    }
    private var mathInlineString: [String] { [
        #"$`\sqrt{3x-1}+ okay to include $ in the middle (1+x)^2`$"#,
        #"$\sqrt{3x-1}+(1+x)^2$"#,
        "some simple text",
        #"$`\sqrt{3x-1}+ okay  👨‍🔧  to include $ in the middle (1+x)^2`$"#,
        #"$\sqrt{3x-1}+ 👨‍🔧 (1+x)^2$"#,
        "other types of simple text",
        #"$\sqrt{3x-1}+(1+x)^2$"#,
        "another example of simple text",
        #"$`\sqrt{3x-1}+ okay to include $ in the middle (1+x)^2`$"#,
        "regex search is not 👨‍🔧 greedy.\n",
        "$$\n"+#"""
                    math text
                    multi line
                """#+"\n$$",
        "An intermediate 👨‍🔧  line",
        "$$\n"+#"""
                    another set of math text
                    another set of  👨‍🔧 multi line
                """#+"\n$$",
        "Another round of tests $$",
    ]}
    private var threeBackticksBlock: String {
                #"""
                ``` swift
                    some swift code
                ```
                """#
    }
}
