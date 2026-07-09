//
//  StashItem.swift
//  Somewhere
//

import Foundation
import SwiftData

enum StashItemKind: String, CaseIterable, Codable {
    case text
    case link
    case file
    case image

    var displayName: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .text: "text.quote"
        case .link: "link"
        case .file: "doc"
        case .image: "photo"
        }
    }
}

@Model
final class StashItem {
    var createdAt: Date
    var updatedAt: Date
    var kindRawValue: String
    var title: String
    var note: String?
    var textContent: String?
    var sourceURL: String?
    var originalFilename: String?
    var storedFilePath: String?

    init(
        kind: StashItemKind,
        title: String,
        note: String? = nil,
        textContent: String? = nil,
        sourceURL: String? = nil,
        originalFilename: String? = nil,
        storedFilePath: String? = nil,
        createdAt: Date = .now
    ) {
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.kindRawValue = kind.rawValue
        self.title = title
        self.note = note
        self.textContent = textContent
        self.sourceURL = sourceURL
        self.originalFilename = originalFilename
        self.storedFilePath = storedFilePath
    }

    var kind: StashItemKind {
        StashItemKind(rawValue: kindRawValue) ?? .text
    }

    var previewText: String? {
        textContent ?? sourceURL ?? originalFilename
    }
}
