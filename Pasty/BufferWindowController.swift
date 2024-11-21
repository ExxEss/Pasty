//
//  PanelController.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import AppKit
import Cocoa

class BufferWindowController: NSWindowController, NSWindowDelegate {
    static let shared = BufferWindowController()
    var isPanelOpen: Bool = false
    
    var isActive: Bool {
        return self.window?.isKeyWindow ?? false
    }
    
    private var trackingArea: NSTrackingArea?

    private init() {
        let panelWidth: CGFloat = 300
        let panelHeight: CGFloat = 200

        // Default values in case screen details are not screen
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
        
        let count = PasteBuffer.shared.getBuffer().count
        panel.title = "Items to paste: \(count)"
        panel.titlebarAppearsTransparent = true

        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        
        let contentViewController = BufferViewController()
        panel.contentViewController = contentViewController
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: window)
        registerForClipboardNotification()
        
        window?.delegate = self
        
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removeTrackingArea()
    }
    
    private func setupTrackingArea() {
        guard let contentView = window?.contentView else { return }
        
        removeTrackingArea()
        
        trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            contentView.addTrackingArea(trackingArea)
        }
    }
        
    private func removeTrackingArea() {
        guard let contentView = window?.contentView,
              let trackingArea = trackingArea else { return }
        
        contentView.removeTrackingArea(trackingArea)
        self.trackingArea = nil
    }
        
    override func mouseEntered(with event: NSEvent) {
        showPanel(makeKey: true)
    }
    
//    override func mouseExited(with event: NSEvent) {
//        NSApp.deactivate()
//    }
    
    func updatePanelTitle() {
        let count = PasteBuffer.shared.getBuffer().count
        if let panel = window as? BufferPanel {
            panel.title = "\(count) \(count > 1 ? "items" : "item") to paste"
        }
    }
    
    private func registerForClipboardNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(bufferDidChange(_:)), 
                                               name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    @objc private func bufferDidChange(_ notification: Notification) {
        updatePanelTitle()
    }

    func windowWillClose(_ notification: Notification) {
        // Call resetBuffer when the window is about to close
        isPanelOpen = false
        PasteBuffer.shared.resetBuffer()
    }

    func showPanel(makeKey: Bool = false) {
        if let window = self.window, let contentView = window.contentView {
            var frame = window.frame
            frame.size.height = contentView.frame.size.height // Use contentView's height
            let oldHeight = window.frame.height
            frame.origin.y += (oldHeight - frame.size.height)

            window.setFrame(frame, display: true)
            window.orderFront(nil)
            isPanelOpen = true

            if makeKey {
                window.makeKeyAndOrderFront(nil)
            }
        }
        updatePanelTitle()
    }
    
    func closePanel() {
        updatePanelTitle()
        self.window?.close()
    }
}

