import AppKit
import SwiftUI

final class BlockingFullscreenWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        // Keep the prompt/countdown on screen until an explicit button action.
    }

    override func performClose(_ sender: Any?) {
        // No close affordance while the fullscreen flow is active.
    }
}

enum FullscreenWindowFactory {
    static func make<Content: View>(
        screen: NSScreen,
        title: String,
        rootView: Content
    ) -> BlockingFullscreenWindow {
        let window = BlockingFullscreenWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.title = title
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.setFrame(screen.frame, display: true)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        return window
    }
}
