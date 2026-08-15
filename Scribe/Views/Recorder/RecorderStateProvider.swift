import Foundation

// Protocol for objects that provide live recorder state to the UI.
@MainActor
protocol RecorderStateProvider: AnyObject {
    var recordingState: RecordingState { get }
    var partialTranscript: String { get }
    /// Captured at the start of the active recording, after the applicable
    /// mode has been resolved for the frontmost app.
    var activeOutputMode: ModeOutputMode { get }
}
