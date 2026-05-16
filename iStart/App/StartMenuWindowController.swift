import AppKit
import SwiftUI

final class StartMenuWindowController {
    private let model: StartMenuModel
    private let panel: StartMenuPanel
    private var hideObserver: NSObjectProtocol?

    init(model: StartMenuModel) {
        self.model = model

        let contentView = StartMenuView(model: model)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 18
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true

        panel = StartMenuPanel(
            contentRect: NSRect(x: 0, y: 0, width: StartMenuMetrics.width, height: StartMenuMetrics.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = false
        panel.title = "iStart"

        hideObserver = NotificationCenter.default.addObserver(
            forName: .startMenuShouldHide,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            showAndFocusSearch()
        }
    }

    func showAndFocusSearch() {
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        model.focusSearch()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        let screen = screenContainingMouse() ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(StartMenuMetrics.width, visibleFrame.width - 32)
        let height = min(StartMenuMetrics.height, visibleFrame.height - 48)
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + 18

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }
}

enum StartMenuMetrics {
    static let width: CGFloat = 720
    static let height: CGFloat = 760
}

final class StartMenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
