//
//  DraggableFloatingPanel.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import Cocoa

class BufferPanel: NSPanel {
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override init(contentRect: NSRect, 
                  styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType,
                  defer flag: Bool) {
        
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel,
                               .fullSizeContentView,
                               .titled, .resizable, .closable,
                               .miniaturizable], backing: backingStoreType, defer: flag)
        
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        
        // Set up the visual effect view
//        let visualEffect = NSVisualEffectView(frame: self.contentRect(forFrameRect: self.frame))
//        visualEffect.blendingMode = .behindWindow
//        visualEffect.state = .active
//        visualEffect.material = .hudWindow
//        self.contentView = visualEffect
    }
    
}
