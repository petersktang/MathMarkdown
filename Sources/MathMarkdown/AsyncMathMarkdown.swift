//
//  AsyncSwiftMathDown.swift
//  
//
//  Created by Peter Tang on 30/9/2023.
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import Markdown

protocol AsyncImageProvider: NSObject {
    var image: SwiftMathImage? { get }
}

#if os(macOS)
class AsyncImageCell: NSTextAttachmentCell {
    public let sourceRange: SourceRange
    private weak var delegate: AsyncImageProvider?
    internal init(sourceRange: SourceRange) {
        self.sourceRange = sourceRange
        super.init()
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override var image: NSImage? {
        get { super.image ?? delegate?.image }
        set { super.image = newValue }
    }
}
#else
class AsyncImageAttachment: NSTextAttachment {
    public let sourceRange: SourceRange
    private weak var delegate: AsyncImageProvider?
    internal init(sourceRange: SourceRange) {
        self.sourceRange = sourceRange
        super.init()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override var image: UIImage? {
        get { super.image ?? delegate?.image }
        set { super.image = newValue }
    }
}
#endif

public struct AsyncMathMarkdown: MarkupVisitor {
    public typealias Result = NSAttributedString
    
    private let baseFontSize: CGFloat
#if os(macOS)
    private(set) var attachments: [AsyncImageCell] = []
#else
    private(set) var attachments: [AsyncImageAttachment] = []
#endif
    weak var delegate: MathMarkdown?
    private let imageLoader: ((Markup) -> ImageResult)?
    
    public init(baseFontSize: CGFloat = 15.0, delegate: MathMarkdown , imageLoader: ((Markup) -> ImageResult)? = nil) {
        self.baseFontSize = baseFontSize
        self.imageLoader  = imageLoader
        self.delegate = delegate
    }
    private mutating func imageAttachment(range: SourceRange, alignment: NSTextAlignment? = nil, finalTouch: ((NSMutableAttributedString) -> (Void))? = nil) -> NSAttributedString {
#if os(macOS)
        let imageCell = AsyncImageCell(sourceRange: range)
        attachments.append(imageCell)
        let imageAttachment = NSTextAttachment()
        imageAttachment.attachmentCell = imageCell
#else
        let imageAttachment = AsyncImageAttachment(sourceRange: range)
        attachments.append(imageAttachment)
#endif
        let result = NSMutableAttributedString(attachment: imageAttachment)
        let attachmentRange = NSRange(location: 0, length: result.length)
        result.addAttribute(.font, value: SwiftMathFont.systemFont(ofSize: baseFontSize), range: attachmentRange)
        
        if let alignment = alignment {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            let attributes: [NSAttributedString.Key: Any] = [.paragraphStyle: paragraphStyle]
            result.addAttributes(attributes)
        }
        finalTouch?(result)
        return result
    }
}
extension AsyncMathMarkdown {
    public mutating func attributedString(from document: Document) -> NSAttributedString {
        return visit(document)
    }
    mutating public func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in markup.children {
            result.append(visit(child))
        }
        
        return result
    }
    mutating public func visitText(_ text: Text) -> NSAttributedString {
        return NSAttributedString(string: text.plainText, attributes: [
            .font: SwiftMathFont.systemFont(ofSize: baseFontSize, weight: .regular)
        ])
    }
    mutating public func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in emphasis.children {
            result.append(visit(child))
        }
        
        result.applyEmphasis()
        
        return result
    }
    
    mutating public func visitStrong(_ strong: Strong) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in strong.children {
            result.append(visit(child))
        }
        
        result.applyStrong()
        
