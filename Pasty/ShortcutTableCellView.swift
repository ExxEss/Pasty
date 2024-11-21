//
//  ShortcutTableCellView.swift
//  Pasty
//
//  Created by EssExx on 2024/11/19.
//

import Cocoa

protocol ShortcutTableCellViewDelegate: AnyObject {
    func cellDidChange(_ cell: ShortcutTableCellView, newValue: String)
}

class ShortcutTableCellView: NSTableCellView {
    weak var delegate: ShortcutTableCellViewDelegate?
    
    private var contentField: NSTextField?
    private var modifiersLabel: NSTextField?
    private var numberLabel: NSTextField?
    private var content: String = ""
    
    private var hoverTimer: Timer?
    private var popover: NSPopover?
    
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Create and configure the content field
        let contentField = NSTextField()
        contentField.isBezeled = false
        contentField.drawsBackground = false
        contentField.isEditable = false
        contentField.isSelectable = true
        contentField.font = .menuFont(ofSize: 0)
        contentField.textColor = .labelColor
        contentField.focusRingType = .none
        contentField.lineBreakMode = .byTruncatingMiddle
        contentField.delegate = self
        self.contentField = contentField
        addSubview(contentField)
        
        // Create and configure the modifiers label
        let modifiersLabel = NSTextField()
        modifiersLabel.isBezeled = false
        modifiersLabel.drawsBackground = false
        modifiersLabel.isEditable = false
        modifiersLabel.isSelectable = false
        modifiersLabel.font = .menuFont(ofSize: 14)
        modifiersLabel.textColor = .placeholderTextColor
        modifiersLabel.alignment = .right
        self.modifiersLabel = modifiersLabel
        addSubview(modifiersLabel)
        
        // Create and configure the number label
        let numberLabel = NSTextField()
        numberLabel.isBezeled = false
        numberLabel.drawsBackground = false
        numberLabel.isEditable = false
        numberLabel.isSelectable = false
        numberLabel.font = .menuFont(ofSize: 14)
        numberLabel.textColor = .placeholderTextColor
        numberLabel.alignment = .center
        self.numberLabel = numberLabel
        addSubview(numberLabel)
        
