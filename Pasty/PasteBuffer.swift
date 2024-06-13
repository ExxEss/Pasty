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

class PasteBuffer {
    static let shared = PasteBuffer()
    
    private var pasteboard = NSPasteboard.general
    
    private var changeCount = NSPasteboard.general.changeCount
    
    private var pasteBuffer: [String] = []
    private var showBufferThreshold = 2
    
    private var pasteHistory: [String] = []
    
    private var isBufferAppendable = true
    
    var lastChangeDate: Date?
    
    private var eventTap: CFMachPort?
    
    private var sequentialPasteHotKey: HotKey?
    private var reverseSequentialPasteHotKey: HotKey?
    private var activateOrDeactivateBufferPanelHotKey: HotKey?
    private var popFirstHotKey: HotKey?
    private var popLastHotKey: HotKey?

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
        
        reverseSequentialPasteHotKey = HotKey(key: .d, modifiers: [.command, .shift])
        reverseSequentialPasteHotKey?.keyDownHandler = { [weak self] in
            self?.reversePaste()
        }
        
        activateOrDeactivateBufferPanelHotKey = HotKey(key: .b, modifiers: [.command])
        activateOrDeactivateBufferPanelHotKey?.keyDownHandler =  { [weak self] in
            self?.activateOrDeactivateBufferPanel()
        }
        
        popFirstHotKey = HotKey(key: .p, modifiers: [.control])
        popFirstHotKey?.keyDownHandler = { [weak self] in
            if self?.pasteBuffer.count ?? 0 > 0 {
                self?.deleteItem(at: 0)
            }
        }
        
        popLastHotKey = HotKey(key: .p, modifiers: [.control, .shift])
        popLastHotKey?.keyDownHandler =  { [weak self] in
            if self?.pasteBuffer.count ?? 0 > 0 {
                self?.deleteItem(at: ((self?.pasteBuffer.count)! - 1))
            }
        }
        
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: eventMask,
                                     callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            return PasteBuffer.hotKeyCallBack(proxy: proxy, type: type, event: event, refcon: refcon)
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
                if isBufferAppendable {
                    pasteBuffer.append(text)
                } else {
                    isBufferAppendable = true
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: text)

                if pasteBuffer.count >= showBufferThreshold {
                    BufferWindowController.shared.showPanel()
                }
            }
        }
    }

    func resetBuffer() {
        pasteBuffer = []
        isBufferAppendable = true
        
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: [])
    }
    
    @objc func resetBufferAndClosePanel() {
        let delay: Double = pasteBuffer.count > 0 ? 1 : 0.2
        resetBuffer()
        closePanel(delay: delay)
    }
    
    @objc func activateOrDeactivateBufferPanel() {
        if !BufferWindowController.shared.isPanelOpen || !BufferWindowController.shared.isActive {
            BufferWindowController.shared.showPanel(makeKey: true)
        } else if BufferWindowController.shared.isActive {
            NSApp.deactivate()
        }
    }
    
    @objc func autoResetBuffer() {
        if lastChangeDate != nil && Date().timeIntervalSince(lastChangeDate!) >= 120 {
            resetBufferWithClosedPanel()
        }
    }
    
    func resetBufferWithClosedPanel() {
        if !BufferWindowController.shared.isPanelOpen {
            resetBuffer()
        }
    }
    
    private func closePanel(delay: Double? = 1) {
        let delayInterval = delay ?? 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delayInterval) {
            BufferWindowController.shared.closePanel()
        }
    }

    func getHistory() -> [String] {
        return pasteBuffer
    }
    
    func copyItemFromBuffer(at index: Int) {
        isBufferAppendable = false
        copyToClipboard(pasteBuffer[index])
    }
    
    func joinItems(separator: String) {
        let unifiedString = pasteBuffer.joined(separator: separator)
        pasteBuffer = [unifiedString]
        
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    func moveItem(from oldIndex: Int, to newIndex: Int) {
        guard oldIndex != newIndex,
              oldIndex >= 0, oldIndex < pasteBuffer.count,
              newIndex >= 0, newIndex < pasteBuffer.count else {
            return
        }
        
        let item = pasteBuffer.remove(at: oldIndex)
        pasteBuffer.insert(item, at: newIndex)
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    func duplicateItem(_ item: String, at index: Int) {
        guard index >= 0 && index < pasteBuffer.count else {
            return // Index out of bounds check
        }
        
        pasteBuffer.insert(item, at: index + 1)
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    func deleteItem(at index: Int) {
        guard index >= 0 && index < pasteBuffer.count else {
            return // Index out of bounds check
        }
        
        pasteBuffer.remove(at: index)
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
        
        if pasteBuffer.count == 0 {
            closePanel()
        }
    }
    
    func restoreItem() {
        guard let item = pasteHistory.last else {
            return
        }
        
        pasteBuffer.insert(item, at: 0)
        pasteHistory.removeLast()
        
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }

    private func paste() {
        if let firstItem = pasteBuffer.first {
            pasteBuffer.removeFirst()
            pasteHistory.append(firstItem)
            isBufferAppendable = false
            copyToClipboard(firstItem)
            simulatePasteAction()
            
            if pasteBuffer.isEmpty {
                closePanel()
            }
        }
    }
    
    private func reversePaste() {
        if let lastItem = pasteBuffer.last {
            pasteBuffer.removeLast()
            pasteHistory.append(lastItem)
            isBufferAppendable = false
            copyToClipboard(lastItem)
            simulatePasteAction()
            
            if pasteBuffer.isEmpty {
                closePanel()
            }
        }
    }

    private func copyToClipboard1(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Create a new pasteboard item
        let pasteboardItem = NSPasteboardItem()
        
        // Set the main content as a string
        pasteboardItem.setString(text, forType: .string)
        
        // Add custom metadata
        let deviceName = Host.current().localizedName ?? "Unknown Device"
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown App"
        
        let metadata = "Device: \(deviceName)\nApp: \(appName)"
        
        // Use a custom type for the metadata
        let metadataType = NSPasteboard.PasteboardType("com.yourApp.metadata")
        pasteboardItem.setString(metadata, forType: metadataType)
        
        // Write the item to the pasteboard
        pasteboard.writeObjects([pasteboardItem])
        
        // readMetadataFromClipboard()
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    // Function to read metadata from the clipboard
    private func readMetadataFromClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        
        // Define the custom type for the metadata
        let metadataType = NSPasteboard.PasteboardType("com.yourApp.metadata")
        
        if let items = pasteboard.pasteboardItems {
            for item in items {
                if let metadata = item.string(forType: metadataType) {
                    print("Metadata", metadata)
                    return metadata
                }
            }
        }
        return nil
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
        let mySelf = Unmanaged<PasteBuffer>.fromOpaque(refcon).takeUnretainedValue()

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
//            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command] && nsEvent.keyCode == 0x08 {
//                let count = NSPasteboard.general.changeCount
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    if count == NSPasteboard.general.changeCount {
//                        mySelf.resetBufferAndClosePanel()
//                    }
//                }
//            }
            
            // Escape key
            if nsEvent.keyCode == 53 {
                let count = mySelf.pasteBuffer.count
                mySelf.resetBufferAndClosePanel()
                
                if count > 0 {
                    return nil
                }
            }
            
            // cmd + v
            if nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command] && nsEvent.keyCode == 9 {
                mySelf.resetBufferWithClosedPanel()
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
