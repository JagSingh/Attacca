//
//  AttaccaApp.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import SwiftUI

@main
struct AttaccaApp: App {
    @State private var access = FolderAccess()
    @State private var player = Player()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(access)
                .environment(player)
        }
    }
}
