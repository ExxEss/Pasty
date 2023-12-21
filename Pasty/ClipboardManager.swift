//
//  ClipboardManager.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import Cocoa
import CoreGraphics

let kVK_Command: CGKeyCode = 0x37
let kVK_ANSI_V: CGKeyCode = 0x09

class ClipboardManager {
    static let shared = ClipboardManager()
    
    private var pasteboard = NSPasteboard.general
    
    private var changeCount = NSPasteboard.general.changeCount
    
    private var clipboardHistory: [String] = []
    
    private var popped = false
    
    var lastChangeDate: Date?
    
    private var eventTap: CFMachPort?

    private init() {}

    func startMonitoring() {
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkForChanges), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerResetBuffer), userInfo: nil, repeats: true)
        
        self.setupHotKey()
    }

    private func setupHotKey() {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: eventMask,
                                     callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            return ClipboardManager.hotKeyCallBack(proxy: proxy, type: type, event: event, refcon: refcon)
        },
                                     userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    @objc private func checkForChanges() {
        if pasteboard.changeCount != changeCount {
            changeCount = pasteboard.changeCount
            lastChangeDate = Date()
            
            if let text = pasteboard.string(forType: .string) {
                if !popped {
                    clipboardHistory.append(text)
                } else {
                    popped = false
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: text)

                if clipboardHistory.count > 2 {
                    PanelController.shared.showPanel()
                }
            }
        }
    }

    @objc func resetBuffer(autoMode: Bool) {
        if !autoMode || (lastChangeDate != nil && Date().timeIntervalSince(lastChangeDate!) <= 120) {
            clipboardHistory = []
            popped = false
        }
        
        if !autoMode && PanelController.shared.isPanelOpen {
            NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: [])
            
            closePanel()
        }
    }
    
    @objc private func timerResetBuffer() {
        resetBuffer(autoMode: true)
    }
    
    private func closePanel() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            PanelController.shared.closePanel()
        }
    }

    func getHistory() -> [String] {
        return clipboardHistory
    }

    private func paste() {
        if let firstItem = clipboardHistory.first {
            clipboardHistory.removeFirst()
            lastChangeDate = Date()
            popped = true
            copyToClipboard(firstItem)
            simulatePasteAction()
            
            if clipboardHistory.isEmpty {
                closePanel()
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags = []) {
        guard let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState),
              let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            return
        }

        event.flags = flags
        event.post(tap: CGEventTapLocation.cghidEventTap)
    }

    private func simulatePasteAction() {
        simulateKeyPress(keyCode: CGKeyCode(kVK_Command), keyDown: true)

        simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_V), keyDown: true, flags: .maskCommand)
        simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_V), keyDown: false, flags: .maskCommand)

        simulateKeyPress(keyCode: CGKeyCode(kVK_Command), keyDown: false)
    }

    private static func hotKeyCallBack(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let mySelf = Unmanaged<ClipboardManager>.fromOpaque(refcon).takeUnretainedValue()

        if type == .keyDown, let nsEvent = NSEvent(cgEvent: event) {
            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift] && nsEvent.keyCode == 9 {
                mySelf.paste()
                // Return nil to stop propagation of this event
                return nil
            }
            
            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command] && nsEvent.keyCode == 9 {
                mySelf.resetBuffer(autoMode: false)
            }
            
            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.shift, .option] && nsEvent.keyCode == 9 {
                mySelf.simulatePasteAction()
                return nil
            }
        }

        // For all other events, pass them on
        return Unmanaged.passUnretained(event)
    }
}
