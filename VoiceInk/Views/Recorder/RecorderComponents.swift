import AppKit
import SwiftUI

// MARK: - Recorder Glass Surface

/// Keeps the recorder chrome visually consistent across the compact pill,
/// transcript, and assistant states. On macOS Tahoe this is the native liquid
/// glass material; earlier systems receive the closest system-material fallback.
private struct RecorderGlassSurface<Shape: SwiftUI.Shape>: ViewModifier {
    let shape: Shape

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                // Keep the system glass material active without making this
                // floating, non-activating panel the key window.
                .environment(\.appearsActive, true)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.16), radius: 12, y: 4)
        }
    }
}

extension View {
    func recorderGlass<Shape: SwiftUI.Shape>(in shape: Shape) -> some View {
        modifier(RecorderGlassSurface(shape: shape))
    }
}

// MARK: - Reference Recorder Surface

/// The non-activating recorder surface used by the compact pill. Unlike liquid
/// glass, it stays visually stable while dictation keeps focus in another app.
private struct ReferenceRecorderSurface<Shape: SwiftUI.Shape>: ViewModifier {
    let shape: Shape

    func body(content: Content) -> some View {
        content
            .background {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(shape)
            }
            .background {
                shape.fill(Color.white.opacity(0.06))
            }
            .overlay {
                shape.stroke(Color.white.opacity(0.22), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }
}

extension View {
    func referenceRecorderSurface<Shape: SwiftUI.Shape>(in shape: Shape) -> some View {
        modifier(ReferenceRecorderSurface(shape: shape))
    }
}

// MARK: - Reference Recorder Pill

/// A fixed, graphite recorder capsule. Unlike liquid glass it deliberately
/// renders identically whether VoiceInk is the foreground app or not.
struct ReferenceRecorderPill: View {
    let recordingState: RecordingState
    let audioMeterProvider: () -> AudioMeter
    let recordingStartedAt: Date?
    let showsCloseButton: Bool
    let showsRecordingControls: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let onClose: () -> Void

    private var isRecording: Bool { recordingState == .recording }
    private var isStarting: Bool { recordingState == .starting }
    private var isProcessing: Bool {
        recordingState == .transcribing || recordingState == .enhancing || recordingState == .busy
    }

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.clear)
                .referenceRecorderSurface(in: Capsule(style: .continuous))

            if isRecording && showsRecordingControls {
                recordingContent
            } else if isRecording {
                // Keep the regular recording state as the clean, live meter.
                // The destructive/confirm controls appear only on hover.
                ReferencePillWaveform(audioMeterProvider: audioMeterProvider, activity: .recording)
            } else if showsCloseButton {
                // Ask Mode is ready for a follow-up: use the same reference
                // controls as recording, with X closing the chat and ✓
                // beginning the next spoken follow-up.
                HStack(spacing: 6) {
                    ReferencePillActionButton(icon: "xmark", action: onClose)
                    ReferencePillWaveform(audioMeterProvider: audioMeterProvider, activity: .idle)
                        .frame(maxWidth: .infinity)
                    ReferencePillActionButton(icon: "checkmark", action: onConfirm)
                }
                .padding(.horizontal, 6)
            } else {
                // Starting is a real recorder state, but it has not received
                // microphone samples yet. Showing the idle artwork for that
                // one frame is the static-waveform flash seen at invocation.
                if !isStarting {
                    ReferencePillWaveform(
                        audioMeterProvider: audioMeterProvider,
                        activity: isProcessing ? .processing : .idle
                    )
                }
            }
        }
        .frame(height: 72)
        .accessibilityElement(children: .contain)
    }

    private var recordingContent: some View {
        HStack(spacing: 6) {
            ReferencePillActionButton(icon: "xmark", action: onCancel)

            ZStack {
                ReferencePillWaveform(audioMeterProvider: audioMeterProvider, activity: .recording)
                    .opacity(0.36)
                RecordingElapsedTime(startedAt: recordingStartedAt)
            }
            .frame(maxWidth: .infinity)

            ReferencePillActionButton(icon: "checkmark", action: onConfirm)
        }
        .padding(.horizontal, 6)
    }

}

