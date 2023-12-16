//
//  ClipboardHistoryViewController.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import Cocoa

class BufferController: NSViewController {
    private var historyView: NSTableView!
    private var clipboardHistory: [String] = []
    private var clipboardColumn: NSTableColumn?

    override func loadView() {
        // Load the clipboard history first to know how many items we have.
        clipboardHistory = ClipboardManager.shared.getHistory()
        
        // Calculate the height based on the number of items.
        let rowHeight: CGFloat = 30  // Adjust if your row height is different
        let totalRowsHeight = rowHeight * CGFloat(clipboardHistory.count)
        
        // Calculate the minimum height needed to display the table without overlapping the header.
        let paddingTop: CGFloat = 40  // Adjust if your header height is different
        let totalHeight = totalRowsHeight + paddingTop
        
        // Create the view with the new dynamic height, ensuring it starts below the header.
        let newView = NSView(frame: NSRect(x: 0, y: paddingTop, width: 280, height: totalHeight))

        // Create and configure the visual effect view
        let visualEffectView = NSVisualEffectView(frame: newView.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .menu  // Choose the material as per your requirement
        visualEffectView.state = .active

        // Add the visual effect view as the first subview of newView
        newView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)

        self.view = newView
        
        // Your existing setup code.
        setupTableView()
        registerForClipboardNotification()
        
        // Reload the table view data.
        historyView.reloadData()
    }


    private func setupTableView() {
        historyView = NSTableView()
        historyView.dataSource = self
        historyView.delegate = self

        // Create a scroll view and add the table view to it
        let scrollView = NSScrollView()
        scrollView.documentView = historyView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        // Add the scroll view to the view controller's view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(scrollView)

        // Set up constraints for the scroll view
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])

        // Add a single column to the table view
        clipboardColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "ClipboardColumn"))
        clipboardColumn?.title = "Items (\(clipboardHistory.count))"
        if let column = clipboardColumn {
            historyView.addTableColumn(column)
        }

        // Remove the header view
        historyView.headerView = nil

        historyView.focusRingType = .none
        historyView.selectionHighlightStyle = .regular
        historyView.allowsEmptySelection = true
        historyView.allowsMultipleSelection = false
        historyView.enclosingScrollView?.drawsBackground = false
        historyView.backgroundColor = NSColor.clear
    }
        
    private func registerForClipboardNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(bufferDidChange(_:)), name: NSNotification.Name("BufferChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bufferReset(_:)), name: NSNotification.Name("BufferReset"), object: nil)
    }

    @objc private func bufferDidChange(_ notification: Notification) {
        reloadHistory()
    }
    
    @objc private func bufferReset(_ notification: Notification) {
        reloadHistory()
    }

    private func reloadHistory() {
        clipboardHistory = ClipboardManager.shared.getHistory()
        historyView.reloadData()
        
        clipboardColumn?.title = "Items (\(clipboardHistory.count))"

        // Calculate the new height of the table view
        let rowHeight: CGFloat = 30
        let newHeight = rowHeight * CGFloat(clipboardHistory.count) + 15

        // Determine the maximum height based on the screen size or a fixed maximum.
        let maxHeight = NSScreen.main?.visibleFrame.height ?? 600 // Example max height.
        
        // Calculate the new view height, not exceeding the maximum height.
        let adjustedHeight = min(newHeight, maxHeight)

        if let window = self.view.window {
            var newWindowFrame = window.frame
            let windowContentHeight = window.contentLayoutRect.height
            let heightDifference = adjustedHeight - windowContentHeight

            if heightDifference != 0 {
                // Calculate the new frame for the window
                newWindowFrame.size.height += heightDifference
                newWindowFrame.origin.y -= heightDifference

                // Animate the frame change
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3 // Set the duration of the animation
                    context.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                    window.animator().setFrame(newWindowFrame, display: true, animate: true)
                }, completionHandler: {
                    // Completion code if needed
                })
            }
        }
    }

}

extension BufferController: NSTableViewDataSource, NSTableViewDelegate {
    // Implement the data source and delegate methods to display the clipboard history
    func numberOfRows(in tableView: NSTableView) -> Int {
        return clipboardHistory.count
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let selectedRow = historyView.selectedRowIndexes.first {
             let selectedItem = clipboardHistory[selectedRow]
            // Perform an action with the selected item, like copying it to the clipboard
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "ClipboardCell")
        var cellView: NSTableCellView
        var textField: NSTextField
        
        // Reuse or create the cell view
        if let existingCellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cellView = existingCellView
            textField = existingCellView.textField!
        } else {
            cellView = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 200, height: 25))
            cellView.identifier = cellIdentifier
            
            textField = NSTextField(frame: NSInsetRect(cellView.bounds, 5, 5))
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            textField.autoresizingMask = [.width, .height]
            textField.font = .menuFont(ofSize: 0)
            textField.textColor = .labelColor
            cellView.addSubview(textField)
            cellView.textField = textField
        }
        
        textField.stringValue = clipboardHistory[row]
        
        // Additional styling to mimic a menu item
        textField.backgroundColor = .clear
        textField.enclosingScrollView?.drawsBackground = false
        textField.lineBreakMode = .byTruncatingTail
        
        cellView.enclosingScrollView?.drawsBackground = false
        
        return cellView
    }


    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30 // Adjust the height to match menu item style
    }
}
