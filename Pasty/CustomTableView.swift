//
//  CustomTableView.swift
//  Pasty
//
//  Created by EssExx on 01/01/24.
//

import Cocoa

class CustomTableView: NSTableView {
    override func keyDown(with event: NSEvent) {
        if let viewController = self.delegate as? BufferViewController {
            let shiftKeyPressed = event.modifierFlags.contains(.shift)

            switch event.keyCode {
            case 38: // J key code
                if shiftKeyPressed {
                    viewController.joinItems(separator: "\n")
                } else {
                    viewController.joinItems(separator: " ")
                }
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }
}

