import ViewInspector
@testable import MusicWall

// Test-only shim for ViewInspector Approach #2 (https://github.com/nalexn/ViewInspector/issues/404).
extension Inspection: @retroactive InspectionEmissary {}
extension Inspection: @retroactive @unchecked Sendable {}
