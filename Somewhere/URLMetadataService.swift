//
//  URLMetadataService.swift
//  Somewhere
//

import AppKit
import Foundation
import ImageIO

nonisolated struct URLPreviewMetadata: @unchecked Sendable {
    enum ImageRole: Sendable {
        case preview
        case favicon
        case none
    }

    let requestedURL: URL
    let resolvedURL: URL
    let canonicalURL: URL
    let title: String
    let siteName: String?
    let image: NSImage?
    let imageRole: ImageRole
    let pagePrimaryColor: NSColor?
    let dominantImageColor: NSColor?
    let displayAccentColor: NSColor
    let failed: Bool

    var hasRichImage: Bool {
        imageRole == .preview && image != nil
    }

    var displayDomain: String {
        canonicalURL.host(percentEncoded: false)
            ?? resolvedURL.host(percentEncoded: false)
            ?? requestedURL.absoluteString
    }

#if DEBUG
    static func preview(
        title: String,
        domain: String,
        image: NSImage?,
        accent: NSColor
    ) -> URLPreviewMetadata {
        let url = URL(string: "https://\(domain)")!
        return URLPreviewMetadata(
            requestedURL: url,
            resolvedURL: url,
            canonicalURL: url,
            title: title,
            siteName: domain,
            image: image,
            imageRole: image == nil ? .none : .preview,
            pagePrimaryColor: accent,
            dominantImageColor: accent,
            displayAccentColor: accent,
            failed: false
        )
    }
#endif
}