private struct ReferencePillActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 54, height: 54)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                        }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

private struct ReferencePillWaveform: View {
    enum Activity {
        case idle
        case recording
        case processing
    }

    let audioMeterProvider: () -> AudioMeter
    let activity: Activity
    private let idleHeights: [CGFloat] = [2, 3, 4, 5, 7, 11, 17, 23, 31, 38, 32, 25, 19, 14, 9, 6, 4, 3, 2]
    @State private var recordedLevels = Array(repeating: CGFloat(3), count: 19)
    @State private var hasReceivedLiveAudio = false

    private var isRecording: Bool { activity == .recording }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let audioMeter = audioMeterProvider()
            HStack(alignment: .center, spacing: 4.0) {
                ForEach(idleHeights.indices, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(isRecording ? 0.72 : 0.88))
                        .frame(width: 3.0, height: height(for: index, at: context.date))
                }
            }
            // The first draw happens before Core Audio has provided its first
            // level. Do not flash the placeholder flat line in that frame.
            .opacity(!isRecording || hasReceivedLiveAudio ? 1 : 0)
            .onChange(of: context.date) { _, _ in
                record(audioMeter)
            }
        }
        .frame(width: 148, height: 42)
        .onChange(of: isRecording) { _, recording in
            // A recorder window is reused between sessions. Do not carry the
            // prior session's last bars into the first frame of the next one.
            if recording {
                recordedLevels = Array(repeating: CGFloat(3), count: idleHeights.count)
                hasReceivedLiveAudio = false
            }
        }
        .accessibilityHidden(true)
    }

    private func record(_ meter: AudioMeter) {
        guard isRecording else { return }
        // Each bar is an actual recent microphone-power sample. There is no
        // synthetic sine-wave animation while the recorder is running.
        let power = max(0, min(1, meter.averagePower * 0.7 + meter.peakPower * 0.3))
        if power > 0.001 {
            hasReceivedLiveAudio = true
        }
        let level = max(3, min(38, 3 + CGFloat(power) * 35))
        recordedLevels.removeFirst()
        recordedLevels.append(level)
    }

    private func height(for index: Int, at date: Date) -> CGFloat {
        switch activity {
        case .idle:
            return idleHeights[index]
        case .recording:
            return recordedLevels[index]
        case .processing:
            // Processing is deliberately animated rather than representing
            // microphone power. Two slow, offset pulses travel through a
            // centered envelope to make progress feel alive but unhurried.
            let position = CGFloat(index) / CGFloat(idleHeights.count - 1)
            let envelope = pow(1 - abs(position - 0.5) * 2, 0.72)
            let time = date.timeIntervalSinceReferenceDate
            let travellingPulse = (sin(time * 4.2 - Double(index) * 0.72) + 1) * 0.5
            let secondaryPulse = (sin(time * 2.1 + Double(index) * 0.38) + 1) * 0.5
            let level = 4 + envelope * CGFloat(8 + travellingPulse * 20 + secondaryPulse * 5)
            return min(34, level)
        }
    }
}

private struct RecordingElapsedTime: View {
    let startedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Text(formattedElapsed(at: timeline.date))
                .font(.system(size: 27, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 2)
        }
    }

    private func formattedElapsed(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(startedAt ?? date)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Icon Toggle Button

struct RecorderToggleButton: View {
    let isEnabled: Bool
    let icon: String
    let disabled: Bool
    let action: () -> Void

    init(isEnabled: Bool, icon: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.icon = icon
        self.disabled = disabled
        self.action = action
    }

    private var isEmoji: Bool {
        !icon.contains(".") && !icon.contains("-") && icon.unicodeScalars.contains { !$0.isASCII }
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isEmoji {
                    Text(icon).font(.system(size: 14))
                } else {
                    Image(systemName: icon).font(.system(size: 13))
                }
            }
            .foregroundColor(disabled ? .white.opacity(0.3) : (isEnabled ? .white : .white.opacity(0.6)))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
    }
}

// MARK: - Record Button

struct RecorderRecordButton: View {
    let recordingState: RecordingState
    let action: () -> Void

