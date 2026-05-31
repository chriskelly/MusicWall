import Foundation

enum UITestConfiguration {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestMockMusic")
    }
}
