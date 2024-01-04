//
//  ClipboardManager.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import Cocoa
import CoreGraphics
import HotKey


let kVK_Command: CGKeyCode = 0x37
let kVK_ANSI_V: CGKeyCode = 0x09

class ClipboardManager {
    static let shared = ClipboardManager()
    
    private var pasteboard = NSPasteboard.general
    
    private var changeCount = NSPasteboard.general.changeCount
    
    private var clipboardHistory: [String] = []
    private var pasteHistory: [String] = []
    
    private var popped = false
    
    var lastChangeDate: Date?
    
    private var eventTap: CFMachPort?
    
    private var sequentialPasteHotKey: HotKey?
    private var showPanelHotKey: HotKey?

    private init() {}

    func startMonitoring() {
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkForChanges), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(autoResetBuffer), userInfo: nil, repeats: true)
        
        self.setupHotKey()
    }

    private func setupHotKey() {
        sequentialPasteHotKey = HotKey(key: .d, modifiers: [.command])
        sequentialPasteHotKey?.keyDownHandler = { [weak self] in
            self?.paste()
        }
        
        showPanelHotKey = HotKey(key: .b, modifiers: [.command, .shift])
        showPanelHotKey?.keyDownHandler = {
            PanelController.shared.showPanel(makeKey: true)
        }
        
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

    @objc func resetBufferAndClosePanel() {
        resetBuffer()
        closePanel()
    }
    
    @objc func autoResetBuffer() {
        if lastChangeDate != nil && Date().timeIntervalSince(lastChangeDate!) >= 120 &&
            !PanelController.shared.isPanelOpen {
            resetBuffer()
        }
    }
    
    func resetBuffer() {
        clipboardHistory = []
        popped = false
        
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: [])
    }
    
    private func closePanel() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            PanelController.shared.closePanel()
        }
    }

    func getHistory() -> [String] {
        return clipboardHistory
    }
    
    func concatenateItems() {
        let concatenatedString = clipboardHistory.joined(separator: " ")
        clipboardHistory = [concatenatedString]
        
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    func moveItem(from oldIndex: Int, to newIndex: Int) {
        guard oldIndex != newIndex,
              oldIndex >= 0, oldIndex < clipboardHistory.count,
              newIndex >= 0, newIndex < clipboardHistory.count else {
            return
        }
        
        let item = clipboardHistory.remove(at: oldIndex)
        clipboardHistory.insert(item, at: newIndex)
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    func duplicateItem(_ item: String, at index: Int) {
        guard index >= 0 && index < clipboardHistory.count else {
            return // Index out of bounds check
        }
        
        clipboardHistory.insert(item, at: index + 1)
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    func deleteItem(at index: Int) {
        guard index >= 0 && index < clipboardHistory.count else {
            return // Index out of bounds check
        }
        
        clipboardHistory.remove(at: index)
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
        
        if clipboardHistory.count == 0 {
            closePanel()
        }
    }
    
    func restoreItem() {
        guard let item = pasteHistory.last else {
            return
        }
        
        clipboardHistory.insert(item, at: 0)
        pasteHistory.removeLast()
        
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }

    private func paste() {
        if let firstItem = clipboardHistory.first {
            clipboardHistory.removeFirst()
            pasteHistory.append(firstItem)
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

    private static func hotKeyCallBack(proxy: CGEventTapProxy, type: CGEventType, 
                                       event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let mySelf = Unmanaged<ClipboardManager>.fromOpaque(refcon).takeUnretainedValue()

        if type == .keyDown, let nsEvent = NSEvent(cgEvent: event) {
            // cmd + shift + v
//            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift] && nsEvent.keyCode == 9 {
//                mySelf.paste()
//                // Return nil to stop propagation of this event
//                return nil
//            }
            
            // cmd + d
//            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command] && nsEvent.keyCode == 0x02 {
//                mySelf.paste()
//                // Return nil to stop propagation of this event
//                return nil
//            }
            
            // cmd + c
            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command] && nsEvent.keyCode == 0x08 {
                let count = NSPasteboard.general.changeCount
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if count == NSPasteboard.general.changeCount {
                        mySelf.resetBufferAndClosePanel()
                    }
                }
            }
            
            // cmd + v
            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command] && nsEvent.keyCode == 9 {
                mySelf.resetBufferAndClosePanel()
            }
            
            // cmd + option + v
//            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.shift, .option] && nsEvent.keyCode == 9 {
//                PanelController.shared.showPanel(makeKey: true)
//                return nil
//            }
        }

        // For all other events, pass them on
        return Unmanaged.passUnretained(event)
    }
}
