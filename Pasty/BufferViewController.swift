//
//  ClipboardHistoryViewController.swift
//  TestPanel
//
//  Created by EssExx on 15/12/23.
//

import Cocoa

enum MoveDirection {
    case up, down
}

class BufferViewController: NSViewController {
    private var historyView: CustomTableView!
    private var clipboardHistory: [String] = []
    private var clipboardColumn: NSTableColumn?

    override func loadView() {
        // Load the clipboard history first to know how many items we have.
        clipboardHistory = PasteBuffer.shared.getHistory()
        
        // Calculate the height based on the number of items.
        let rowHeight: CGFloat = 30
        let totalRowsHeight = rowHeight * CGFloat(clipboardHistory.count)
        
        // Calculate the minimum height needed to display the table without overlapping the header.
        let paddingTop: CGFloat = 50
        let totalHeight = totalRowsHeight + paddingTop
        
        // Create the view with the new dynamic height, ensuring it starts below the header.
        let newView = NSView(frame: NSRect(x: 0, y: paddingTop, width: 290, height: totalHeight))

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
        historyView = CustomTableView()
        historyView.dataSource = self
        historyView.delegate = self

        // Create a scroll view and add the table view to it
        let scrollView = NSScrollView()
        scrollView.documentView = historyView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        // Add the scroll view to the view controller's view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Hide the vertical and horizontal scroll bars
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false

        // Scroll bars will appear during scrolling only
        scrollView.autohidesScrollers = true
        
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
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(historyView)
    }
        
    private func registerForClipboardNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(bufferDidChange(_:)), 
                                               name: NSNotification.Name("BufferChanged"), object: nil)
    }

    @objc private func bufferDidChange(_ notification: Notification) {
        reloadHistory()
    }

    private func reloadHistory() {
        clipboardHistory = PasteBuffer.shared.getHistory()
        historyView.reloadData()
        
        clipboardColumn?.title = "Items (\(clipboardHistory.count))"

        // Calculate the new height of the table view
        let rowHeight: CGFloat = 30
        let newHeight = rowHeight * CGFloat(clipboardHistory.count) + 20

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
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                    window.animator().setFrame(newWindowFrame, display: true, animate: true)
                }, completionHandler: {})
            }
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else {
            return
        }
        
        switch characters {
        case "d":
            duplicateSelectedItem()
        case "c":
            copySelectedItem()
        case "x":
            deleteSelectedItem()
        case "z":
            restoreItem()
        default:
            super.keyDown(with: event)
        }
    }
    
    @objc func joinItems(separator: String) {
        PasteBuffer.shared.joinItems(separator: separator)
        historyView.reloadData()
    }
    
    @objc func copySelectedItem() {
        let selectedRow = historyView.selectedRow
        guard selectedRow >= 0 else {
            return // No selection
        }
        
        PasteBuffer.shared.copyItemFromBuffer(at: selectedRow)
    }
    
    func moveSelectedItem(direction: MoveDirection) {
        let selectedRow = historyView.selectedRow
        guard selectedRow >= 0 else {
            return
        }

        var newPosition = direction == .up ? selectedRow - 1 : selectedRow + 1

        if newPosition >= clipboardHistory.count {
            // If the new position is beyond the last item, move to the start (index 0)
            newPosition = 0
        } else if newPosition < 0 {
            // If the new position is before the first item, move to the end (last index)
            newPosition = clipboardHistory.count - 1
        }

        PasteBuffer.shared.moveItem(from: selectedRow, to: newPosition)

        // Reload the table view and update selection
        historyView.reloadData()
        historyView.selectRowIndexes(IndexSet(integer: newPosition), byExtendingSelection: false)
    }

    @objc func duplicateSelectedItem() {
        let selectedRow = historyView.selectedRow
        guard selectedRow >= 0 else {
            return // No selection
        }

        let itemToDuplicate = PasteBuffer.shared.getHistory()[selectedRow]
        PasteBuffer.shared.duplicateItem(itemToDuplicate, at: selectedRow)

        // Reload the table view and select the new duplicated row
        historyView.reloadData()
        
        let newRowToSelect = selectedRow + 1 // The duplicated row will be after the original
        historyView.selectRowIndexes(IndexSet(integer: newRowToSelect), byExtendingSelection: false)
    }

    
    @objc func deleteSelectedItem() {
        let selectedRow = historyView.selectedRow
        guard selectedRow >= 0 else {
            return // No selection
        }
        
        PasteBuffer.shared.deleteItem(at: selectedRow)
        
        // Reload the table view
        historyView.reloadData()
        
        // Determine the new row to select
        let newRowCount = PasteBuffer.shared.getHistory().count
        if newRowCount > 0 {
            let newRowToSelect = selectedRow >= newRowCount ? newRowCount - 1 : selectedRow
            historyView.selectRowIndexes(IndexSet(integer: newRowToSelect), byExtendingSelection: false)
        } else {
            // No rows left to select
        }
    }
    
    @objc func restoreItem() {
        PasteBuffer.shared.restoreItem()
    }
}

extension BufferViewController: NSTableViewDataSource, NSTableViewDelegate {
    // Implement the data source and delegate methods to display the clipboard history
    func numberOfRows(in tableView: NSTableView) -> Int {
        return clipboardHistory.count
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
//        if let selectedRow = historyView.selectedRowIndexes.first {
//             let selectedItem = clipboardHistory[selectedRow]
//            // Perform an action with the selected item, like copying it to the clipboard
//        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "ClipboardCell")
        var cellView: NSTableCellView
        var textField: NSTextField
        
        if let existingCellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cellView = existingCellView
            textField = existingCellView.textField!
        } else {
            cellView = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 200, height: 25))
            cellView.identifier = cellIdentifier
            
            textField = NSTextField()
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
        
        // Adjust the text field's frame to remove horizontal padding and center vertically
        textField.frame = CGRect(x: 0,
                                 y: (cellView.bounds.height - textField.font!.pointSize) / 2 - 2, // Center vertically
                                 width: cellView.bounds.width,
                                 height: textField.font!.pointSize + 4) // Adjust height as needed
        
        textField.stringValue = formatString(from: clipboardHistory[row])
        
        // Additional styling to mimic a menu item
        textField.backgroundColor = .clear
        textField.enclosingScrollView?.drawsBackground = false
        textField.lineBreakMode = .byTruncatingMiddle
        
        return cellView
    }


    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30 // Adjust the height to match menu item style
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
