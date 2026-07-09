//
//  ContentView.swift
//  Somewhere
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StashItem.createdAt, order: .reverse) private var items: [StashItem]

    @State private var searchText = ""
    @State private var isPresentingCapture = false
    @State private var isShowingShuffle = false
    @State private var shuffledItems: [StashItem] = []

    private var displayedItems: [StashItem] {
        let source = isShowingShuffle ? shuffledItems : items
        guard !searchText.isEmpty else { return source }

        return source.filter { item in
            [item.title, item.note, item.textContent, item.sourceURL, item.originalFilename]
                .compactMap { $0 }
                .contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStashView(addItem: { isPresentingCapture = true })
                } else if displayedItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(displayedItems) { item in
                                StashItemCard(item: item)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            modelContext.delete(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Somewhere")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingCapture = true
                    } label: {
                        Label("Add to Somewhere", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        isShowingShuffle.toggle()
                        if isShowingShuffle {
                            shuffledItems = items.shuffled()
                        }
                    } label: {
                        Label(isShowingShuffle ? "Show Recent" : "Shuffle", systemImage: "shuffle")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search Somewhere")
        .frame(minWidth: 440, minHeight: 560)
        .sheet(isPresented: $isPresentingCapture) {
            QuickCaptureSheet()
        }
        .onChange(of: items.count) { _, _ in
            if isShowingShuffle {
                shuffledItems = items.shuffled()
            }
        }
    }
}

private struct EmptyStashView: View {
    let addItem: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("A place for things before they have a place.", systemImage: "tray.and.arrow.down")
        } description: {
            Text("Save an image, a link, a thought, or anything else you want to keep.")
        } actions: {
            Button("Add your first thing", action: addItem)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct StashItemCard: View {
    let item: StashItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.symbolName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                if let previewText = item.previewText, previewText != item.title {
                    Text(previewText)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(2)
                }

                Text("\(item.kind.displayName) · \(item.createdAt, format: .dateTime.month(.abbreviated).day().year())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var content = ""
    @State private var note = ""

    private var derivedTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmedContent.prefix(80))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add to Somewhere")
                .font(.title2.weight(.semibold))

            TextField("A short title (optional)", text: $title)

            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 150)
                .overlay(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("Paste or write something you want to keep…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }

            TextField("Why did you save it? (optional)", text: $note)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(derivedTitle.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func save() {
        let item = StashItem(
            kind: .text,
            title: derivedTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            textContent: content.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        modelContext.insert(item)
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    ContentView()
        .modelContainer(for: StashItem.self, inMemory: true)
}
