//
//  SidebarSearchField.swift
//  Somewhere
//

import AppKit
import SwiftUI

/// A native macOS search field styled for the dark, translucent corner veil.
struct SidebarSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholder
        searchField.controlSize = .regular
        searchField.bezelStyle = .roundedBezel
        searchField.sendsSearchStringImmediately = true
        searchField.focusRingType = .default
        searchField.appearance = NSAppearance(named: .darkAqua)
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SidebarSearchField

        init(parent: SidebarSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            parent.text = searchField.stringValue
        }
    }
}
