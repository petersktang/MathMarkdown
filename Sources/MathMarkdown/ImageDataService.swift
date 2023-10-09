//
//  DownloadImageDataService.swift
//  DownloadImageWithCombineTraining
//
//  Created by Noah's Ark on 2022/08/21.
//

import Foundation
import SwiftMath
import Semaphore

/// https://theswiftdev.com/how-to-download-files-with-urlsession-using-combine-publishers-and-subscribers/
/// https://medium.com/@GetInRhythm/closures-vs-combine-vs-async-await-993eb1da4d44
/// https://www.swiftbysundell.com/articles/swift-concurrency-multiple-tasks-in-parallel/
/// https://www.swiftbysundell.com/articles/a-deep-dive-into-grand-central-dispatch-in-swift/

#if os(macOS)
    fileprivate let coreGraphicsImageForceToPng = true
#else
    fileprivate let coreGraphicsImageForceToPng = false
#endif

public struct ImageDataService {
    
    static let shared = ImageDataService()
    private let semaphore: AsyncSemaphore

    init(maxConcurrent: Int = 12) {
        self.semaphore = AsyncSemaphore(value: maxConcurrent)
    }

    // private func networkImageFile(label: String, url: URL) async {
    //     let task = Task<URL, Error> { () -> URL in
    //         let (fileUrl, _) = try await URLSession.shared.download(from: url)
    //         return fileUrl
    //     }
    //     let result = await task.result
    //     do {
    //         let _ = try result.get()
    //     } catch  {
    //         return
    //     }
    // }

    func networkImages(_ imageEntries: [(String, URL)], notify notifier: ImageOpNotification) {
        @Sendable func networkImage(label: String, url: URL) async -> ImageOpResult {
            do {
                let (fileUrl, response) = try await URLSession.shared.download(from: url)
                guard let response = response as? HTTPURLResponse, response.statusCode >= 200 && response.statusCode < 300 else {
                    throw NetworkImageError.responseError(resp: response as? HTTPURLResponse).nserr
                }
                guard let data = try? Data(contentsOf: fileUrl), let image = SwiftMathImage(data: data) else {
                    throw NetworkImageError.imageError.nserr
                }
                return ImageOpResult(label: label, error: nil, image: image)
            } catch let error as NSError {
                return ImageOpResult(label: label, error: error, image: nil)
            }
        }
        for (label, url) in imageEntries {
            Task {
                await semaphore.wait()
                let notifier = notifier
                let result = await networkImage(label: label, url: url)
                if result.error == nil, let image = result.image {
                    await ImageCacheManager.shared.updateCache(key: label, image: image)
                    await notifier.notify(key: label, error: nil)
                } else {
                    await notifier.notify(key: label, error: result.error)
                }
                semaphore.signal()
            }
        }
    }
    func latexImages(_ latexEntries: [(String, String)], fontSize: CGFloat, textColor: MTColor, notify notifier: ImageOpNotification) {
        @Sendable func swiftMathImage(label: String, latex: String, fontSize: CGFloat, textColor: MTColor = .black) async -> ImageOpResult {
            var formatter = MathImage(latex: latex, fontSize: fontSize, textColor: textColor, labelMode: .text)
            let (error, image) = formatter.asImage()
            guard error == nil, let image = image else {
                return ImageOpResult(label: label, error: error, image: nil)
            }
            // on Mac, the generated NSImage is not truly an image but a CoreGraphics object, where layoutManager treats glyphs layout wrongly.
            // now convert to png and reimport back until found a way to manage the layout difference at a later point in time.
            if coreGraphicsImageForceToPng, let pngData = image.pngData(), let newImage = SwiftMathImage(data: pngData) {
                return ImageOpResult(label: label, error: nil, image: newImage)
            }
            return ImageOpResult(label: label, error: nil, image: image)
        }
        for (label, latex) in latexEntries {
            Task {
                let notifier = notifier
                let result = await swiftMathImage(label: label, latex: latex, fontSize: fontSize, textColor: textColor)
                if result.error == nil, let image = result.image {
                    await ImageCacheManager.shared.updateCache(key: result.label, image: image)
                    await notifier.notify(key: result.label, error: nil)
                } else {
                    await notifier.notify(key: result.label, error: result.error)
                }
            }
        }
    }

    func localImages(_ imageEntries: [(label: String, fileName: String)], notify notifier: ImageOpNotification & ImageResourceLocator) {
        @Sendable func bundleImage(label: String, fileName: String) async -> ImageOpResult {
            guard let url = await notifier.fileUrl(resource: fileName), 
                    let data = try? Data(contentsOf: url),
                    let img = SwiftMathImage(data: data) else {
                return ImageOpResult(label: label, error: NetworkImageError.imageError.nserr, image: nil)
            }
            return ImageOpResult(label: label, error: nil, image: img)
        }
        for (label, fileName) in imageEntries {
            Task {
                let result = await bundleImage(label: label, fileName: fileName)
                if result.error == nil, let image = result.image {
                    await ImageCacheManager.shared.updateCache(key: result.label, image: image)
                    await notifier.notify(key: result.label, error: nil)
                } else {
                    await notifier.notify(key: result.label, error: result.error)
                }
            }
        }

    }

    private enum NetworkImageError: Error {
        case responseError(resp: HTTPURLResponse?)
        case imageError
        var nserr: NSError {
            switch self {
            case .responseError(resp: let resp):
                let errorCode = resp?.statusCode ?? URLError.Code.unknown.rawValue
                let code = URLError.Code(rawValue: errorCode)
                return URLError(code, userInfo: [NSLocalizedDescriptionKey: localizedDescription]) as NSError
            case .imageError:
                return NSError(domain: "ImageDataService", code: 999, 
                               userInfo: [NSLocalizedDescriptionKey: localizedDescription])
            }
        }
    }
}

