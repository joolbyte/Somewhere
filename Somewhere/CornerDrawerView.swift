//
//  CornerDrawerView.swift
//  Somewhere
//

import AppKit
import Combine
import LinkPresentation
import SwiftUI
import UniformTypeIdentifiers

/// Temporary contents for the current app session.
/// Nothing here is written to SwiftData or copied to Application Support yet.
@MainActor
final class CornerDrawerSession: ObservableObject {
    struct Item: Identifiable {
        enum Kind {
            case image(NSImage, name: String?)
            case link(URL, title: String, preview: NSImage?)
            case text(String)
            case file(name: String, type: String)
        }

        let id = UUID()
        var kind: Kind
    }

    @Published private(set) var items: [Item] = []

    func receive(_ providers: [NSItemProvider]) {
        Task { [weak self] in
            for provider in providers {
                guard let item = await DropItemDecoder.decode(provider) else { continue }
                self?.items.append(item)

                if case let .link(url, _, _) = item.kind {
                    self?.loadLinkPreview(for: item.id, url: url)
                }
            }
        }
    }

    private func loadLinkPreview(for id: UUID, url: URL) {
        Task { [weak self] in
            let provider = LPMetadataProvider()
            guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return }
            let preview = await DropItemDecoder.image(from: metadata.imageProvider)

            guard let index = self?.items.firstIndex(where: { $0.id == id }),
                  case let .link(_, currentTitle, _) = self?.items[index].kind else { return }
            self?.items[index].kind = .link(
                url,
                title: metadata.title?.nonEmpty ?? currentTitle,
                preview: preview
            )
        }
    }
}

struct CornerDrawerView: View {
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
            case let .link(url, title, _):
                return title.localizedCaseInsensitiveContains(query)
                    || url.absoluteString.localizedCaseInsensitiveContains(query)
            case let .text(text):
                return text.localizedCaseInsensitiveContains(query)
            case let .file(name, type):
                return name.localizedCaseInsensitiveContains(query)
                    || type.localizedCaseInsensitiveContains(query)
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
                        .init(color: .clear, location: 0.42),
                        .init(color: .black.opacity(0.035), location: 0.64),
                        .init(color: .black.opacity(0.10), location: 0.84),
                        .init(color: .black.opacity(0.16), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 12) {
                            Text("Somewhere")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)

                            SidebarSearchField(text: $searchText, placeholder: "Search Somewhere")
                                .frame(width: 248, height: 28)
                        }
                        .padding(.top, 42)
                        .padding(.trailing, 28)
                    }

                    drawerContents
                        .padding(.top, 28)

                    Spacer(minLength: 0)
                }

                if isDropTargeted {
                    dropHighlight
                }
            }
            .contentShape(Rectangle())
            .onDrop(
                of: [.fileURL, .url, .plainText, .image, .pdf, .movie, .audio, .data],
                isTargeted: $isDropTargeted,
                perform: acceptDrop(providers:)
            )
        }
        .preferredColorScheme(.dark)
    }

    private var drawerContents: some View {
        ScrollView(showsIndicators: false) {
            StashMasonryLayout(spacing: 10) {
                ForEach(visibleItems) { item in
                    TemporaryStashCard(item: item)
                        .layoutValue(key: StashCardSpanKey.self, value: item.prefersFullWidth)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: visibleItems.map(\.id))
            .frame(width: 292)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 28)
            .padding(.leading, 28)
            .padding(.bottom, 24)
        }
    }

    private var dropHighlight: some View {
        HStack {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 126)
                .padding(.bottom, 24)
                .padding(.trailing, 16)
                .frame(width: 324)
                .allowsHitTesting(false)
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
    }

    private func acceptDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        session.receive(providers)
        return true
    }
}

private struct TemporaryStashCard: View {
    let item: CornerDrawerSession.Item

    var body: some View {
        Group {
            switch item.kind {
            case let .image(image, _):
                imageCard(image: image)
            case let .link(url, title, preview):
                linkCard(url: url, title: title, preview: preview)
            case let .text(text):
                textCard(text)
            case let .file(name, _):
                fileCard(name: name)
            }
        }
        .contextMenu { metadataMenu }
    }

