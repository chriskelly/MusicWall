//
//  MusicWallApp.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI

@main
struct MusicWallApp: App {
    private let dependencies = MusicWallApp.resolveDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }

    private static func resolveDependencies() -> AppDependencies {
        guard UITestConfiguration.isEnabled else {
            return .live
        }
        let scenario = UITestLoadScenario.fromLaunchArguments() ?? .savedLibrary
        return .uiTest(scenario: scenario)
    }
}
