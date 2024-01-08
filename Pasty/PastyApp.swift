//
//  TestPanelApp.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import SwiftUI
import AppKit

@main
struct PastyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!

    override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        PasteBuffer.shared.startMonitoring()
        
        // Create the status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set an emoji as the icon for the status bar item
        if let emojiImage = emojiToImage(emoji: "📋", size: CGSize(width: 16, height: 16)), // Adjust size as needed
           let button = statusBarItem.button {
            button.image = emojiImage
        }

        // Create the menu
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open buffer", action: #selector(openPanel), keyEquivalent: ""))
        
        // Quit menu item
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusBarItem.menu = menu

    }
    
    @objc func openPanel() {
        NSApp.activate(ignoringOtherApps: true)
        BufferWindowController.shared.showPanel()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    func emojiToImage(emoji: String, size: CGSize) -> NSImage? {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: size.height),
            NSAttributedString.Key.paragraphStyle: style
        ]

        let attributedString = NSAttributedString(string: emoji, attributes: attributes)
        let image = NSImage(size: size)
        image.lockFocus()

        attributedString.draw(in: CGRect(origin: .zero, size: size))
        
        image.unlockFocus()
        return image
    }
}


