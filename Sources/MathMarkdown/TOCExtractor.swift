//
//  File.swift
//  
//
//  Created by Peter Tang on 12/9/2023.
//

import Foundation
import Markdown

/// https://github.com/LiYanan2004/MarkdownView.git
public struct TOCExtractor: MarkupWalker {
    private var sections = [TOCItem]()
    
    public init() {}
    
    public mutating func extract(from text: String) -> [TOCItem] {
        let document = Document(parsing: text, options: [.parseSymbolLinks])
        self.visit(document)
        return sections
    }
    
    public mutating func visitHeading(_ heading: Heading) {
        sections.append(TOCItem(level: heading.level, range: heading.range, plainText: heading.plainText))
        descendInto(heading)
    }
    public func visitInlineAttributes(_ attributes: InlineAttributes) -> () {
        NSLog("\(#function) \(attributes.plainText)")
    }
    public struct TOCItem: Hashable {
        /// Heading level, starting from 1.
        var level: Int
        /// The range of the heading in the raw Markdown.
        var range: SourceRange?
        /// The content text of the heading.
        var plainText: String
        
        var markdown: String {
            var markdownText = [String](repeating: "   ", count: level - 1).joined()
            for _ in 1...level {
                markdownText.append("#")
            }
            markdownText.append(" \(plainText)")
            return markdownText
        }
    }
}
