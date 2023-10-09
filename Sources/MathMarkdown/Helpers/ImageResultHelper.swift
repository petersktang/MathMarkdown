//
//  SwiftMathImageResult.swift
//
//
//  Created by Peter Tang on 18/9/2023.
//

#if os(iOS)
import UIKit
public typealias SwiftMathImage = UIImage
#elseif os(macOS)
import AppKit
public typealias SwiftMathImage = NSImage
#endif

import SwiftMath
import Markdown

public struct ImageResult {
    let source: String
    let error: NSError?
    let image: SwiftMathImage?
}
internal struct ImageOpResult {
    let label: String
    let error: NSError?
    let image: SwiftMathImage?
}
public protocol ImageOpNotification {
    func notify(key: String, error: NSError?) async
}
public protocol ImageOpCompletion {
    func completion() async
}
public protocol ImageResourceLocator {
    func fileUrl(resource: String) async -> URL?
}
#if os(macOS)
import Cocoa
extension NSImage: @unchecked Sendable {
    func pngData() -> Data? {
        tiffRepresentation?.bitmap?.png
    }
}
extension Data {
    var bitmap: NSBitmapImageRep? { NSBitmapImageRep(data: self) }
}
extension NSBitmapImageRep {
    var png: Data? { representation(using: .png, properties: [:]) }
}
#endif
