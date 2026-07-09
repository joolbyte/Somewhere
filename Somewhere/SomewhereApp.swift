//
//  SomewhereApp.swift
//  Somewhere
//
//  Created by Julian Grønås-Hamre on 10/07/2026.
//

import AppKit
import SwiftUI

@main
struct SomewhereApp: App {
    private let cornerDrawerController: CornerDrawerController

    init() {
        let controller = CornerDrawerController()
        cornerDrawerController = controller
        controller.start()
    }

    var body: some Scene {
        MenuBarExtra("Somewhere", systemImage: "square.and.arrow.down") {
            Button("Quit Somewhere") {
                NSApp.terminate(nil)
            }
        }
    }
}
