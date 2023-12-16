//
//  CustomHeaderCell.swift
//  Pasty
//
//  Created by EssExx on 15/12/23.
//

import Cocoa

class CustomHeaderCell: NSTableHeaderCell {
    override func draw(withFrame frame: NSRect, in controlView: NSView) {
        // Draw the header cell background if needed
        super.draw(withFrame: frame, in: controlView)

        // Set the title attributes, including the color
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.red,  // Set your desired color
            .paragraphStyle: paragraphStyle,
            .font: NSFont.systemFont(ofSize: 12)  // Set the desired font
        ]

        // Calculate the title's bounding rect
        let titleRect = self.titleRect(forBounds: frame)

        // Draw the title string
        let attributedTitle = NSAttributedString(string: self.stringValue, attributes: titleAttributes)
        attributedTitle.draw(in: titleRect)
    }
}
