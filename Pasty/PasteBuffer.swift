//
//  ClipboardManager.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import Cocoa
import CoreGraphics
import AVFoundation
import HotKey


let kVK_Command: CGKeyCode = 0x37
let kVK_ANSI_V: CGKeyCode = 0x09

class PasteBuffer {
    private var audioPlayer: AVAudioPlayer?

    static let shared = PasteBuffer()
    
    private var pasteboard = NSPasteboard.general
    
    private var changeCount = NSPasteboard.general.changeCount
    
    private var pasteBuffer: [String] = []
    private var showBufferThreshold = 2
    
    private var pasteHistory: [String] = []
    
    private var isBufferAppendable = true
    
    private var lastUserEventDate: Date?
    var lastChangeDate: Date?
    
    private var eventTap: CFMachPort?
    
    private var sequentialPasteHotKey: HotKey?
    private var reverseSequentialPasteHotKey: HotKey?
    private var pasteNthHotKeys: [HotKey]?
    private var activateOrDeactivateBufferPanelHotKey: HotKey?
    private var popFirstHotKey: HotKey?
    private var popLastHotKey: HotKey?

    private init() {}

    func startMonitoring() {
        // Global monitor for events outside the app
        NSEvent.addGlobalMonitorForEvents(matching: [
            .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .mouseMoved, .scrollWheel
        ]) { event in
            self.lastUserEventDate = Date()
        }
        
        // Local monitor for events inside the app
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.lastUserEventDate = Date()
            return event // Pass the event along for normal handling
        }
        
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkForChanges), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(autoResetBuffer), userInfo: nil, repeats: true)
        
        self.setupHotKey()
    }

    private func setupHotKey() {
        sequentialPasteHotKey = HotKey(key: .e, modifiers: [.command])
        sequentialPasteHotKey?.keyDownHandler = { [weak self] in
            self?.paste()
        }
        
        reverseSequentialPasteHotKey = HotKey(key: .d, modifiers: [.command])
        reverseSequentialPasteHotKey?.keyDownHandler = { [weak self] in
            self?.reversePaste()
        }
        
        pasteNthHotKeys = []
        let keys: [Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
        for (index, key) in keys.enumerated() {
            let hotKey = HotKey(key: key, modifiers: [.control])
            hotKey.keyDownHandler = { [weak self] in
                self?.pasteNth(index)
            }
            pasteNthHotKeys?.append(hotKey)
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
            
            if !isLocalCopy(at: lastChangeDate!) {
                return
            }
            
            if let text = pasteboard.string(forType: .string) {
                if isBufferAppendable {
                    pasteBuffer.append(text)
                    playCopySound()
                } else {
                    isBufferAppendable = true
                    return
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: text)

                if pasteBuffer.count >= showBufferThreshold {
                    BufferWindowController.shared.showPanel()
                }
            }
        }
    }
    
    private func playCopySound() {
        if let soundURL = Bundle.main.url(forResource: "short-wind", withExtension: "wav") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.volume = 0.15
                audioPlayer?.play()
            } catch {
                print("Failed to initialize AVAudioPlayer: \(error.localizedDescription)")
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
        if let lastChangeDate = lastChangeDate, Date().timeIntervalSince(lastChangeDate) >= 60 {
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

    func getBuffer() -> [String] {
        return pasteBuffer
    }
    
    func joinItems(separator: String) {
        let unifiedString = pasteBuffer.joined(separator: separator)
        pasteBuffer = [unifiedString]
        
        NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
    }
    
    func updateItem(at index: Int, with newValue: String) {
        pasteBuffer[index] = newValue
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

    private func paste() {
        if let firstItem = pasteBuffer.first {
            pasteBuffer.removeFirst()
            pasteHistory.append(firstItem)
            isBufferAppendable = false
            copyToClipboard(firstItem)
            simulatePasteAction()
            
            NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
            
            if pasteBuffer.isEmpty {
                closePanel()
            }
        }
    }

    private func pasteNth(_ index: Int) {
        guard index >= 0 else { return }
        
        let calculatedIndex = index > pasteBuffer.count - 1
        ? pasteBuffer.count - 1
        : index
        
        let item = pasteBuffer[calculatedIndex]
        pasteHistory.append(item)
        isBufferAppendable = false
        copyToClipboard(item)
        simulatePasteAction()
    }
    
    private func reversePaste() {
        if let lastItem = pasteBuffer.last {
            pasteBuffer.removeLast()
            pasteHistory.append(lastItem)
            isBufferAppendable = false
            copyToClipboard(lastItem)
            simulatePasteAction()
            
            NotificationCenter.default.post(name: NSNotification.Name("BufferChanged"), object: nil)
            
            if pasteBuffer.isEmpty {
                closePanel()
            }
        }
    }

    private func isLocalCopy(at pasteboardChangeDate: Date) -> Bool {
        guard let lastEventDate = lastUserEventDate else {
            return false
        }
        
        let timeDifference = pasteboardChangeDate.timeIntervalSince(lastEventDate)
        print(timeDifference)
        let threshold: TimeInterval = 1.0
        
        return timeDifference < threshold
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
