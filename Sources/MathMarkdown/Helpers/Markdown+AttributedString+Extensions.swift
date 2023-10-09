//
//  Markdown+AttributedString+Extensions.swift
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

// MARK: - Extensions Land

extension NSMutableAttributedString {
    func applyEmphasis() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, stop in
            guard let font = value as? SwiftMathFont else { return }
            
            let newFont = font.apply(newTraits: SymbolicTraits.italic)
            addAttribute(.font, value: newFont, range: range)
        }
    }
    
    func applyStrong() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, stop in
            guard let font = value as? SwiftMathFont else { return }
            
            let newFont = font.apply(newTraits: SymbolicTraits.bold)
            addAttribute(.font, value: newFont, range: range)
        }
    }
    
    func applyLink(withURL url: URL?) {
        addAttribute(.foregroundColor, value: SwiftMathColor.systemBlue)
        
        if let url = url {
            addAttribute(.link, value: url)
        }
    }
    
    func applyBlockquote() {
        addAttribute(.foregroundColor, value: SwiftMathColor.systemGray)
    }
    
    func applyHeading(baseFontSize: CGFloat, withLevel headingLevel: Int) {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, stop in
            guard let font = value as? SwiftMathFont else { return }
            
            let newFont = font.apply(newTraits: SymbolicTraits.bold, newPointSize: baseFontSize + 13.0 - CGFloat(headingLevel * 2))
            addAttribute(.font, value: newFont, range: range)
        }
    }
    func applyStrikethrough() {
        addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
    }
}

extension SwiftMathFont {
    func apply(newTraits: SymbolicTraits, newPointSize: CGFloat? = nil) -> SwiftMathFont {
        var existingTraits = fontDescriptor.symbolicTraits
        existingTraits.insert(newTraits)
        
        #if os(iOS)
        guard let newFontDescriptor = fontDescriptor.withSymbolicTraits(existingTraits) else { return self }
        return UIFont(descriptor: newFontDescriptor, size: newPointSize ?? pointSize)
        #elseif os(macOS)
        let newFontDescriptor = fontDescriptor.withSymbolicTraits(existingTraits)
        return NSFont(descriptor: newFontDescriptor, size: newPointSize ?? pointSize) ?? NSFont.systemFont(ofSize: newPointSize ?? pointSize)
        #endif
    }
}

extension ListItemContainer {
    /// Depth of the list if nested within others. Index starts at 0.
    var listDepth: Int {
        var index = 0

        var currentElement = parent

        while currentElement != nil {
            if currentElement is ListItemContainer {
                index += 1
            }

            currentElement = currentElement?.parent
        }
        
        return index
    }
}

extension BlockQuote {
    /// Depth of the quote if nested within others. Index starts at 0.
    var quoteDepth: Int {
        var index = 0

        var currentElement = parent

        while currentElement != nil {
            if currentElement is BlockQuote {
                index += 1
            }

            currentElement = currentElement?.parent
        }
        
        return index
    }
}

extension Markup {
    /// Returns true if this element has sibling elements after it.
    var hasSuccessor: Bool {
        guard let childCount = parent?.childCount else { return false }
        return indexInParent < childCount - 1
    }
    
    var isContainedInList: Bool {
        var currentElement = parent

        while currentElement != nil {
            if currentElement is ListItemContainer {
                return true
            }

            currentElement = currentElement?.parent
        }
        
        return false
    }
}

extension NSAttributedString.Key {
    static let listDepth = NSAttributedString.Key("ListDepth")
    static let quoteDepth = NSAttributedString.Key("QuoteDepth")
}

extension NSMutableAttributedString {
    func addAttribute(_ name: NSAttributedString.Key, value: Any) {
        addAttribute(name, value: value, range: NSRange(location: 0, length: length))
    }
    
    func addAttributes(_ attrs: [NSAttributedString.Key : Any]) {
        addAttributes(attrs, range: NSRange(location: 0, length: length))
    }
}

extension NSAttributedString {
    static func singleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        return NSAttributedString(string: "\n", attributes: [.font: SwiftMathFont.systemFont(ofSize: fontSize, weight: .regular)])
    }
    
    static func doubleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        return NSAttributedString(string: "\n\n", attributes: [.font: SwiftMathFont.systemFont(ofSize: fontSize, weight: .regular)])
    }
}