        updateTrackingAreas()
        
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMoved(event)
        }
    }
    
    override func updateTrackingAreas() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation // Mouse location in screen coordinates
        
        // Get the cell view's frame in screen coordinates
        guard let window = self.window,
              let popover = popover else { return }
        
        let cellViewFrame = window.convertToScreen(self.convert(self.bounds, to: nil))
        let popoverFrame = popover.contentViewController?.view.window?.frame ?? .zero
        
        // Check if the mouse is outside both the cell view and the popover
        if !cellViewFrame.contains(mouseLocation) && !popoverFrame.contains(mouseLocation) {
            hidePopover()
        }
    }
        
    override func mouseEntered(with event: NSEvent) {
        hoverTimer?.invalidate() // Cancel any existing timer
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.showPopover()
        }
    }
        
    override func mouseExited(with event: NSEvent) {
        hoverTimer?.invalidate() // Cancel the timer
        hoverTimer = nil
        
        // Get the mouse location in screen coordinates
        let mouseLocation = NSEvent.mouseLocation
        
        // Check if mouse is within the popover window frame
        if let popoverWindow = popover?.contentViewController?.view.window {
            let popoverFrame = popoverWindow.frame
            if !NSPointInRect(mouseLocation, popoverFrame) {
                hidePopover()
            }
        } else {
            hidePopover()
        }
    }
        
    private func showPopover() {
        guard popover == nil,
              let content = Optional(content),
              !content.isEmpty else {
            return
        }
        
        let controller = PopoverViewController(content: content)
        controller.delegate = self
        
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .semitransient
        popover.animates = true
        
        // Set the popover size
        popover.contentSize = NSSize(width: 500, height: 900)
        
        // Show the popover
        popover.show(
            relativeTo: contentField?.bounds ?? bounds,
            of: contentField ?? self,
            preferredEdge: .maxY
        )
        
        self.popover = popover
        
        // Add notification observer for clicking outside
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePopoverShouldClose(_:)),
            name: NSPopover.willCloseNotification,
            object: popover
        )
    }
        
    @objc private func handlePopoverShouldClose(_ notification: Notification) {
        // Prevent closing if we're editing
        if let popover = notification.object as? NSPopover {
            popover.performClose(nil)
        }
        
    }
        
    private func hidePopover() {
        NotificationCenter.default.removeObserver(self, name: NSPopover.willCloseNotification, object: popover)
        popover?.close()
        popover = nil
    }
    
    func textDidChange(_ content: String) {
        delegate?.cellDidChange(self, newValue: content)
    }
        
    // Clean up
    override func removeFromSuperview() {
        super.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
        hidePopover()
    }

    override func layout() {
        super.layout()
        updateTrackingAreas()
        
        let modifiersWidth: CGFloat = 20  // Width for "⌃"
        let numberWidth: CGFloat = 18     // Width for the number
        let leftPadding: CGFloat = 0      // Padding from left edge
        let rightPadding: CGFloat = 0     // Padding from right edge
        let labelSpacing: CGFloat = 2    // Space between content and shortcuts
        let modifierNumberSpacing: CGFloat = 0 // Space between modifier and number
        
        // Calculate vertical center positions
        let contentFontHeight = contentField?.font?.pointSize ?? 13
        let shortcutFontHeight = modifiersLabel?.font?.pointSize ?? 12
        
        let contentY = (bounds.height - contentFontHeight) / 2 - 2
        let shortcutY = (bounds.height - shortcutFontHeight) / 2 - 2
        
        // Position the number label
        numberLabel?.frame = NSRect(
            x: bounds.width - numberWidth - rightPadding,
            y: shortcutY,
            width: numberWidth,
            height: shortcutFontHeight + 4
        )
        
        // Position the modifiers label
        modifiersLabel?.frame = NSRect(
            x: bounds.width - numberWidth - modifiersWidth - modifierNumberSpacing - rightPadding,
            y: shortcutY,
            width: modifiersWidth,
            height: shortcutFontHeight + 4
        )
        
        // Position the content field
        contentField?.frame = NSRect(
            x: leftPadding,
            y: contentY,
            width: bounds.width - modifiersWidth - numberWidth - labelSpacing - leftPadding - rightPadding - modifierNumberSpacing,
            height: contentFontHeight + 4
        )
    }
    
    func configure(with content: String, row: Int) {
        self.content = content
        contentField?.stringValue = formatString(from: content)
        
        // Only show shortcuts for the first 9 items
        if row < 9 {
            modifiersLabel?.stringValue = "⌃"
            numberLabel?.stringValue = "\(row + 1)"
        } else {
            modifiersLabel?.stringValue = ""
            numberLabel?.stringValue = ""
        }
    }
}

extension ShortcutTableCellView: NSTextFieldDelegate, PopoverDelegate {
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        content = textView.string
        
        // Update contentField without closing popover
        contentField?.stringValue = formatString(from: content)
        
        delegate?.cellDidChange(self, newValue: content)
    }
    
    private func formatString(from originalString: String) -> String {
        let trimmedString = originalString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Regular expression to match sequences of two or more newline characters
        let newlineRegex = try! NSRegularExpression(pattern: "\n{1,}", options: [])
        
        let range = NSRange(trimmedString.startIndex..<trimmedString.endIndex, in: trimmedString)
        
        // Replace each match with the same sequence followed by a space
        var formattedString = newlineRegex.stringByReplacingMatches(in: trimmedString, options: [], range: range, withTemplate: "$0 ")
        
        formattedString = formattedString.replacingOccurrences(of: "\n", with: " ↩︎")
        
        return formattedString
    }
}
