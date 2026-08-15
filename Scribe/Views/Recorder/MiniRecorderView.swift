import AppKit
import SwiftUI

struct MiniRecorderView<S: RecorderStateProvider & ObservableObject>: View {
    @ObservedObject var stateProvider: S
    @ObservedObject var recorder: Recorder
    @ObservedObject var assistantSession: AssistantSession
    let onRecordButtonTapped: () -> Void
    let onCancelTapped: () -> Void
    let onCloseTapped: () -> Void
    let onAssistantFollowUp: (String) -> Void
    let onOpenHistory: () -> Void
    @AppStorage(RecorderDisplaySettingsKeys.showLiveTranscript) private var showLiveTranscript = true

    // MARK: - Layout Constants

    private let controlBarHeight: CGFloat = 72
    private let compactWidth: CGFloat = 240
    private let transcriptWidth: CGFloat = 456
    private let assistantWidth: CGFloat = 520
    private let compactCornerRadius: CGFloat = 20
    private let expandedCornerRadius: CGFloat = 14
    @State private var recordingStartedAt: Date?
    @State private var isControlBarHovered = false

    // Show a stable transcript card as soon as live streaming begins. This
    // avoids a distracting size jump when the first partial result arrives.
    private var hasLiveTranscript: Bool {
        showLiveTranscript
            && !isAskMode
            && (
                stateProvider.recordingState == .recording
                    || (stateProvider.recordingState == .enhancing && !stateProvider.partialTranscript.isEmpty)
            )
    }

    private var hasAssistantResponse: Bool {
        assistantSession.isVisible
    }

    /// An Ask recording should use the compact Ask pill from the instant the
    /// shortcut is pressed, not only once its chat session becomes visible.
    /// This deliberately leaves the normal recorder at its existing size.
    private var isAskMode: Bool {
        assistantSession.isVisible || stateProvider.activeOutputMode == .respond
    }

    /// The recorder artwork is authored at 240×72 points, then rendered at
    /// the compact reference size for every Mini recorder state.
    private let pillScale: CGFloat = 0.5
    private var visiblePillWidth: CGFloat { compactWidth * pillScale }
    private var visiblePillHeight: CGFloat { controlBarHeight * pillScale }

    private var shouldShowCloseButton: Bool {
        hasAssistantResponse && stateProvider.recordingState == .idle && !assistantSession.isBusy
    }

    private var liveAssistantFollowUpText: String {
        guard showLiveTranscript, stateProvider.recordingState == .recording else { return "" }
        return stateProvider.partialTranscript
    }

    private var controlBar: some View {
        ReferenceRecorderPill(
            recordingState: stateProvider.recordingState,
            audioMeterProvider: recorder.audioMeterSnapshot,
            recordingStartedAt: recordingStartedAt,
            showsCloseButton: shouldShowCloseButton,
            showsRecordingControls: isControlBarHovered,
            onCancel: onCancelTapped,
            onConfirm: onRecordButtonTapped,
            onClose: onCloseTapped
        )
        .frame(width: compactWidth, height: controlBarHeight)
        // The Ask panel has its own larger card, so its control capsule uses
        // the reference size rather than the normal recorder's larger pill.
        .scaleEffect(pillScale)
        .frame(
            width: visiblePillWidth,
            height: visiblePillHeight
        )
        // This must be attached after scaling. The Ask capsule is visually
        // compact, so its hover target must be compact too.
        .contentShape(Capsule(style: .continuous))
        // Do not use SwiftUI's `onHover` here. On macOS 27 it can crash in
        // HoverEventDispatcher while this floating recorder is active. This
        // AppKit tracking area keeps the same hover-only controls without
        // becoming key or taking focus from the target application.
        .background {
            NativeHoverTrackingArea { isControlBarHovered = $0 }
        }
        // Reserve room for the downwards glass shadow in both normal and Ask
        // states; without this the compact normal pill clips at the window edge.
        .padding(.bottom, 10)
    }

    private var transcriptCard: some View {
        LiveTranscriptView(text: stateProvider.partialTranscript, lineLimit: 4)
            .frame(width: 420, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .referenceRecorderSurface(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var body: some View {
        VStack(spacing: hasLiveTranscript || hasAssistantResponse ? 12 : 0) {
            if hasAssistantResponse {
                AssistantPanelView(
                    session: assistantSession,
                    liveFollowUpText: liveAssistantFollowUpText,
                    onSend: onAssistantFollowUp,
                    onOpenHistory: onOpenHistory
                )
                .background {
                    RoundedRectangle(cornerRadius: expandedCornerRadius, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: expandedCornerRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                        }
                }
                .frame(maxHeight: .infinity)
                .layoutPriority(1)
            } else if hasLiveTranscript {
                transcriptCard
            }
            controlBar
        }
        .frame(width: hasAssistantResponse ? assistantWidth : (hasLiveTranscript ? transcriptWidth : visiblePillWidth))
        .animation(.easeInOut(duration: 0.3), value: hasLiveTranscript)
        .animation(.easeInOut(duration: 0.3), value: hasAssistantResponse)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear { updateRecordingStartTime(for: stateProvider.recordingState) }
        .onChange(of: stateProvider.recordingState) { _, newState in
            updateRecordingStartTime(for: newState)
        }
        .onDisappear { isControlBarHovered = false }
    }

    private func updateRecordingStartTime(for state: RecordingState) {
        if state == .recording {
            recordingStartedAt = recordingStartedAt ?? Date()
        } else {
            recordingStartedAt = nil
        }
    }
}

/// An AppKit-backed hover tracker for the recorder capsule. Keeping this out
/// of SwiftUI's hover responder avoids a macOS hover-dispatch crash seen in
/// non-activating floating panels, while leaving focus with the app receiving
/// dictation.
private struct NativeHoverTrackingArea: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context _: Context) -> NativeHoverTrackingView {
        let view = NativeHoverTrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: NativeHoverTrackingView, context _: Context) {
        view.onChange = onChange
    }
}

private final class NativeHoverTrackingView: NSView {
    var onChange: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isInside = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let newTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
    }

    override func mouseEntered(with _: NSEvent) {
        setInside(true)
    }

    override func mouseExited(with _: NSEvent) {
        setInside(false)
    }

    private func setInside(_ value: Bool) {
        guard isInside != value else { return }
        isInside = value
        onChange?(value)
    }
}
