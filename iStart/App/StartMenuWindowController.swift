import AppKit
import Carbon.HIToolbox
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
        panel.onShouldHide = { [weak self] in
            self?.hide()
        }

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
        model.reloadApplicationsInBackground()
        let targetFrame = targetPanelFrame()
        panel.setFrame(startingFrame(for: targetFrame), display: true)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        animatePanelIn(to: targetFrame)
        model.focusSearch()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func targetPanelFrame() -> NSRect {
        let screen = screenContainingMouse() ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(StartMenuMetrics.width, visibleFrame.width - 32)
        let height = min(StartMenuMetrics.height, visibleFrame.height - 48)
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + 18

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func startingFrame(for targetFrame: NSRect) -> NSRect {
        targetFrame.offsetBy(dx: 0, dy: -StartMenuMetrics.appearAnimationOffset)
    }

    private func animatePanelIn(to targetFrame: NSRect) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(targetFrame, display: true)
            panel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = StartMenuMetrics.appearAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)

            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }
}

enum StartMenuMetrics {
    static let width: CGFloat = 720
    static let height: CGFloat = 760
    static let appearAnimationOffset: CGFloat = 34
    static let appearAnimationDuration: TimeInterval = 0.18
}

final class StartMenuPanel: NSPanel {
    var onShouldHide: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !isHandlingMarkedTextInput {
            switch Int(event.keyCode) {
            case kVK_Escape:
                onShouldHide?()
                return
            case kVK_DownArrow:
                NotificationCenter.default.post(name: .startMenuMoveSelectionDown, object: nil)
                return
            case kVK_UpArrow:
                NotificationCenter.default.post(name: .startMenuMoveSelectionUp, object: nil)
                return
            case kVK_Return, kVK_ANSI_KeypadEnter:
                NotificationCenter.default.post(name: .startMenuOpenSelection, object: nil)
                return
            default:
                break
            }
        }

        super.sendEvent(event)
    }

    private var isHandlingMarkedTextInput: Bool {
        guard let textInputClient = firstResponder as? NSTextInputClient else {
            return false
        }

        return textInputClient.hasMarkedText()
    }

    override func resignKey() {
        super.resignKey()

        if isVisible {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isVisible, !self.isKeyWindow else { return }
                self.onShouldHide?()
            }
        }
    }
}
