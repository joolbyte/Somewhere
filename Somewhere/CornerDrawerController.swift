//
//  CornerDrawerController.swift
//  Somewhere
//

import AppKit
import SwiftUI

/// Controls the transient right-edge capture veil. AppKit owns the window
/// behavior while SwiftUI renders the material gradient and drop affordance.
@MainActor
final class CornerDrawerController: NSObject {
    private enum Layout {
        static let veilWidth: CGFloat = 560
        static let interactiveWidth: CGFloat = 292
        static let activationWidth: CGFloat = 26
        static let activationHeight: CGFloat = 30
        static let dismissalDelay: TimeInterval = 0.32
    }

    private let panel: NSPanel
    private var mouseMonitorTimer: Timer?
    private var pendingDismissal: DispatchWorkItem?
    private var hasStarted = false

    override init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: Layout.veilWidth, height: 1)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true

        let drawerView = CornerDrawerView()
        let hostingView = NSHostingView(rootView: drawerView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        mouseMonitorTimer = Timer.scheduledTimer(
            timeInterval: 0.08,
            target: self,
            selector: #selector(checkPointerLocation),
            userInfo: nil,
            repeats: true
        )
        mouseMonitorTimer?.tolerance = 0.02
    }

    @objc private func checkPointerLocation() {
        updateForCurrentPointerLocation()
    }

    private func updateForCurrentPointerLocation() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else { return }

        let activationRect = NSRect(
            x: screen.frame.maxX - Layout.activationWidth,
            y: screen.frame.maxY - Layout.activationHeight,
            width: Layout.activationWidth,
            height: Layout.activationHeight
        )
        let isPointerInActivationArea = activationRect.contains(location)
        let isPointerInDropZone = panel.isVisible && dropZone(in: panel.frame).contains(location)

        if isPointerInActivationArea || isPointerInDropZone {
            show(on: screen)
            panel.ignoresMouseEvents = false
        } else {
            panel.ignoresMouseEvents = true
            scheduleDismissal()
        }
    }

    private func show(on screen: NSScreen) {
        pendingDismissal?.cancel()
        pendingDismissal = nil
        position(on: screen)

        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
            return
        }

        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func position(on screen: NSScreen) {
        let screenFrame = screen.frame
        let origin = NSPoint(
            x: screenFrame.maxX - Layout.veilWidth,
            y: screenFrame.minY
        )
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: Layout.veilWidth, height: screenFrame.height)), display: true)
    }

    private func dropZone(in frame: NSRect) -> NSRect {
        NSRect(
            x: frame.maxX - Layout.interactiveWidth,
            y: frame.minY,
            width: Layout.interactiveWidth,
            height: frame.height
        )
    }

    private func scheduleDismissal() {
        guard panel.isVisible, pendingDismissal == nil else { return }

        let dismissal = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        pendingDismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.dismissalDelay, execute: dismissal)
    }

    private func hide() {
        pendingDismissal = nil
        guard panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            panel?.ignoresMouseEvents = true
            panel?.orderOut(nil)
        }
    }
}
