//
//  BufferViewController.swift
//
//  Created by EssExx on 15/12/23.
//

import Cocoa

enum MoveDirection {
    case up, down
}

class BufferViewController: NSViewController {
    private var bufferView: CustomTableView!
    private var buffer: [String] = []
    private var clipboardColumn: NSTableColumn?

    override func loadView() {
        buffer = PasteBuffer.shared.getBuffer()
        
        // Calculate the height based on the number of items.
        let rowHeight: CGFloat = 30
        let totalRowsHeight = rowHeight * CGFloat(buffer.count)
        
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
        bufferView.reloadData()
    }


    private func setupTableView() {
        bufferView = CustomTableView()
        bufferView.dataSource = self
        bufferView.delegate = self

        // Create a scroll view and add the table view to it
        let scrollView = NSScrollView()
        scrollView.documentView = bufferView
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
        clipboardColumn?.title = "Items (\(buffer.count))"
        if let column = clipboardColumn {
            bufferView.addTableColumn(column)
        }

        // Remove the header view
        bufferView.headerView = nil

        bufferView.focusRingType = .none
        bufferView.selectionHighlightStyle = .regular
        bufferView.allowsEmptySelection = true
        bufferView.allowsMultipleSelection = false
        bufferView.enclosingScrollView?.drawsBackground = false
        bufferView.backgroundColor = NSColor.clear
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(bufferView)
    }
        
    private func registerForClipboardNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(bufferDidChange(_:)), 
                                               name: NSNotification.Name("BufferChanged"), object: nil)
    }

    @objc private func bufferDidChange(_ notification: Notification) {
        reloadView()
    }

    private func reloadView() {
        buffer = PasteBuffer.shared.getBuffer()
        bufferView.reloadData()
        
        clipboardColumn?.title = "Items (\(buffer.count))"

        // Calculate the new height of the table view
        let rowHeight: CGFloat = 30
        let newHeight = rowHeight * CGFloat(buffer.count) + 20

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
        bufferView.reloadData()
    }
    
    @objc func copySelectedItem() {
        let selectedRow = bufferView.selectedRow
        guard selectedRow >= 0 else {
            return // No selection
        }
        
        PasteBuffer.shared.copyItemFromBuffer(at: selectedRow)
    }
    
    func moveSelectedItem(direction: MoveDirection) {
        let selectedRowPosition = bufferView.selectedRow
        guard selectedRowPosition >= 0 else {
            return
        }

        var newPosition = direction == .up ? selectedRowPosition - 1 : selectedRowPosition + 1

        if newPosition >= buffer.count {
            // If the new position is beyond the last item, move to the start (index 0)
            newPosition = 0
        } else if newPosition < 0 {
            // If the new position is before the first item, move to the end (last index)
            newPosition = buffer.count - 1
        }

        PasteBuffer.shared.moveItem(from: selectedRowPosition, to: newPosition)

        // Reload the table view and update selection
        bufferView.reloadData()
        bufferView.selectRowIndexes(IndexSet(integer: newPosition), byExtendingSelection: false)
    }

    @objc func duplicateSelectedItem() {
        let selectedRow = bufferView.selectedRow
        guard selectedRow >= 0 else {
            return // No selection
        }

        let itemToDuplicate = PasteBuffer.shared.getBuffer()[selectedRow]
        PasteBuffer.shared.duplicateItem(itemToDuplicate, at: selectedRow)

        // Reload the table view and select the new duplicated row
        bufferView.reloadData()
        
        let newRowToSelect = selectedRow + 1 // The duplicated row will be after the original
        bufferView.selectRowIndexes(IndexSet(integer: newRowToSelect), byExtendingSelection: false)
    }

    
    @objc func deleteSelectedItem() {
        let selectedRow = bufferView.selectedRow
        guard selectedRow >= 0 else {
            return // No selection
        }
        
        PasteBuffer.shared.deleteItem(at: selectedRow)
        
        // Reload the table view
        bufferView.reloadData()
        
        // Determine the new row to select
        let newRowCount = PasteBuffer.shared.getBuffer().count
        if newRowCount > 0 {
            let newRowToSelect = selectedRow >= newRowCount ? newRowCount - 1 : selectedRow
            bufferView.selectRowIndexes(IndexSet(integer: newRowToSelect), byExtendingSelection: false)
        } else {
            // No rows left to select
        }
    }
    
    @objc func restoreItem() {
        PasteBuffer.shared.restoreItem()
    }
}

extension BufferViewController: NSTableViewDataSource, NSTableViewDelegate {
    // Implement the data source and delegate methods to display the buffer item
    func numberOfRows(in tableView: NSTableView) -> Int {
        return buffer.count
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {}
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "ShortcutCell")
        
        var cellView: ShortcutTableCellView
        
        if let existingCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? ShortcutTableCellView {
            cellView = existingCell
        } else {
            cellView = ShortcutTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 200, height: 30))
            cellView.identifier = cellIdentifier
        }
        
        cellView.configure(with: formatString(from: buffer[row]), row: row)
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
