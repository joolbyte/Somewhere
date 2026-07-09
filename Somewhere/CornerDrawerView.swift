//
//  CornerDrawerView.swift
//  Somewhere
//

import SwiftUI
import UniformTypeIdentifiers

struct CornerDrawerView: View {
    @State private var isDropTargeted = false
    @State private var feedback = "Drop anything here to preview the interaction."

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(edgeGradient)

                LinearGradient(
                    colors: [.clear, .white.opacity(0.05), .white.opacity(0.18)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Somewhere")
                                .font(.headline.weight(.semibold))

                            Spacer()

                            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "tray.and.arrow.down")
                                .font(.body.weight(.medium))
                                .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .padding(.top, 42)

                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 9) {
                            Image(systemName: isDropTargeted ? "arrow.down" : "sparkles")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)

                            Text(isDropTargeted ? "Drop in Somewhere" : "Keep it Somewhere.")
                                .font(.title3.weight(.semibold))

                            Text(feedback)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Text("Text, links, images, and files")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 32)
                    }
                    .frame(width: min(260, proxy.size.width * 0.52), alignment: .leading)
                    .padding(.trailing, 28)
                }
            }
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.16), value: isDropTargeted)
            .onDrop(of: [.fileURL, .url, .plainText], isTargeted: $isDropTargeted, perform: acceptDrop(providers:))
        }
    }

    private var edgeGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(0.04), location: 0.22),
                .init(color: .black.opacity(0.56), location: 0.60),
                .init(color: .black, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func acceptDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        feedback = "Design preview — nothing was saved."
        return true
    }
}