    private var visualState: VisualState {
        switch recordingState {
        case .idle, .starting, .busy:
            return .ready
        case .recording:
            return .recording
        case .transcribing, .enhancing:
            return .processing
        }
    }

    private var isDisabled: Bool {
        switch recordingState {
        case .idle, .recording:
            return false
        case .starting, .transcribing, .enhancing, .busy:
            return true
        }
    }

    var body: some View {
        Button(action: action) {
            buttonFace
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(accessibilityLabel)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    @ViewBuilder
    private var buttonFace: some View {
        if #available(macOS 26.0, *) {
            if visualState == .recording {
                systemButtonIcon
                    .glassEffect(.regular.tint(Color.red.opacity(0.30)).interactive(), in: Circle())
            } else {
                systemButtonIcon
                    .glassEffect(.regular.interactive(), in: Circle())
            }
        } else {
            legacyButtonFace
        }
    }

    private var systemButtonIcon: some View {
        Image(systemName: systemIcon)
            .font(.system(size: 12, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.primary)
            .frame(width: 28, height: 28)
    }

    private var systemIcon: String {
        switch visualState {
        case .ready:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "ellipsis"
        }
    }

    private var legacyButtonFace: some View {
        ZStack {
            Circle()
                .fill(colors.surface)
                .overlay(
                    Circle()
                        .strokeBorder(colors.border, lineWidth: 0.6)
                )

            stateMark
        }
        .frame(width: 21, height: 21)
        .contentShape(Circle())
    }

    private var colors: StateColors {
        switch visualState {
        case .ready:
            return StateColors(
                surface: Color.white.opacity(0.18),
                border: Color.white.opacity(0.32),
                mark: Color.white.opacity(0.95)
            )
        case .recording:
            return StateColors(
                surface: Color.white.opacity(0.24),
                border: Color.white.opacity(0.42),
                mark: .white
            )
        case .processing:
            return StateColors(
                surface: Color.white.opacity(0.13),
                border: Color.white.opacity(0.18),
                mark: Color.white.opacity(0.86)
            )
        }
    }

    @ViewBuilder
    private var stateMark: some View {
        switch visualState {
        case .ready, .recording:
            RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                .fill(colors.mark)
                .frame(width: 8, height: 8)
        case .processing:
            ProcessingIndicator(color: colors.mark)
        }
    }

    private var accessibilityLabel: String {
        switch recordingState {
        case .idle:
            return String(localized: "Start recording")
        case .starting:
            return String(localized: "Starting recording")
        case .recording:
            return String(localized: "Stop recording")
        case .transcribing:
            return String(localized: "Transcribing recording")
        case .enhancing:
            return String(localized: "Enhancing recording")
        case .busy:
            return String(localized: "Recorder unavailable")
        }
    }

    private enum VisualState: Equatable {
        case ready
        case recording
        case processing
    }

    private struct StateColors {
        let surface: Color
        let border: Color
        let mark: Color
    }
}

// MARK: - Close Button

struct RecorderCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if #available(macOS 26.0, *) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 28, height: 28)
                        .glassEffect(.regular.tint(Color.red.opacity(0.30)).interactive(), in: Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.20))
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.red.opacity(0.36), lineWidth: 0.6)
                            )

                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    .frame(width: 21, height: 21)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Close")
    }
}

// MARK: - Processing Indicator

struct ProcessingIndicator: View {
    @State private var rotation: Double = 0
    let color: Color

    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(color, lineWidth: 1.5)
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Progress Dot Animation

struct ProgressAnimation: View {
    let color: Color
    let animationSpeed: Double

    private let dotCount = 5
    private let dotSize: CGFloat = 3
    private let dotSpacing: CGFloat = 2

    @State private var currentDot = 0
    @State private var timer: Timer?

