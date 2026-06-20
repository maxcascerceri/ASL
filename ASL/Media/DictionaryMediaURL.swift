//
//  DictionaryMediaURL.swift
//  ASL
//
//  Single canonical HTTPS URL builder for dictionary posters and videos.
//

import Foundation

enum DictionaryMediaURL {
    static let bucket = "asl-app-718bf.firebasestorage.app"

    static func url(storagePath: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = storagePath.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        let pathEncoded = encoded.replacingOccurrences(of: "/", with: "%2F")
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(pathEncoded)?alt=media")
    }
}
