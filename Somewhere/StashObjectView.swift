//
//  StashObjectView.swift
//  Somewhere
//

import AppKit
import SwiftUI

struct StashObjectView: View {
    let item: CornerDrawerSession.Item

    @State private var isHovered = false

    var body: some View {
        content
            .scaleEffect(isHovered ? 1.012 : 1)
            .shadow(
                color: .black.opacity(isHovered ? 0.24 : 0.18),
                radius: isHovered ? 18 : 14,
                y: isHovered ? 8 : 6
            )
            .zIndex(isHovered ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
            .contextMenu { metadataMenu }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case let .image(image, _):
            imageClipping(image)
        case let .link(url, metadata):
            linkClipping(url: url, metadata: metadata)
        case let .text(text):
            textClipping(text)
        }
    }

    private func imageClipping(_ image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))

            if let note = cleanNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textClipping(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(textFont(for: text))
                .foregroundStyle(Color(red: 0.14, green: 0.14, blue: 0.137))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if let note = cleanNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.black.opacity(0.48))
                    .padding(.top, 10)
            }
        }
        .padding(textPadding(for: text))
        .background(textSurface)
        .clipShape(RoundedRectangle(cornerRadius: textCornerRadius, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func linkClipping(url: URL, metadata: URLPreviewMetadata?) -> some View {
        if let metadata, metadata.hasRichImage {
            richLinkClipping(metadata)
                .transition(.opacity)
        } else if let metadata {
            compactLinkClipping(metadata)
                .transition(.opacity)
        } else {
            loadingLinkClipping(url)
                .transition(.opacity)
        }
    }

    private func richLinkClipping(_ metadata: URLPreviewMetadata) -> some View {
        let accent = metadata.displayAccentColor
        let foreground = accent.contrastingTextColor

        return VStack(alignment: .leading, spacing: 0) {
            if let image = metadata.image {
                Color.clear
                    .aspectRatio(1.58, contentMode: .fit)
                    .overlay {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(metadata.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.94))
                    .lineLimit(2)

                Text(metadata.displayDomain)
                    .font(.caption)
                    .foregroundStyle(foreground.opacity(0.62))
                    .lineLimit(1)

                if let note = cleanNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(foreground.opacity(0.76))
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 11)
            .padding(.bottom, 12)
            .background(Color(nsColor: accent))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactLinkClipping(_ metadata: URLPreviewMetadata) -> some View {
        let accent = metadata.displayAccentColor
        let foreground = accent.contrastingTextColor

        return HStack(spacing: 10) {
            if metadata.imageRole == .favicon, let image = metadata.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
            } else {
                Text(metadata.displayDomain.prefix(1).uppercased())
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.72))
                    .frame(width: 26, height: 26)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(metadata.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.94))
                    .lineLimit(2)

                Text(metadata.displayDomain)
                    .font(.caption2)
                    .foregroundStyle(foreground.opacity(0.60))
                    .lineLimit(1)

                if let note = cleanNote {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(foreground.opacity(0.72))
                        .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color(nsColor: accent))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadingLinkClipping(_ url: URL) -> some View {
        HStack(spacing: 9) {
            ProgressView()
                .controlSize(.small)
                .tint(.white.opacity(0.72))

            Text(url.host(percentEncoded: false) ?? url.absoluteString)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color(red: 0.13, green: 0.14, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cleanNote: String? {
        let note = item.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return note?.isEmpty == false ? note : nil
    }

    private var textSurface: Color {
        switch item.visualVariant {
        case 0: Color(red: 0.91, green: 0.894, blue: 0.855)
        case 1: Color(red: 0.867, green: 0.894, blue: 0.882)
        default: Color(red: 0.894, green: 0.871, blue: 0.831)
        }
    }

    private var textCornerRadius: CGFloat {
        [8, 10, 9][item.visualVariant]
    }

    private var imageCornerRadius: CGFloat {
        [8, 10, 9][item.visualVariant]
    }

    private func textFont(for text: String) -> Font {
        switch text.count {
        case ...55: .system(size: 19, weight: .semibold)
        case ...180: .system(size: 16, weight: .medium)
        default: .system(size: 15, weight: .regular)
        }
    }

    private func textPadding(for text: String) -> EdgeInsets {
        let amount: CGFloat = text.count <= 55 ? 17 : 14
        return EdgeInsets(top: amount, leading: amount, bottom: amount, trailing: amount)
    }

    @ViewBuilder
    private var metadataMenu: some View {
        switch item.kind {
        case let .image(_, name):
            if let name, !name.isEmpty {
                Text(name)
            }
        case let .link(url, metadata):
            let targetURL = metadata?.canonicalURL ?? url
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(targetURL.absoluteString, forType: .string)
            }
            Divider()
            if let siteName = metadata?.siteName {
                Text(siteName)
            }
            Text(targetURL.absoluteString)
        case let .text(text):
            Button("Copy Text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
    }
}

extension CornerDrawerSession.Item {
    var stableSeed: UInt64 {
        id.uuidString.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    var visualVariant: Int {
        Int(stableSeed % 3)
    }

    var mosaicAttributes: MosaicAttributes {
        let percentile = Int(stableSeed % 100)
        let span: Int

        switch kind {
        case let .image(image, _):
            let ratio = image.naturalAspectRatio
            if ratio >= 1.55 {
                span = 3
            } else if ratio >= 1.05 {
                span = percentile < 20 ? 3 : 2
            } else {
                span = percentile < 35 ? 2 : 1
            }
        case let .text(text):
            if text.count <= 55 {
                span = percentile < 35 ? 2 : 1
            } else if text.count <= 180 {
                span = 2
            } else {
                span = 3
            }
        case let .link(_, metadata):
            if metadata?.hasRichImage == true {
                span = percentile < 20 ? 3 : 2
            } else {
                span = 2
            }
        }

        return MosaicAttributes(span: span, tieBreak: stableSeed)
    }
}

private extension NSImage {
    var naturalAspectRatio: CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return size.width / size.height
    }
}

private extension NSColor {
    var contrastingTextColor: Color {
        let color = usingColorSpace(.sRGB) ?? self

        func linearized(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }

        let luminance = 0.2126 * linearized(color.redComponent)
            + 0.7152 * linearized(color.greenComponent)
            + 0.0722 * linearized(color.blueComponent)
        let blackContrast = (luminance + 0.05) / 0.05
        let whiteContrast = 1.05 / (luminance + 0.05)
        return blackContrast >= whiteContrast ? .black : .white
    }
}

#if DEBUG
private extension NSImage {
    static func previewGradient(size: NSSize, colors: [NSColor]) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSGradient(colors: colors)?.draw(in: rect, angle: -32)
            return true
        }
    }
}

#Preview("Editorial mosaic objects") {
    let landscape = NSImage.previewGradient(
        size: NSSize(width: 480, height: 260),
        colors: [.systemIndigo, .systemTeal]
    )
    let preview = NSImage.previewGradient(
        size: NSSize(width: 480, height: 300),
        colors: [.systemOrange, .systemPink]
    )
    let metadata = URLPreviewMetadata.preview(
        title: "A saved corner of the internet",
        domain: "example.com",
        image: preview,
        accent: NSColor(srgbRed: 0.28, green: 0.20, blue: 0.16, alpha: 1)
    )
    let items = [
        CornerDrawerSession.Item(kind: .image(landscape, name: nil)),
        CornerDrawerSession.Item(kind: .text("A small thought worth keeping.")),
        CornerDrawerSession.Item(kind: .link(URL(string: "https://example.com")!, metadata: metadata)),
        CornerDrawerSession.Item(kind: .text("Longer fragments have room to become part of the composition instead of being squeezed into the same component."))
    ]

    ZStack {
        Color(red: 0.10, green: 0.11, blue: 0.10)
        EditorialMosaicLayout {
            ForEach(items) { item in
                StashObjectView(item: item)
                    .mosaicAttributes(item.mosaicAttributes)
            }
        }
        .frame(width: 420)
        .padding(24)
    }
    .frame(width: 468, height: 720)
    .preferredColorScheme(.dark)
}
#endif
