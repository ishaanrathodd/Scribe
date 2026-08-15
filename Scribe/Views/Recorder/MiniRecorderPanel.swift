import AppKit
import SwiftUI

class MiniRecorderPanel: NSPanel {
    private static let savedHeightKey = "MiniRecorderPanel.savedHeight"
    private static let defaultHeight: CGFloat = 430
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    private func configurePanel() {
        isFloatingPanel = true
        canHide = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = true
        isMovableByWindowBackground = true
        minSize = NSSize(width: 540, height: 260)
        maxSize = NSSize(width: 540, height: 720)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(persistHeight),
            name: NSWindow.didResizeNotification,
            object: self
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    static func calculateWindowMetrics() -> NSRect {
        let width: CGFloat = 540
        let height = savedHeight

        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: width, height: height)
        }

        // Host stays large enough for assistant output; SwiftUI controls the visible mini width.
        let padding: CGFloat = 24

        let visibleFrame = screen.visibleFrame
        let centerX = visibleFrame.midX
        let xPosition = centerX - (width / 2)
        let yPosition = visibleFrame.minY + padding

        return NSRect(
            x: xPosition,
            y: yPosition,
            width: width,
            height: height
        )
    }

    private static var savedHeight: CGFloat {
        let storedHeight = UserDefaults.standard.double(forKey: savedHeightKey)
        guard storedHeight > 0 else { return defaultHeight }
        return min(max(CGFloat(storedHeight), 260), 720)
    }

    @objc private func persistHeight() {
        UserDefaults.standard.set(frame.height, forKey: Self.savedHeightKey)
    }

    func show() {
        let metrics = MiniRecorderPanel.calculateWindowMetrics()
        setFrame(metrics, display: true)
        orderFrontRegardless()
    }

}
