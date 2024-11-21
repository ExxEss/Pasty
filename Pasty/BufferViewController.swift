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
    
    @objc func joinItems(separator: String) {
        PasteBuffer.shared.joinItems(separator: separator)
        bufferView.reloadData()
    }
}

extension BufferViewController: NSTableViewDataSource, NSTableViewDelegate, ShortcutTableCellViewDelegate {
    // Implement the data source and delegate methods to display the buffer item
    func numberOfRows(in tableView: NSTableView) -> Int {
        return buffer.count
    }
    
    func cellDidChange(_ cell: ShortcutTableCellView, newValue: String) {
        let row = bufferView.row(for: cell)
        if row >= 0 {
            // Update your data model with the new value
            PasteBuffer.shared.updateItem(at: row, with: newValue)
            buffer = PasteBuffer.shared.getBuffer()
            
            // Optionally reload the row to ensure proper display
            bufferView.reloadData(forRowIndexes: IndexSet(integer: row),
                                  columnIndexes: IndexSet(integer: 0))
        }
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
        
        cellView.delegate = self
        cellView.configure(with: buffer[row], row: row)
        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30 // Adjust the height to match menu item style
    }
}
