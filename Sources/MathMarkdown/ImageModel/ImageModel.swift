//
//  ImageModel.swift
//  
//
//  Created by Peter Tang on 19/9/2023.
//

import Foundation

struct ImageModel: Identifiable, Codable {
    let albumId: Int
    let id: Int
    let title: String
    let url: String
    let thumbnailUrl: String
}
import CryptoKit

public extension Data {
    var md5: String {
        Insecure.MD5
        .hash(data: self)
        .map {String(format: "%02x", $0)}
        .joined()
    }
}
public extension String {
    var data: Data? {
        self.data(using: .utf8)
    }
}
