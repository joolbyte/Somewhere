//
//  CornerDrawerView.swift
//  Somewhere
//

import SwiftUI
import UniformTypeIdentifiers

struct CornerDrawerView: View {
    @State private var isDropTargeted = false
    @State private var searchText = ""

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

                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL, .url, .plainText], isTargeted: $isDropTargeted, perform: acceptDrop(providers:))
        }
        .preferredColorScheme(.dark)
    }

    private func acceptDrop(providers: [NSItemProvider]) -> Bool {
        !providers.isEmpty
    }
}
