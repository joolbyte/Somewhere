//
//  CornerDrawerView.swift
//  Somewhere
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Temporary contents for the current app session.
/// Nothing here is written to SwiftData or copied to Application Support yet.
@MainActor
final class CornerDrawerSession: ObservableObject {
    struct Item: Identifiable {
        enum Kind {
            case image(NSImage, name: String?)
            case link(URL, metadata: URLPreviewMetadata?)
            case text(String)
        }

        let id: UUID
        var kind: Kind
        var note: String?

        init(id: UUID = UUID(), kind: Kind, note: String? = nil) {
            self.id = id
            self.kind = kind
            self.note = note
        }
    }

    @Published private(set) var items: [Item] = []

    func receive(_ providers: [NSItemProvider]) {
        Task { [weak self] in
            for provider in providers {
                guard let item = await DropItemDecoder.decode(provider) else { continue }

                withAnimation(.easeOut(duration: 0.18)) {
                    self?.items.append(item)
                }

                if case let .link(url, _) = item.kind {
                    self?.loadURLMetadata(for: item.id, url: url)
                }
            }
        }
    }

    private func loadURLMetadata(for id: UUID, url: URL) {
        Task { [weak self] in
            let metadata = await URLMetadataService.shared.metadata(for: url)

            guard let self,
                  let index = items.firstIndex(where: { $0.id == id }),
                  case .link = items[index].kind else { return }

            withAnimation(.easeOut(duration: 0.18)) {
                self.items[index].kind = .link(url, metadata: metadata)
            }
        }
    }
}

struct CornerDrawerView: View {
    private enum Layout {
        static let boardWidth: CGFloat = 420
        static let interactiveWidth: CGFloat = 468
        static let horizontalPadding: CGFloat = 24
    }

    @ObservedObject var session: CornerDrawerSession
    @State private var isDropTargeted = false
    @State private var searchText = ""

    private var visibleItems: [CornerDrawerSession.Item] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return session.items }

        return session.items.filter { item in
            switch item.kind {
            case let .image(_, name):
                return name?.localizedCaseInsensitiveContains(query) ?? false
            case let .link(url, metadata):
                return (metadata?.title.localizedCaseInsensitiveContains(query) ?? false)
                    || url.absoluteString.localizedCaseInsensitiveContains(query)
            case let .text(text):
                return text.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                GlassyGradientBackground()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.31),
                        .init(color: .black.opacity(0.03), location: 0.52),
                        .init(color: .black.opacity(0.09), location: 0.76),
                        .init(color: .black.opacity(0.15), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    header

                    drawerContents
                        .padding(.top, 20)

                    Spacer(minLength: 0)
                }

                if isDropTargeted {
                    dropHighlight
                }
            }
            .contentShape(Rectangle())
            .onDrop(
                of: [.fileURL, .url, .plainText, .image],
                isTargeted: $isDropTargeted,
                perform: acceptDrop(providers:)
            )
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 10) {
                Text("Somewhere")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)

                SidebarSearchField(text: $searchText, placeholder: "Search Somewhere")
                    .frame(width: 300, height: 28)
            }
            .padding(.top, 40)
            .padding(.trailing, Layout.horizontalPadding)
        }
    }

    private var drawerContents: some View {
        ScrollView(showsIndicators: false) {
            EditorialMosaicLayout(trackCount: 3, spacing: 10) {
                ForEach(visibleItems) { item in
                    StashObjectView(item: item)
                        .mosaicAttributes(item.mosaicAttributes)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: mosaicAnimationValue)
            .frame(width: Layout.boardWidth)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, 28)
        }
    }

    private var mosaicAnimationValue: [String] {
        visibleItems.map { item in
            "\(item.id.uuidString)-\(item.mosaicAttributes.span)"
        }
    }

    private var dropHighlight: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            LinearGradient(
                colors: [.clear, .white.opacity(0.025), .white.opacity(0.055)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Layout.interactiveWidth)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 1)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
    }

    private func acceptDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        session.receive(providers)
        return true
    }
}

private enum DropItemDecoder {
    static func decode(_ provider: NSItemProvider) async -> CornerDrawerSession.Item? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = await url(from: provider, type: .fileURL) {
            return item(forImageFileURL: url)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let image = await image(from: provider) {
            return .init(kind: .image(image, name: provider.suggestedName))
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await url(from: provider, type: .url),
           url.isWebURL {
            return .init(kind: .link(url, metadata: nil))
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = await text(from: provider),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmedText), url.isWebURL {
                return .init(kind: .link(url, metadata: nil))
            }
            return .init(kind: .text(text))
        }

        return nil
    }

    static func image(from provider: NSItemProvider) async -> NSImage? {
        let identifier = provider.registeredTypeIdentifiers.first { identifier in
            UTType(identifier)?.conforms(to: .image) == true
        } ?? UTType.image.identifier

        return await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, _ in
                continuation.resume(returning: data.flatMap(NSImage.init(data:)))
            }
        }
    }

    private static func url(from provider: NSItemProvider, type: UTType) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                } else if let data = item as? Data {
                    continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                } else if let string = item as? String {
                    continuation.resume(returning: URL(string: string))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func text(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSString.self) { object, _ in
                continuation.resume(returning: (object as? NSString).map(String.init))
            }
        }
    }

    private static func item(forImageFileURL url: URL) -> CornerDrawerSession.Item? {
        guard let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
              contentType.conforms(to: .image) else { return nil }

        guard let image = NSImage(contentsOf: url) else { return nil }
        return .init(kind: .image(image, name: url.lastPathComponent))
    }
}

private extension URL {
    var isWebURL: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