actor URLMetadataService {
    static let shared = URLMetadataService()

    private struct CachedImage: @unchecked Sendable {
        let image: NSImage
        let dominantColor: NSColor?
    }

    private struct ColorBucket {
        var score: CGFloat = 0
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0

        mutating func add(red: CGFloat, green: CGFloat, blue: CGFloat, weight: CGFloat) {
            score += weight
            self.red += red * weight
            self.green += green * weight
            self.blue += blue * weight
        }
    }

    private var metadataCache: [URL: URLPreviewMetadata] = [:]
    private var imageCache: [URL: CachedImage] = [:]
    private var inFlight: [URL: Task<URLPreviewMetadata, Never>] = [:]
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.urlCache = URLCache(
            memoryCapacity: 24 * 1_024 * 1_024,
            diskCapacity: 0
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    func metadata(for url: URL) async -> URLPreviewMetadata {
        let cacheKey = url.normalizedForMetadataCache

        if let cached = metadataCache[cacheKey] {
            return cached
        }

        if let task = inFlight[cacheKey] {
            return await task.value
        }

        let task = Task { await fetchMetadata(for: url) }
        inFlight[cacheKey] = task
        let metadata = await task.value
        metadataCache[cacheKey] = metadata
        inFlight[cacheKey] = nil
        return metadata
    }

    private func fetchMetadata(for requestedURL: URL) async -> URLPreviewMetadata {
        var request = URLRequest(url: requestedURL)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<400).contains(httpResponse.statusCode),
                  let html = HTMLMetadataParser.decodeHTML(data) else {
                return fallback(for: requestedURL, failed: true)
            }

            let resolvedURL = httpResponse.url ?? requestedURL
            let document = HTMLMetadataParser(html: html, baseURL: resolvedURL)
            let canonicalURL = document.canonicalURL ?? resolvedURL
            let title = document.openGraphTitle?.trimmedNonEmpty
                ?? document.htmlTitle?.trimmedNonEmpty
                ?? Self.cleanedPathTitle(for: canonicalURL)
                ?? canonicalURL.host(percentEncoded: false)
                ?? requestedURL.absoluteString

            let previewURL = document.openGraphImageURL ?? document.twitterImageURL
            let previewAsset: CachedImage?
            if let previewURL {
                previewAsset = await loadImage(at: previewURL)
            } else {
                previewAsset = nil
            }
            let faviconAsset: CachedImage?

            if previewAsset == nil, let faviconURL = document.faviconURL {
                faviconAsset = await loadImage(at: faviconURL)
            } else {
                faviconAsset = nil
            }

            let selectedAsset = previewAsset ?? faviconAsset
            let imageRole: URLPreviewMetadata.ImageRole = if previewAsset != nil {
                .preview
            } else if faviconAsset != nil {
                .favicon
            } else {
                .none
            }

            let pagePrimaryColor = document.primaryColor?.opaqueSRGB
            let dominantImageColor = selectedAsset?.dominantColor?.opaqueSRGB
            let displayAccentColor = Self.displayAccentColor(
                pageColor: pagePrimaryColor,
                dominantColor: dominantImageColor,
                domain: canonicalURL.host(percentEncoded: false) ?? requestedURL.absoluteString
            )

            return URLPreviewMetadata(
                requestedURL: requestedURL,
                resolvedURL: resolvedURL,
                canonicalURL: canonicalURL,
                title: title,
                siteName: document.siteName?.trimmedNonEmpty,
                image: selectedAsset?.image,
                imageRole: imageRole,
                pagePrimaryColor: pagePrimaryColor,
                dominantImageColor: dominantImageColor,
                displayAccentColor: displayAccentColor,
                failed: false
            )
        } catch {
            return fallback(for: requestedURL, failed: true)
        }
    }

    private func loadImage(at url: URL) async -> CachedImage? {
        let cacheKey = url.normalizedForMetadataCache
        if let cached = imageCache[cacheKey] {
            return cached
        }

        var request = URLRequest(url: url)
        request.setValue("image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode),
              let image = NSImage(data: data) else { return nil }

        let asset = CachedImage(
            image: image,
            dominantColor: Self.dominantColor(from: data)
        )
        imageCache[cacheKey] = asset
        return asset
    }

    private func fallback(for url: URL, failed: Bool) -> URLPreviewMetadata {
        URLPreviewMetadata(
            requestedURL: url,
            resolvedURL: url,
            canonicalURL: url,
            title: Self.cleanedPathTitle(for: url)
                ?? url.host(percentEncoded: false)
                ?? url.absoluteString,
            siteName: nil,
            image: nil,
            imageRole: .none,
            pagePrimaryColor: nil,
            dominantImageColor: nil,
            displayAccentColor: Self.displayAccentColor(
                pageColor: nil,
                dominantColor: nil,
                domain: url.host(percentEncoded: false) ?? url.absoluteString
            ),
            failed: failed
        )
    }

    private static func cleanedPathTitle(for url: URL) -> String? {
        let path = url.path(percentEncoded: false)
            .split(separator: "/")
            .last
            .map(String.init)?
            .removingPercentEncoding
            ?? url.pathComponents.last

        guard let path, path != "/", !path.isEmpty else { return nil }
        let withoutExtension = (path as NSString).deletingPathExtension
        let cleaned = withoutExtension
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "+", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return cleaned.trimmedNonEmpty
    }

    private static func dominantColor(from data: Data) -> NSColor? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let didDraw = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }

            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard didDraw else { return nil }

        var buckets: [Int: ColorBucket] = [:]

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = CGFloat(pixels[index + 3]) / 255
            guard alpha > 0.18 else { continue }

            let red = CGFloat(pixels[index]) / 255
            let green = CGFloat(pixels[index + 1]) / 255
            let blue = CGFloat(pixels[index + 2]) / 255
            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let delta = maximum - minimum
            let saturation = maximum == 0 ? 0 : delta / maximum
            let brightness = maximum

            guard brightness > 0.10,
                  brightness < 0.92,
                  saturation > 0.12 else { continue }

            let hue: CGFloat
            if delta == 0 {
                hue = 0
            } else if maximum == red {
                hue = (((green - blue) / delta).truncatingRemainder(dividingBy: 6) + 6)
                    .truncatingRemainder(dividingBy: 6) / 6
            } else if maximum == green {
                hue = (((blue - red) / delta) + 2) / 6
            } else {
                hue = (((red - green) / delta) + 4) / 6
            }

            let hueBucket = min(Int(hue * 12), 11)
            let saturationBucket = min(Int(saturation * 3), 2)
            let brightnessBucket = min(Int(brightness * 3), 2)
            let key = hueBucket * 9 + saturationBucket * 3 + brightnessBucket
            let midtoneWeight = 1 - abs(brightness - 0.55)
            let weight = 1 + saturation * 0.65 + midtoneWeight * 0.25

            var bucket = buckets[key, default: ColorBucket()]
            bucket.add(red: red, green: green, blue: blue, weight: weight)
            buckets[key] = bucket
        }

        guard let bucket = buckets.values.max(by: { $0.score < $1.score }),
              bucket.score > 0 else { return nil }

        return NSColor(
            srgbRed: bucket.red / bucket.score,
            green: bucket.green / bucket.score,
            blue: bucket.blue / bucket.score,
            alpha: 1
        )
    }

    private static func displayAccentColor(
        pageColor: NSColor?,
        dominantColor: NSColor?,
        domain: String
    ) -> NSColor {
        let source: NSColor
        if let pageColor, isUsefulAccent(pageColor) {
            source = pageColor
        } else if let dominantColor, isUsefulAccent(dominantColor) {
            source = dominantColor
        } else {
            source = domainColor(for: domain)
        }

        let color = source.usingColorSpace(.sRGB) ?? source
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let resolvedSaturation = min(max(saturation, 0.28), 0.58)
        let resolvedBrightness = min(max(brightness * 0.60, 0.24), 0.40)
        return NSColor(
            calibratedHue: hue,
            saturation: resolvedSaturation,
            brightness: resolvedBrightness,
            alpha: 1
        ).opaqueSRGB
    }

    private static func isUsefulAccent(_ color: NSColor) -> Bool {
        let color = color.usingColorSpace(.sRGB) ?? color
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return alpha > 0.18
            && saturation > 0.08
            && brightness > 0.08
            && brightness < 0.92
    }

    private static func domainColor(for domain: String) -> NSColor {
        let hash = domain.lowercased().utf8.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        let hue = CGFloat(hash % 360) / 360
        return NSColor(calibratedHue: hue, saturation: 0.34, brightness: 0.32, alpha: 1)
    }
}

