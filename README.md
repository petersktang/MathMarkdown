# SwiftMathMarkdown

## Approaches
- Study attributed-string-builder and migrate Markdownosaur visit code in.
- Assemble multiple Markdown to AttributedString collection, review and compare differences later.
- MarkupFormatter & MarkupTreeDumper uses MarkupWalker protocol
- BreakDeleter (MarkupFormatter), SoftBreakDeleter both uses MarkupRewriter. 

## Asynchronous Behaviour consideration
- SwiftMathDownosaur could accept two closures, one to handle latex images generation, and the other local or remote images loading
- These can be asynchronous loading effect, keeps changing the contents of the attributed string when contents arrives.
- Each arrival or notification of the contents, triggers a textLayout refresh.
- So far, no implementation approaches. May be a bit of Combine.

## Notes
- Done apply change to Downosaur. AttributedStringBuilder seems complex.

## Limitations
- objcio.attributed-string-builder (supports cocoa only, uses TextBlock), adopt its MarkupWalker approach, 
- Markdownosaur uses only MarkupVisitor approach
- NSAttributedString, paragraphStyle implementation is different across cocoa and uikit. The former has TextBlock for Table.
- May need to lower the support on iOS.
- All code uses struct on MarkupVisitor/MarkupWalker, thus cannot subclass and override.

## References
- not depend on apple/swift-markdown  https://github.com/objecthub/swift-markdownkit.git
- Renderer is publishing to SwiftUI only https://github.com/LiYanan2004/MarkdownView.git/Sources/MardownView/Renderer/Renderer.swift
- Interesting library to configure view on Markdown visitor,  https://github.com/johnxnguyen/Down.git
- Unfortunately, this only supports MacOS but not iOS.  https://github.com/objcio/attributed-string-builder.git
- apple/swift-docc/Sources/SwiftDocC/Model/Rendering/RenderContentCompiler use MarkupVisitor
- https://github.com/nathantannar4/StyleKit.git read StyleKit/StyleKit/Font.swift on Bundle handling.
- This is mainly cgContext based rendering, not even covering pdf, https://github.com/shaps80/GraphicsRenderer/tree/master
- Mainly for drawing stuff, use with GraphicsRenderer, https://github.com/shaps80/InkKit.git

## Sample inline math
This is a sample `\sqrt{5z+6}-(9+y)^3` test.
