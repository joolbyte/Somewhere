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
        static let interactiveWidth: CGFloat = 340
        static let activationWidth: CGFloat = 56
        static let activationHeight: CGFloat = 48
        static let trackingInterval: TimeInterval = 1.0 / 60.0
        static let dismissalDelay: TimeInterval = 0.10
        static let revealDuration: TimeInterval = 0.12
        static let dismissalDuration: TimeInterval = 0.10
        static let revealGraceDuration: TimeInterval = 0.18
    }

    private enum PresentationState {
        case hidden
        case revealing
        case visible
        case dismissing
    }

    private let panel: NSPanel
    private let session = CornerDrawerSession()
    private var mouseMonitorTimer: Timer?
    private var pendingDismissal: DispatchWorkItem?
    private var presentationState: PresentationState = .hidden
    private var activeTransitionID = UUID()
    private var revealGraceEndsAt = Date.distantPast
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

        let drawerView = CornerDrawerView(session: session)
        let hostingView = NSHostingView(rootView: drawerView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        let timer = Timer(
            timeInterval: Layout.trackingInterval,
            target: self,
            selector: #selector(checkPointerLocation),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 0.004
        RunLoop.main.add(timer, forMode: .common)
        mouseMonitorTimer = timer

        updateForCurrentPointerLocation()
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

        switch presentationState {
        case .hidden:
            panel.alphaValue = 0
            panel.orderFront(nil)
            revealGraceEndsAt = .now.addingTimeInterval(Layout.revealGraceDuration)
            reveal()
        case .dismissing:
            reveal()
        case .revealing, .visible:
            break
        }
    }

    private func reveal() {
        presentationState = .revealing
        let transitionID = UUID()
        activeTransitionID = transitionID

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.revealDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.activeTransitionID == transitionID else { return }
                self.presentationState = .visible
            }
        }
    }

    private func position(on screen: NSScreen) {
        let screenFrame = screen.frame
        let origin = NSPoint(
            x: screenFrame.maxX - Layout.veilWidth,
            y: screenFrame.minY
        )
        let targetFrame = NSRect(origin: origin, size: NSSize(width: Layout.veilWidth, height: screenFrame.height))
        guard panel.frame != targetFrame else { return }
        panel.setFrame(targetFrame, display: true)
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
        guard presentationState == .revealing || presentationState == .visible,
              pendingDismissal == nil else { return }

        let dismissal = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        pendingDismissal = dismissal
        let delay = max(Layout.dismissalDelay, revealGraceEndsAt.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: dismissal)
    }

    private func hide() {
        pendingDismissal = nil
        guard presentationState == .revealing || presentationState == .visible else { return }

        presentationState = .dismissing
        let transitionID = UUID()
        activeTransitionID = transitionID

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.dismissalDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.activeTransitionID == transitionID else { return }
                self.presentationState = .hidden
                self.panel.ignoresMouseEvents = true
                self.panel.orderOut(nil)
            }
        }
    }
}
