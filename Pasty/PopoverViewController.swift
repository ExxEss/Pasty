//
//  ContentPopoverViewController.swift
//  Pasty
//
//  Created by EssExx on 2024/11/21.
//

import Cocoa

protocol PopoverDelegate: AnyObject {
    func textDidChange(_ notification: Notification)
}

class PopoverViewController: NSViewController {
    weak var delegate: PopoverDelegate?
    private var content: String
    
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
        text.textContainerInset = NSSize(width: 10, height: 15)
        
        // Set the content
        text.string = self.content
        
        return text
    }()
    
    init(content: String) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 900))
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(scrollView)
        scrollView.documentView = textView
        
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
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width - 20, height: CGFloat.greatestFiniteMagnitude )
    }
}

extension PopoverViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        delegate?.textDidChange(notification)
    }
}
