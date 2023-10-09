import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import PDFKit

// https://www.hackingwithswift.com/example-code/libraries/how-to-extract-text-from-a-pdf-using-pdfkit
public extension PDFDocument {
    var attributedString: NSAttributedString {
        let contentAttrString = NSMutableAttributedString()
        for i in 0 ..< pageCount {
            guard let page = page(at: i) else { continue }
            guard let pageContent = page.attributedString else { continue }
            contentAttrString.append(pageContent)
        }
        return NSAttributedString(attributedString: contentAttrString)
    }
}

extension CGFloat {
    public static var pointsPerInch: CGFloat { 72 }
    public static var pointsPerMM: CGFloat { pointsPerInch / 25.4 }
}

extension CGSize {
    static public let a4 = CGSize(width: 8.25 * .pointsPerInch, height: 11.75 * .pointsPerInch)
}

public class PDFFormatter: NSObject, NSLayoutManagerDelegate {
    private let size: CGSize
    private let inset: CGSize
    
    public var lineSpacing: CGFloat = 2.0
    
    public init(size: CGSize = .a4, inset: CGSize = .init(width: .pointsPerInch, height: .pointsPerInch)) {
        self.size = size
        self.inset = inset
    }
    public func pdfData(_ attributedString: NSAttributedString) -> Data {
        // need `storage` for the entire duration of PDF Data generation
        let storage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        
        #if os(macOS)
        layoutManager.typesetterBehavior = .latestBehavior
        layoutManager.defaultAttachmentScaling = .scaleProportionallyUpOrDown
        layoutManager.allowsNonContiguousLayout = true
        layoutManager.backgroundLayoutEnabled = false
        #endif

        layoutManager.delegate = self
        storage.addLayoutManager(layoutManager)
        
        let page = CGRect(origin: .zero, size: size)
        let bounds = page.insetBy(dx: inset.width, dy: inset.height)
        
        let renderer = CGContextRenderer(page: page, flipped: true)
        return renderer.pdfData { ctx in
            ctx.saveGState()
            layoutManager.render(on: ctx, page: page, content: bounds, contextFlipped: renderer.flipped)
            ctx.restoreGState()
        }
    }
    #if os(iOS)
    public func iosPDF(_ attributedString: NSAttributedString) -> Data {
        // need `storage` for the entire duration of PDF Data generation
        let storage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        
        let page = CGRect(origin: .zero, size: size)
        let bounds = page.insetBy(dx: inset.width, dy: inset.height)
        
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: .init())
        return renderer.pdfData { ctx in
            ctx.cgContext.saveGState()
            layoutManager.render(on: ctx.cgContext, page: page, content: bounds, contextFlipped: true)
            ctx.cgContext.restoreGState()
        }
    }
    #endif
}
extension PDFFormatter {
    // public func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>, properties props: UnsafePointer<NSLayoutManager.GlyphProperty>, characterIndexes charIndexes: UnsafePointer<Int>, font aFont: UIFont, forGlyphRange glyphRange: NSRange) -> Int {
    //     0
    // }
    // public func layoutManager(_ layoutManager: NSLayoutManager, shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>, lineFragmentUsedRect: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>, in textContainer: NSTextContainer, forGlyphRange glyphRange: NSRange) -> Bool {
    //     true
    // }
    public func layoutManager(_ layoutManager: NSLayoutManager, lineSpacingAfterGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
        return self.lineSpacing
    }
}
extension PDFFormatter {

    private func layoutAsyncAttachments(_ textStorage: NSTextStorage, in range: NSRange) {
        // func asyncAttachments(_ textStorage: NSTextStorage, in range: NSRange) ->  [(AsyncTextAttachment, NSRange)] {
        //     var attachments: [(AsyncTextAttachment, NSRange)] = []
        //     textStorage.enumerateAttribute(.attachment, in: range) { attribute, range, _ in
        //         if let textAttachment = attribute as? AsyncTextAttachment {
        //             attachments.append((textAttachment, range))
        //         }
        //     }
        //     return attachments
        // }
        // let attachments = asyncAttachments(textStorage, in: range)
        // for (viewAttachment, range) in attachments {
        //     let index = layoutManager.glyphIndexForCharacter(at: range.location)
        //     let size = layoutManager.attachmentSize(forGlyphAt: index)
        //     if size == .zero {
        //         continue
        //     }
        //     let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: nil)
        //     if lineFragmentRect.size == .zero {
        //         continue
        //     }
        //     let location = layoutManager.location(forGlyphAt: index)
        // }
    }

}

internal class CGContextRenderer {
    private var pageRect: CGRect
    public let flipped: Bool
    init(page: CGRect, flipped: Bool) {
        self.pageRect = page
        self.flipped = flipped
    }
    func pdfData(actions: (CGContext) -> Void) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
                let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else { return data as Data}
        #if os(macOS)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: flipped)
        #elseif os(iOS)
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        #endif
        
        actions(context)
        
        return data as Data
    }
}

private extension NSLayoutManager {
    // Refer techniques in: https://github.com/facebook/lexical-ios/blob/main/Lexical/TextKit/LayoutManager.swift
    // some other technique: https://github.com/AuroraEditor/AuroraEditor.git
    // TextKit 1 & 2: https://github.com/ChimeHQ/TextViewPlus.git
    func render(on context: CGContext, page pageRect: CGRect, content contentRect: CGRect, contextFlipped: Bool) {
        var needsMoreContainers = true
        var pageNumber: Int = 1
        
        while needsMoreContainers {
            let container = NSTextContainer(size: contentRect.size)
            
            addTextContainer(container)
            let range = glyphRange(for: container)
            needsMoreContainers = range.location + range.length < numberOfGlyphs
            
            context.beginPDFPage(nil)
            
            if contextFlipped {
                context.translateBy(x: 0, y: pageRect.height)
                context.scaleBy(x: 1, y: -1)
            }
            
            ("Page \(pageNumber), \(Date().formatted())" as NSString).draw(in: pageRect, withAttributes: [
                .font: SwiftMathFont.systemFont(ofSize: 12)
            ])
            
            // let generator = glyphGenerator

            #if os(macOS)
            textStorage?.enumerateAttribute(.attachment, in: range) { v, r, _ in
                // guard let attachment = v as? NSTextAttachment else { return }
                // if let image = attachment.image {
                //     // setAttachmentSize(image.size, forGlyphRange: r)
                //     // invalidateLayout(forCharacterRange: r, actualCharacterRange: nil)
                //     var lineRange: NSRange = NSRange()
                //     let index = glyphIndexForCharacter(at: r.location)
                //     let rect = lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
                //     print("\(#function) image \(rect.size == image.size) \(rect.size) vs \(image.size) \(r) vs \(lineRange)")
                // }
                // if let imageCell = attachment.attachmentCell as? NSTextAttachmentCell, let image = imageCell.image {
                //     // setAttachmentSize(image.size, forGlyphRange: r)
                //     // invalidateLayout(forCharacterRange: r, actualCharacterRange: nil)
                //     var lineRange: NSRange = NSRange()
                //     let index = glyphIndexForCharacter(at: r.location)
                //     let rect = lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
                //     print("\(#function) iCell \(rect.size == image.size) \(rect.size) vs \(image.size) \(r) vs \(lineRange)")
                // }
            }
            let rangeAfterLayout = glyphRange(for: container)
            #endif
            
            if range.length > 0 {
                drawBackground(forGlyphRange: range, at: contentRect.origin)
                drawGlyphs(forGlyphRange: range, at: contentRect.origin)
            }
            
            context.endPDFPage()
            
            pageNumber += 1
        }
        context.closePDF()
    }
}