    private func imageCard(image: NSImage) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
    }

    private func linkCard(url: URL, title: String, preview: NSImage?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            linkPreview(preview: preview, url: url)
                .aspectRatio(1.7, contentMode: .fit)
                .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(2)

                Text(url.host(percentEncoded: false) ?? url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .drawerCardBackground(cornerRadius: 16)
    }

    @ViewBuilder
    private func linkPreview(preview: NSImage?, url: URL) -> some View {
        if let preview {
            Image(nsImage: preview)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [.white.opacity(0.15), .white.opacity(0.045)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Text((url.host(percentEncoded: false) ?? url.absoluteString).prefix(1).uppercased())
                    .font(.system(size: 36, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
    }

    private func textCard(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.white.opacity(0.94))
            .lineLimit(7)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
            .padding(14)
            .drawerCardBackground(cornerRadius: 16)
    }

    private func fileCard(name: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "doc")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.70))
                .frame(width: 42, height: 46)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 0)

            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .padding(13)
        .drawerCardBackground(cornerRadius: 16)
    }

    @ViewBuilder
    private var metadataMenu: some View {
        switch item.kind {
        case let .image(_, name):
            if let name, !name.isEmpty {
                Text(name)
            }
        case let .link(url, _, _):
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
            Divider()
            Text(url.absoluteString)
        case let .text(text):
            Button("Copy Text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        case let .file(name, type):
            Text(name)
            Text(type)
        }
    }
}

private extension View {
    func drawerCardBackground(cornerRadius: CGFloat) -> some View {
        background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            }
    }
}

private extension CornerDrawerSession.Item {
    var prefersFullWidth: Bool {
        switch kind {
        case .link:
            true
        case let .text(text):
            text.count > 90
        case .image, .file:
            false
        }
    }
}

private nonisolated struct StashCardSpanKey: LayoutValueKey {
    static let defaultValue = false
}

/// A compact two-column layout that lets smaller cards settle independently,
/// while rich links and longer text are given the full width they need.
private nonisolated struct StashMasonryLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 292
        let placements = placements(for: subviews, width: width)
        let height = placements.map { $0.origin.y + $0.size.height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for placement in placements(for: subviews, width: bounds.width) {
            subviews[placement.index].place(
                at: CGPoint(x: bounds.minX + placement.origin.x, y: bounds.minY + placement.origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: placement.size.width, height: placement.size.height)
            )
        }
    }

    private func placements(for subviews: Subviews, width: CGFloat) -> [Placement] {
        let columnWidth = max(0, (width - spacing) / 2)
        var columnHeights = [CGFloat.zero, CGFloat.zero]
        var placements: [Placement] = []

        for index in subviews.indices {
            let subview = subviews[index]
            let spansColumns = subview[StashCardSpanKey.self]
            let cardWidth = spansColumns ? width : columnWidth
            let size = subview.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil))

            if spansColumns {
                let y = max(columnHeights[0], columnHeights[1])
                placements.append(.init(index: index, origin: CGPoint(x: 0, y: y), size: size))
                let nextY = y + size.height + spacing
                columnHeights = [nextY, nextY]
            } else {
                let column = columnHeights[0] <= columnHeights[1] ? 0 : 1
                let x = column == 0 ? 0 : columnWidth + spacing
                placements.append(.init(index: index, origin: CGPoint(x: x, y: columnHeights[column]), size: size))
                columnHeights[column] += size.height + spacing
            }
        }

        return placements
    }

    private struct Placement {
        let index: Int
        let origin: CGPoint
        let size: CGSize
    }
}

private enum DropItemDecoder {
    static func decode(_ provider: NSItemProvider) async -> CornerDrawerSession.Item? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = await url(from: provider, type: .fileURL) {
            return item(forFileURL: url)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let image = await image(from: provider) {
            return .init(kind: .image(image, name: provider.suggestedName))
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await url(from: provider, type: .url),
           url.isFileURL == false {
            return .init(kind: .link(url, title: url.host(percentEncoded: false) ?? url.absoluteString, preview: nil))
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = await text(from: provider),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .init(kind: .text(text))
        }

        guard let identifier = provider.registeredTypeIdentifiers.first(where: { identifier in
            UTType(identifier)?.conforms(to: .data) == true
        }) else { return nil }

        return .init(kind: .file(
            name: provider.suggestedName ?? "Untitled file",
            type: UTType(identifier)?.localizedDescription ?? "File"
        ))
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

    static func image(from provider: NSItemProvider?) async -> NSImage? {
        guard let provider else { return nil }
        return await image(from: provider)
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

    private static func item(forFileURL url: URL) -> CornerDrawerSession.Item {
        if let image = NSImage(contentsOf: url) {
            return .init(kind: .image(image, name: url.lastPathComponent))
        }

        let type = UTType(filenameExtension: url.pathExtension)?.localizedDescription ?? "File"
        return .init(kind: .file(name: url.lastPathComponent, type: type))
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
