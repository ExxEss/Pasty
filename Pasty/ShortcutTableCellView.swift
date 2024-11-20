//
//  ShortcutTableCellView.swift
//  Pasty
//
//  Created by EssExx on 2024/11/19.
//

import Cocoa

protocol ShortcutTableCellViewDelegate: AnyObject {
    func cellDidEndEditing(_ cell: ShortcutTableCellView, newValue: String)
}

class ShortcutTableCellView: NSTableCellView {
    private var contentField: NSTextField?
    private var modifiersLabel: NSTextField?
    private var numberLabel: NSTextField?
    private var originalString: String = ""
    
    weak var delegate: ShortcutTableCellViewDelegate?
    
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
        contentField.isEditable = true
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
    }
    
    override func layout() {
        super.layout()
        
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
        originalString = content
        contentField?.stringValue = content
        
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

extension ShortcutTableCellView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField.stringValue != originalString else {
            return
        }
        
        delegate?.cellDidEndEditing(self, newValue: textField.stringValue)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            delegate?.cellDidEndEditing(self, newValue: contentField?.stringValue ?? "")
            return true
        }
        return false
    }
}
