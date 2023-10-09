# MathMarkdown

## Approaches
- Use RegEx to preprocess Markdown text, and substitute math latex code that swift-markdown and cmark-gfm cannot handle by UUIDs.
- Apply swift-markdown parsing on the substituted text.
- Use MarkupWalker to extract the finalized list of network images, local images and math images that need to be generated.
- Use Async/Await to handle SwiftMathImage and Image download
- Embed Remote NSTextAttachment(iOS) and NSTextAttachmentCell(macOS) into NSAttributedString
- Build using a Formatter on NSAttributedString for PDF generation.
- Prepare for async notification to refresh NSTextAttachment or NSTextAttachmentCell.

## Some Limitations
- objcio.attributed-string-builder (supports cocoa only, uses TextBlock), adopt its MarkupWalker approach, 
- NSAttributedString, paragraphStyle implementation is different across cocoa and uikit. The former has TextBlock for Table.
- struct based MarkupVisitor and MarkupWalkers cannot be subclassed.
- NSImage, drawn using CoreGraphics preserves Glphy Infos while UIImage does not, end upwith awkward multi-line math equations across PDF pages.

## References
- This does not depend on apple/swift-markdown  https://github.com/objecthub/swift-markdownkit.git
- Renderer is publishing to SwiftUI only https://github.com/LiYanan2004/MarkdownView.git/Sources/MardownView/Renderer/Renderer.swift
- Other library to configure view on Markdown visitor,  https://github.com/johnxnguyen/Down.git
- Unfortunately, this only supports MacOS but not iOS.  https://github.com/objcio/attributed-string-builder.git
- apple/swift-docc/Sources/SwiftDocC/Model/Rendering/RenderContentCompiler use MarkupVisitor
- read StyleKit/StyleKit/Font.swift on Bundle handling https://github.com/nathantannar4/StyleKit.git .
- This is mainly cgContext based rendering, not even covering pdf, https://github.com/shaps80/GraphicsRenderer/tree/master
- Mainly for drawing stuff, use with GraphicsRenderer, https://github.com/shaps80/InkKit.git
