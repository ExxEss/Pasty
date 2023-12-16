//
//  PanelController.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import AppKit
import Cocoa

class PanelController: NSWindowController {
    static let shared = PanelController()

    private init() {
        let panelWidth: CGFloat = 300  // Updated width
        let panelHeight: CGFloat = 200

        // Default values in case screen details are not c
        var x: CGFloat = 100
        var y: CGFloat = 100

        // If we can get the screen's main details, we calculate the position
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            x = screenRect.maxX - panelWidth
            // Position the panel 200 points from the top of the screen
            y = screenRect.maxY - panelHeight - 100
        }

        let panel = BufferPanel(
            contentRect: NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        let count = ClipboardManager.shared.getHistory().count
        panel.title = "Pasty buffer: \(count) items"
        panel.titlebarAppearsTransparent = true

        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        
        let contentViewController = BufferController()
        panel.contentViewController = contentViewController
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: window)
        registerForClipboardNotification()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updatePanelTitle(withItemCount count: Int) {
        if let panel = window as? BufferPanel {
            panel.title = "Pasty buffer: \(count) items"
        }
    }
    
    private func registerForClipboardNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(clipboardHistoryDidChange(_:)), name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    @objc private func clipboardHistoryDidChange(_ notification: Notification) {
        if let itemCount = notification.object as? Int {
            updatePanelTitle(withItemCount: itemCount)
        }
    }

    @objc func windowWillClose(notification: Notification) {
        // Call resetBuffer when the window is about to close
        ClipboardManager.shared.resetBuffer()
    }

    func showPanel() {
        if let window = self.window, let contentView = window.contentView {
            var frame = window.frame
            frame.size.height = contentView.frame.size.height // Use contentView's height
            // If you want to keep the window's top at the same position when resizing
            let oldHeight = window.frame.height
            frame.origin.y += (oldHeight - frame.size.height)

            window.setFrame(frame, display: true)
            window.orderFront(nil)
        }
    }
    
    func closePanel() {
        self.window?.close()  // or any other logic to hide/close the panel
    }
}

