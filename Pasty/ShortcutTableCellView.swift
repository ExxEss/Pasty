//
//  ShortcutTableCellView.swift
//  Pasty
//
//  Created by EssExx on 2024/11/19.
//

import Cocoa

protocol ContentPopoverDelegate: AnyObject {
    func popoverDidEndEditing(_ content: String)
}

class ContentPopoverViewController: NSViewController {
    weak var delegate: ContentPopoverDelegate?
    private var originalContent: String
    
    private lazy var scrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private lazy var textView: NSTextView = {
        // Create text storage, layout manager, and text container
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(size: NSSize(width: 500, height: 900))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        // Create text view with the configured components
        let text = NSTextView(frame: .zero, textContainer: textContainer)
        text.autoresizingMask = [.width, .height]
        text.isEditable = true
        text.isSelectable = true
        text.allowsUndo = true
        text.font = .menuFont(ofSize: 0)
        text.textColor = .white
        text.drawsBackground = false
        text.enabledTextCheckingTypes = 0
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.textContainerInset = NSSize(width: 10, height: 10)
        
        // Set the content
        text.string = self.originalContent
        
        return text
    }()
    
    init(content: String) {
        self.originalContent = content
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        // Create the main view with a fixed size
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 900))
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add scroll view
        containerView.addSubview(scrollView)
        
        // Set scroll view's document view
        scrollView.documentView = textView
        
        // Setup constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        self.view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.delegate = self
        
        // Ensure the text view fills the scroll view's content area
        let contentSize = scrollView.contentSize
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // Update text container width when view is laid out
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width - 20, height: CGFloat.greatestFiniteMagnitude)
    }
}

extension ContentPopoverViewController: NSTextViewDelegate {
    func textDidEndEditing(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        delegate?.popoverDidEndEditing(textView.string)
    }
}

protocol ShortcutTableCellViewDelegate: AnyObject {
    func cellDidEndEditing(_ cell: ShortcutTableCellView, newValue: String)
}

class ShortcutTableCellView: NSTableCellView, ContentPopoverDelegate {
    private var contentField: NSTextField?
    private var modifiersLabel: NSTextField?
    private var numberLabel: NSTextField?
    private var originalString: String = ""
    
    private var popover: NSPopover?
    private var trackingArea: NSTrackingArea?
    private var isEditing = false
    
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
        
    override func mouseEntered(with event: NSEvent) {
        if !isEditing {
            showPopover()
        }
    }
        
    override func mouseExited(with event: NSEvent) {
        if !isEditing {
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
    }
        
    private func showPopover() {
        guard popover == nil,
              let content = Optional(originalString),
              !content.isEmpty else {
            return
        }
        
        let contentViewController = ContentPopoverViewController(content: content)
        contentViewController.delegate = self
        
        let popover = NSPopover()
        popover.contentViewController = contentViewController
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
        if isEditing {
            // Prevent closing if we're editing
            if let popover = notification.object as? NSPopover {
                popover.performClose(nil)
            }
        }
    }
        
    private func hidePopover() {
        guard !isEditing else { return }
        NotificationCenter.default.removeObserver(self, name: NSPopover.willCloseNotification, object: popover)
        popover?.close()
        popover = nil
    }
        
    // ContentPopoverDelegate
    func popoverDidEndEditing(_ content: String) {
        delegate?.cellDidEndEditing(self, newValue: content)
        isEditing = false
        hidePopover()
    }
        
    // Handle when the text view begins editing
    func textViewDidBeginEditing(_ notification: Notification) {
        isEditing = true
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
        originalString = content
        contentField?.stringValue = formatString(from: content)
        
        // Only show shortcuts for the first 9 items
        if row < 9 {
            modifiersLabel?.stringValue = "⌃"
            numberLabel?.stringValue = "\(row + 1)"
        } else {
            modifiersLabel?.stringValue = ""
            numberLabel?.stringValue = ""
        }
        
        updateTrackingAreas()
    }
}

extension ShortcutTableCellView: NSTextFieldDelegate {
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
