//
//  QuickAccessView.swift
//  Somewhere
//

import AppKit
import SwiftUI

struct QuickAccessView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var isPresentingCapture = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Somewhere")
                    .font(.headline)
                Spacer()
                Button {
                    isPresentingCapture = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            Text("A place for things before they have a place.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Somewhere") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "archive")
            }
        }
        .padding(16)
        .frame(width: 280)
        .sheet(isPresented: $isPresentingCapture) {
            QuickCaptureSheet()
        }
    }
}
