import Foundation

enum UITestLoadScenario: String, Sendable {
    case savedLibrary
    case restoreFromBackup
    case emptyCollection

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> UITestLoadScenario? {
        guard let index = arguments.firstIndex(of: "-UITestLoadScenario"),
              arguments.indices.contains(arguments.index(after: index))
        else { return nil }
        return UITestLoadScenario(rawValue: arguments[arguments.index(after: index)])
    }
}