private nonisolated struct HTMLMetadataParser {
    let openGraphTitle: String?
    let htmlTitle: String?
    let siteName: String?
    let openGraphImageURL: URL?
    let twitterImageURL: URL?
    let faviconURL: URL?
    let canonicalURL: URL?
    let primaryColor: NSColor?

    init(html: String, baseURL: URL) {
        let metaTags = Self.tags(named: "meta", in: html)
        var metadata: [String: String] = [:]

        for tag in metaTags {
            let attributes = Self.attributes(in: tag)
            guard let key = (attributes["property"] ?? attributes["name"] ?? attributes["itemprop"])?.lowercased(),
                  let content = attributes["content"]?.decodedHTMLEntities.trimmedNonEmpty else { continue }
            if metadata[key] == nil {
                metadata[key] = content
            }
        }

        let links = Self.tags(named: "link", in: html).map(Self.attributes(in:))
        let canonical = links.first { attributes in
            Self.relTokens(in: attributes).contains("canonical")
        }?["href"]
        let favicon = links.first { attributes in
            let rel = Self.relTokens(in: attributes)
            return rel.contains("icon") || rel.contains("shortcut") || rel.contains("apple-touch-icon")
        }?["href"]

        openGraphTitle = metadata["og:title"]
        siteName = metadata["og:site_name"]
        openGraphImageURL = Self.resolvedURL(
            metadata["og:image:secure_url"] ?? metadata["og:image"],
            relativeTo: baseURL
        )
        twitterImageURL = Self.resolvedURL(
            metadata["twitter:image"] ?? metadata["twitter:image:src"],
            relativeTo: baseURL
        )
        faviconURL = Self.resolvedURL(favicon, relativeTo: baseURL)
            ?? URL(string: "/favicon.ico", relativeTo: baseURL)?.absoluteURL
        canonicalURL = Self.resolvedURL(canonical, relativeTo: baseURL)
        primaryColor = NSColor(cssColor: metadata["theme-color"] ?? metadata["msapplication-tilecolor"])
        htmlTitle = Self.firstCapture(
            pattern: #"<title\b[^>]*>(.*?)</title>"#,
            in: html
        )?.removingHTMLTags.decodedHTMLEntities.trimmedNonEmpty
    }

    static func decodeHTML(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(data: data, encoding: .windowsCP1252)
    }

    private static func tags(named name: String, in html: String) -> [String] {
        matches(pattern: #"<"# + name + #"\b[^>]*>"#, in: html)
    }

    private static func attributes(in tag: String) -> [String: String] {
        let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\"'=<>`]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [:] }
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        var result: [String: String] = [:]

        for match in regex.matches(in: tag, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: tag) else { continue }
            let valueRange = (2...4)
                .lazy
                .map { match.range(at: $0) }
                .first { $0.location != NSNotFound }
                .flatMap { Range($0, in: tag) }
            guard let valueRange else { continue }
            result[String(tag[keyRange]).lowercased()] = String(tag[valueRange])
        }
        return result
    }

    private static func relTokens(in attributes: [String: String]) -> Set<String> {
        Set((attributes["rel"] ?? "").lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
    }

    private static func resolvedURL(_ value: String?, relativeTo baseURL: URL) -> URL? {
        guard let value = value?.decodedHTMLEntities.trimmedNonEmpty else { return nil }
        if value.hasPrefix("//") {
            return URL(string: (baseURL.scheme ?? "https") + ":" + value)
        }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }
}

private nonisolated extension URL {
    var normalizedForMetadataCache: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else { return self }
        components.fragment = nil
        return components.url ?? self
    }
}

