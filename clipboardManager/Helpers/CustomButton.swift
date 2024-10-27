//
//  CustomButton.swift
//  clipboardManager
//
//  Created by muratcankoc on 25/10/2024.
//

import Cocoa

class CustomButton: NSButton {
    private var isPressed = false

    // Color properties for the button
    var originalColor: NSColor = .gray {
        didSet {
            self.layer?.backgroundColor = originalColor.cgColor
        }
    }
    var hoverColor: NSColor = .lightGray
    var pressedColor: NSColor = .darkGray
    
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        
        // Change to pressed color
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.allowsImplicitAnimation = true
            self.layer?.backgroundColor = pressedColor.cgColor
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        // Reset the color immediately, ensuring no delay
        self.layer?.backgroundColor = isPressed ? hoverColor.cgColor : originalColor.cgColor

        // Check if the release happened within bounds
        let mouseLocation = convert(event.locationInWindow, from: nil)

        if isPressed && bounds.contains(mouseLocation) {
            // Trigger the action only if the release is within bounds
            super.mouseUp(with: event)
        }
        isPressed = false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Create a tracking area to monitor mouse entering and exiting the button
        let trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        // Change color to hoverColor on mouse enter
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.layer?.backgroundColor = hoverColor.lighter().cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        // Reset color to originalColor on mouse exit
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.layer?.backgroundColor = originalColor.cgColor
        }

        // Reset button if mouse exits while pressed
        if isPressed {
            self.layer?.backgroundColor = originalColor.cgColor
            isPressed = false
        }
    }
}

extension NSColor {
    // Function to get a darker version of the color with a customizable factor
    func darker(by factor: CGFloat = 0.3) -> NSColor {
        return NSColor(
            calibratedRed: max(self.redComponent * (1 - factor), 0),
            green: max(self.greenComponent * (1 - factor), 0),
            blue: max(self.blueComponent * (1 - factor), 0),
            alpha: self.alphaComponent
        )
    }
    func lighter(by factor: CGFloat = 0.3) -> NSColor {
        return NSColor(
            calibratedRed: min(self.redComponent + (1 - self.redComponent) * factor, 1),
            green: min(self.greenComponent + (1 - self.greenComponent) * factor, 1),
            blue: min(self.blueComponent + (1 - self.blueComponent) * factor, 1),
            alpha: self.alphaComponent
        )
    }
}
