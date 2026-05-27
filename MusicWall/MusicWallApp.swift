//
//  MusicWallApp.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI

@main
struct MusicWallApp: App {
    private let dependencies = AppDependencies.live

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }
}