        return result
    }
    
    mutating public func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in paragraph.children {
            result.append(visit(child))
        }
        
        if paragraph.hasSuccessor {
            result.append(paragraph.isContainedInList ? .singleNewline(withFontSize: baseFontSize) : .doubleNewline(withFontSize: baseFontSize))
        }
        
        return result
    }

    mutating public func visitHeading(_ heading: Heading) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in heading.children {
            result.append(visit(child))
        }
        
        result.applyHeading(baseFontSize: baseFontSize, withLevel: heading.level)
        
        if heading.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        
        return result
    }
    
    mutating public func visitLink(_ link: Link) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in link.children {
            result.append(visit(child))
        }
        
        let url = link.destination != nil ? URL(string: link.destination!) : nil
        
        result.applyLink(withURL: url)
        
        return result
    }
    mutating public func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        func defaultInlineCode(_ inlineCodeOriginal: String) -> NSAttributedString {
            return NSAttributedString(string: inlineCodeOriginal, attributes: [
                .font: SwiftMathFont.monospacedSystemFont(ofSize: baseFontSize - 1.0, weight: .regular),
                .foregroundColor: SwiftMathColor.systemGray
            ])
        }
        guard let _ = UUID(uuidString: inlineCode.code), let sourceRange = inlineCode.range else {
            return defaultInlineCode(inlineCode.code)
        }
        return imageAttachment(range: sourceRange)
    }
    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let baseFontSize = baseFontSize
        func defaultCodeBlock(_ codeBlockOriginal: String) -> NSAttributedString {
            let result = NSMutableAttributedString(string: codeBlockOriginal, attributes: [
                .font: SwiftMathFont.monospacedSystemFont(ofSize: baseFontSize - 1.0, weight: .regular),
                .foregroundColor: SwiftMathColor.systemGray
            ])
            
            if codeBlock.hasSuccessor {
                result.append(.singleNewline(withFontSize: baseFontSize))
            }
            
            return result
        }
        guard codeBlock.language == "math", let sourceRange = codeBlock.range else {  return defaultCodeBlock(codeBlock.code) }
        
        return imageAttachment(range: sourceRange, alignment: .center) { result in
            if codeBlock.hasSuccessor {
                result.append(codeBlock.isContainedInList ? .singleNewline(withFontSize: baseFontSize) : .doubleNewline(withFontSize: baseFontSize))
            }
        }
     }
    
    mutating public func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in strikethrough.children {
            result.append(visit(child))
        }
        
        result.applyStrikethrough()
        
        return result
    }
    
    mutating public func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        let font = SwiftMathFont.systemFont(ofSize: baseFontSize, weight: .regular)
                
        for listItem in unorderedList.listItems {
            var listItemAttributes: [NSAttributedString.Key: Any] = [:]
            
            let listItemParagraphStyle = NSMutableParagraphStyle()
            
            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(unorderedList.listDepth))
            let spacingFromIndex: CGFloat = 8.0
            let bulletWidth = ceil(NSAttributedString(string: "•", attributes: [.font: font]).size().width)
            let firstTabLocation = leftMarginOffset + bulletWidth
            let secondTabLocation = firstTabLocation + spacingFromIndex
            
            listItemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTabLocation),
                NSTextTab(textAlignment: .left, location: secondTabLocation)
            ]
            
            listItemParagraphStyle.headIndent = secondTabLocation
            
            listItemAttributes[.paragraphStyle] = listItemParagraphStyle
            listItemAttributes[.font] = SwiftMathFont.systemFont(ofSize: baseFontSize, weight: .regular)
            listItemAttributes[.listDepth] = unorderedList.listDepth
            
            let listItemAttributedString = visit(listItem).mutableCopy() as! NSMutableAttributedString
            listItemAttributedString.insert(NSAttributedString(string: "\t•\t", attributes: listItemAttributes), at: 0)
            
            result.append(listItemAttributedString)
        }
        
        if unorderedList.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        
        return result
    }
    
    mutating public func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for child in listItem.children {
            result.append(visit(child))
        }
        
        if listItem.hasSuccessor {
            result.append(.singleNewline(withFontSize: baseFontSize))
        }
        
        return result
    }
    
    mutating public func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for (index, listItem) in orderedList.listItems.enumerated() {
            var listItemAttributes: [NSAttributedString.Key: Any] = [:]
            
            let font = SwiftMathFont.systemFont(ofSize: baseFontSize, weight: .regular)
            let numeralFont = SwiftMathFont.monospacedDigitSystemFont(ofSize: baseFontSize, weight: .regular)
            
            let listItemParagraphStyle = NSMutableParagraphStyle()
            
            // Implement a base amount to be spaced from the left side at all times to better visually differentiate it as a list
            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(orderedList.listDepth))
            
            // Grab the highest number to be displayed and measure its width (yes normally some digits are wider than others but since we're using the numeral mono font all will be the same width in this case)
            let highestNumberInList = orderedList.childCount
            let numeralColumnWidth = ceil(NSAttributedString(string: "\(highestNumberInList).", attributes: [.font: numeralFont]).size().width)
            
            let spacingFromIndex: CGFloat = 8.0
            let firstTabLocation = leftMarginOffset + numeralColumnWidth
            let secondTabLocation = firstTabLocation + spacingFromIndex
            
            listItemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTabLocation),
                NSTextTab(textAlignment: .left, location: secondTabLocation)
            ]
            
            listItemParagraphStyle.headIndent = secondTabLocation
            
            listItemAttributes[.paragraphStyle] = listItemParagraphStyle
            listItemAttributes[.font] = font
            listItemAttributes[.listDepth] = orderedList.listDepth

            let listItemAttributedString = visit(listItem).mutableCopy() as! NSMutableAttributedString
            
            // Same as the normal list attributes, but for prettiness in formatting we want to use the cool monospaced numeral font
            var numberAttributes = listItemAttributes
            numberAttributes[.font] = numeralFont
            
            let numberAttributedString = NSAttributedString(string: "\t\(index + 1).\t", attributes: numberAttributes)
            listItemAttributedString.insert(numberAttributedString, at: 0)
            
            result.append(listItemAttributedString)
        }
        
        if orderedList.hasSuccessor {
            result.append(orderedList.isContainedInList ? .singleNewline(withFontSize: baseFontSize) : .doubleNewline(withFontSize: baseFontSize))
        }
        
        return result
    }
    
    mutating public func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        // BlockDirective.swift, can be used to parse the below custom latex block, it may be possible to include other types.
        // @LaTeX {
        //     This is a \LaTeX{} document
        // }
        // Unfortunately, this is not recognized by github.com and thus not rendered correctly.
        let result = NSMutableAttributedString()
        
        for child in blockQuote.children {
            var quoteAttributes: [NSAttributedString.Key: Any] = [:]
            
            let quoteParagraphStyle = NSMutableParagraphStyle()
            
            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(blockQuote.quoteDepth))
            
            quoteParagraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: leftMarginOffset)]
            
            quoteParagraphStyle.headIndent = leftMarginOffset
            
            quoteAttributes[.paragraphStyle] = quoteParagraphStyle
            quoteAttributes[.font] = SwiftMathFont.systemFont(ofSize: baseFontSize, weight: .regular)
            quoteAttributes[.listDepth] = blockQuote.quoteDepth
            
            let quoteAttributedString = visit(child).mutableCopy() as! NSMutableAttributedString
            quoteAttributedString.insert(NSAttributedString(string: "\t", attributes: quoteAttributes), at: 0)
            
            quoteAttributedString.addAttribute(.foregroundColor, value: SwiftMathColor.systemGray)
            
            result.append(quoteAttributedString)
        }
        
        if blockQuote.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        
        return result
    }
    
    public mutating func visitImage(_ image: Image) -> NSAttributedString {
        func defaultImage(_ image: Image) -> NSAttributedString {
            return NSAttributedString(string: image.plainText, attributes: [
                .font: SwiftMathFont.monospacedSystemFont(ofSize: baseFontSize - 1.0, weight: .regular),
                .foregroundColor: SwiftMathColor.systemGray
            ])
        }
        guard let sourceRange = image.range else { return defaultImage(image) }
        return imageAttachment(range: sourceRange, alignment: .left)
    }
    public func visitTable(_ table: Table) -> NSAttributedString {
        // Work-in-progress
        // guard !Array(table.body.rows).isEmpty else { return .init() }
        // let textList = NSTextList()
        // let paragraph = NSMutableParagraphStyle()
        // paragraph.textLists = []
        // ---
        // let result = NSMutableAttributedString()
        // let table = NSTextTable()
        // table.setContentWidth(contentWidth.value, type: contentWidth.type)
        // table.numberOfColumns = rows[0].cells.count
        // for (rowIx, row) in rows.enumerated() {
        //     assert(row.cells.count == table.numberOfColumns)
        //     row.render(row: rowIx, table: table, context: &context, result: result)
        // }
        // result.replaceCharacters(in: NSRange(location: result.length-1, length: 1), with: "")
        return .init()
    }
}