    init(color: Color = .white, animationSpeed: Double = 0.3) {
        self.color = color
        self.animationSpeed = animationSpeed
    }

    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<dotCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: dotSize / 2)
                    .fill(color.opacity(index <= currentDot ? 0.85 : 0.25))
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .onAppear { startAnimation() }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startAnimation() {
        timer?.invalidate()
        currentDot = 0
        timer = Timer.scheduledTimer(withTimeInterval: animationSpeed, repeats: true) { _ in
            currentDot = (currentDot + 1) % (dotCount + 2)
            if currentDot > dotCount { currentDot = -1 }
        }
    }
}

// MARK: - Mode Button

struct RecorderModeButton: View {
    @ObservedObject private var modeManager = ModeManager.shared
    let buttonSize: CGFloat
    let padding: EdgeInsets

    init(buttonSize: CGFloat = 28, padding: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 7)) {
        self.buttonSize = buttonSize
        self.padding = padding
    }

    var body: some View {
        Menu {
            ForEach(modeManager.enabledConfigurations) { configuration in
                Button {
                    modeManager.setActiveConfiguration(configuration)
                } label: {
                    if configuration.icon.kind == .symbol {
                        Label(configuration.name, systemImage: configuration.icon.value)
                    } else {
                        Text("\(configuration.icon.value) \(configuration.name)")
                    }
                }
            }
        } label: {
            Group {
                let icon = modeManager.enabledConfigurations.isEmpty
                    ? "square.grid.2x2" : (modeManager.currentEffectiveConfiguration?.icon.value ?? "square.grid.2x2")
                let isEmoji = modeManager.currentEffectiveConfiguration?.icon.kind == .emoji

                if isEmoji {
                    Text(icon)
                        .font(.system(size: 14))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(modeManager.enabledConfigurations.isEmpty ? .secondary : .primary)
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(modeManager.enabledConfigurations.isEmpty)
        .padding(padding)
        .accessibilityLabel("Select Mode")
    }
}

// MARK: - Live Transcript View

struct LiveTranscriptView: View {
    let text: String
    var lineLimit: Int = 2

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "Listening…") }
        let maxCharacters = lineLimit > 2 ? 280 : 180
        return trimmed.count > maxCharacters ? "…" + trimmed.suffix(maxCharacters) : trimmed
    }

    private var isPlaceholder: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(isPlaceholder ? 0.45 : 0.95))
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Recorder Status Display

struct RecorderStatusDisplay: View {
    let currentState: RecordingState
    let audioMeterProvider: () -> AudioMeter
    let menuBarHeight: CGFloat?

    init(
        currentState: RecordingState,
        audioMeterProvider: @escaping () -> AudioMeter,
        menuBarHeight: CGFloat? = nil
    ) {
        self.currentState = currentState
        self.audioMeterProvider = audioMeterProvider
        self.menuBarHeight = menuBarHeight
    }

    var body: some View {
        Group {
            if currentState == .recording {
                AudioVisualizer(
                    audioMeterProvider: audioMeterProvider,
                    color: .white,
                    isActive: true
                )
                    .scaleEffect(y: menuBarHeight != nil ? min(1.0, (menuBarHeight! - 8) / 25) : 1.0, anchor: .center)
                    .transition(.opacity)
            } else {
                StaticVisualizer(color: .white)
                    .scaleEffect(y: menuBarHeight != nil ? min(1.0, (menuBarHeight! - 8) / 25) : 1.0, anchor: .center)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentState)
    }
}

// MARK: - Assistant Response Panel

struct AssistantPanelView: View {
    @ObservedObject var session: AssistantSession
    let liveFollowUpText: String
    let onSend: (String) -> Void
    let onOpenHistory: () -> Void

    @State private var draftMessage = ""
    @State private var composerFocusRequest = 0
    @FocusState private var isFollowUpFieldFocused: Bool

    private let horizontalPadding: CGFloat = 16
    private let followUpTextColor = Color.white.opacity(0.9)

    private var statusText: String? {
        switch session.phase {
        case .responding, .sendingFollowUp:
            return String(localized: "Thinking")
        case .failed(let message):
            return message
        case .inactive, .ready:
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            messageList
            followUpRow
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 12)
        .frame(minHeight: 220, maxHeight: .infinity)
        .onAppear(perform: requestComposerFocusIfAvailable)
        .onChange(of: session.phase) {
            requestComposerFocusIfAvailable()
        }
    }