private nonisolated extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var removingHTMLTags: String {
        replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }

    var decodedHTMLEntities: String {
        var result = self
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .replacingOccurrences(of: "&apos;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "&#39;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "&lt;", with: "<", options: .caseInsensitive)
            .replacingOccurrences(of: "&gt;", with: ">", options: .caseInsensitive)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)

        guard let regex = try? NSRegularExpression(
            pattern: #"&#(x?[0-9a-f]+);"#,
            options: [.caseInsensitive]
        ) else { return result }

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..<result.endIndex, in: result))
        for match in matches.reversed() {
            guard let wholeRange = Range(match.range(at: 0), in: result),
                  let numberRange = Range(match.range(at: 1), in: result) else { continue }
            let token = String(result[numberRange])
            let radix = token.lowercased().hasPrefix("x") ? 16 : 10
            let digits = radix == 16 ? String(token.dropFirst()) : token
            guard let value = UInt32(digits, radix: radix),
                  let scalar = UnicodeScalar(value) else { continue }
            result.replaceSubrange(wholeRange, with: String(Character(scalar)))
        }
        return result
    }
}

private nonisolated extension NSColor {
    convenience init?(cssColor value: String?) {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !value.isEmpty else { return nil }

        if value.hasPrefix("#") {
            value.removeFirst()
            let expanded: String
            switch value.count {
            case 3, 4:
                expanded = value.map { "\($0)\($0)" }.joined()
            case 6, 8:
                expanded = value
            default:
                return nil
            }

            guard let number = UInt64(expanded, radix: 16) else { return nil }
            let hasAlpha = expanded.count == 8
            let red = CGFloat((number >> (hasAlpha ? 24 : 16)) & 0xff) / 255
            let green = CGFloat((number >> (hasAlpha ? 16 : 8)) & 0xff) / 255
            let blue = CGFloat((number >> (hasAlpha ? 8 : 0)) & 0xff) / 255
            let alpha = hasAlpha ? CGFloat(number & 0xff) / 255 : 1
            self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
            return
        }

        guard value.hasPrefix("rgb"),
              let open = value.firstIndex(of: "("),
              let close = value.lastIndex(of: ")") else { return nil }
        let components = value[value.index(after: open)..<close]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count >= 3 else { return nil }

        func channel(_ component: String) -> CGFloat? {
            if component.hasSuffix("%"), let number = Double(component.dropLast()) {
                return CGFloat(number / 100)
            }
            guard let number = Double(component) else { return nil }
            return CGFloat(number / 255)
        }

        guard let red = channel(components[0]),
              let green = channel(components[1]),
              let blue = channel(components[2]) else { return nil }
        let alpha = components.count > 3 ? CGFloat(Double(components[3]) ?? 1) : 1
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var opaqueSRGB: NSColor {
        let converted = usingColorSpace(.sRGB) ?? self
        return NSColor(
            srgbRed: converted.redComponent,
            green: converted.greenComponent,
            blue: converted.blueComponent,
            alpha: 1
        )
    }
}
