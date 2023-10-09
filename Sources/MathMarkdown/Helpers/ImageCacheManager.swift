//
//  ImageCacheManager.swift
//
//
//  Created by Peter Tang on 19/9/2023.
//


import Foundation
import SwiftMath

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private init() { }
    
    private(set) var imageCache: NSCache<NSString, MTImage> = {
       var cache = NSCache<NSString, MTImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 1024 * 1024 * 100 // 100mb
        return cache
    }()
    
    func add(key: String, value: MTImage) {
        imageCache.setObject(value, forKey: key as NSString)
    }
    
    func get(key: String) -> MTImage? {
        return imageCache.object(forKey: key as NSString)
    }
    @MainActor public func updateCache(key: String, image: MTImage) async {
        ImageCacheManager.shared.add(key: key, value: image)
    }
}