    private var fullConversationText: String {
        session.messages.map { msg in
            let prefix = msg.role == .user ? "You" : "Assistant"
            return "\(prefix): \(msg.content)"
        }.joined(separator: "\n\n")
    }

    private var header: some View {
        HStack {
            Text("Chat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))

            Spacer()

            Button(action: onOpenHistory) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 24, height: 24)
                    .recorderGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .help("Open history")
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(session.messages) { message in
                        AssistantMessageBubble(message: message)
                            .id(message.id)
                    }

                    if let statusText {
                        Text(statusText)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.62))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("status")
                    }
                }
                .padding(.vertical, 2)
                .overlay(alignment: .topLeading) {
                    if !session.messages.isEmpty {
                        CopyIconButton(textToCopy: fullConversationText)
                            .scaleEffect(0.72)
                    }
                }
            }
            .onChange(of: session.messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: session.phase) {
                scrollToBottom(proxy)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var followUpRow: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if shouldShowLiveFollowUpText {
                    Text(liveFollowUpText)
                        .font(.system(size: 13))
                        .foregroundStyle(followUpTextColor)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .allowsHitTesting(false)
                }

                TextField(shouldShowLiveFollowUpText ? "" : "Ask a follow-up", text: $draftMessage)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(followUpTextColor)
                    .tint(followUpTextColor)
                    .disabled(!session.canSendFollowUp)
                    .focused($isFollowUpFieldFocused)
                    .onSubmit(sendDraftMessage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .recorderGlass(in: Capsule(style: .continuous))
            .background(AssistantComposerFocusBridge(request: composerFocusRequest))

            Button(action: sendDraftMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canSendDraft ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 32, height: 32)
                    .background(canSendDraft ? Color.accentColor : Color.white.opacity(0.10))
                    .clipShape(Circle())
                    .shadow(color: canSendDraft ? Color.accentColor.opacity(0.38) : .clear, radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!canSendDraft)
            .help("Send follow up")
        }
    }

    private var shouldShowLiveFollowUpText: Bool {
        draftMessage.isEmpty && !liveFollowUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSendDraft: Bool {
        session.canSendFollowUp && !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendDraftMessage() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard session.canSendFollowUp, !trimmed.isEmpty else { return }
        draftMessage = ""
        onSend(trimmed)
        requestComposerFocusIfAvailable()
    }

    private func requestComposerFocusIfAvailable() {
        guard session.canSendFollowUp else { return }
        composerFocusRequest &+= 1
        DispatchQueue.main.async {
            isFollowUpFieldFocused = true
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                if let last = session.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                } else {
                    proxy.scrollTo("status", anchor: .bottom)
                }
            }
        }
    }
}

/// SwiftUI focus state alone does not always restore AppKit's first responder
/// after a floating recorder panel becomes key. This bridge targets the actual
/// composer text field in that panel when a completed turn makes it available.
private struct AssistantComposerFocusBridge: NSViewRepresentable {
    let request: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard request != context.coordinator.lastRequest else { return }
        context.coordinator.lastRequest = request

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard let window = view.window,
                  let textField = firstTextField(in: view.superview),
                  textField.isEnabled
            else { return }
            window.makeFirstResponder(textField)
        }
    }

    final class Coordinator {
        var lastRequest = 0
    }

    private func firstTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let textField = view as? NSTextField { return textField }
        for child in view.subviews {
            if let textField = firstTextField(in: child) { return textField }
        }
        return nil
    }
}

private struct AssistantMessageBubble: View {
    let message: AssistantDisplayMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 36)
            }

            MarkdownContentView(
                message.content,
                fontSize: 13,
                foregroundColor: .white.opacity(isUser ? 0.96 : 0.88),
                alignment: .leading
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                if isUser {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.24, green: 0.24, blue: 0.24))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !isUser {
                    CopyIconButton(textToCopy: message.content)
                        .scaleEffect(0.72)
                        .padding(0)
                }
            }
            .help(isUser ? message.content : "")

            if !isUser {
                Spacer(minLength: 36)
            }
        }
    }
}
