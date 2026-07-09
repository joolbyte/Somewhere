//
//  GlassyGradientBackground.swift
//  Somewhere
//

import AppKit
import SwiftUI

/// A native macOS vibrancy surface whose opacity dissolves from glass to clear.
struct GlassyGradientBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> GradientVisualEffectView {
        GradientVisualEffectView()
    }

    func updateNSView(_ nsView: GradientVisualEffectView, context: Context) {}
}

final class GradientVisualEffectView: NSView {
    private let visualEffectView = NSVisualEffectView()
    private let gradientMask = CAGradientLayer()
    private let edgeHighlight = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.masksToBounds = true

        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        addSubview(visualEffectView)

        gradientMask.startPoint = CGPoint(x: 0, y: 0.5)
        gradientMask.endPoint = CGPoint(x: 1, y: 0.5)
        gradientMask.locations = [0, 0.16, 0.40, 0.66, 0.86, 1]
        gradientMask.colors = [
            NSColor.black.withAlphaComponent(0).cgColor,
            NSColor.black.withAlphaComponent(0.02).cgColor,
            NSColor.black.withAlphaComponent(0.22).cgColor,
            NSColor.black.withAlphaComponent(0.72).cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor
        ]
        visualEffectView.layer?.mask = gradientMask

        edgeHighlight.startPoint = CGPoint(x: 0, y: 0.5)
        edgeHighlight.endPoint = CGPoint(x: 1, y: 0.5)
        edgeHighlight.locations = [0, 0.86, 1]
        edgeHighlight.colors = [
            NSColor.clear.cgColor,
            NSColor.white.withAlphaComponent(0.01).cgColor,
            NSColor.white.withAlphaComponent(0.07).cgColor
        ]
        layer?.addSublayer(edgeHighlight)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        visualEffectView.frame = bounds
        gradientMask.frame = visualEffectView.bounds
        edgeHighlight.frame = bounds
    }
}
