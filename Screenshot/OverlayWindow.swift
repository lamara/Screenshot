//
//  OverlayWindow.swift
//  Screenshot
//
//  Created by Alexander5175 Lamar on 7/27/16.
//  Copyright © 2016 Alexander5175 Lamar. All rights reserved.
//

import Foundation
import CoreGraphics

class OverlayWindow: NSWindow {
    var onCancel: (() -> Void)? = nil
    
    override init(contentRect: NSRect, styleMask aStyle: Int, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: NSBorderlessWindowMask, backing: bufferingType, defer: flag)
        self.releasedWhenClosed = false
        self.opaque = false
        self.hasShadow = false
        self.level = Int(CGWindowLevelForKey(.FloatingWindowLevelKey))
        self.backgroundColor = NSColor.clearColor().colorWithAlphaComponent(0.0)
        //self.becomesKeyOnlyIfNeeded = true
        self.ignoresMouseEvents = false
        self.contentView = OverlayContentView.init(frame: self.frame)
        self.contentView?.wantsLayer = true
    }
    
    func gifRecordModeOn(captureRect: NSRect) {
        self.ignoresMouseEvents = true;
        let overlayView = self.contentView! as! OverlayContentView
        overlayView.cursor = NSCursor.arrowCursor()
        overlayView.cursorUpdate(NSEvent())
        
        // Dim area outside of the capture area.
        let top = captureRect.origin.y + captureRect.height
        let bottom = captureRect.origin.y
        let left = captureRect.origin.x
        let right = captureRect.origin.x + captureRect.width
        
        let topView = NSView.init(frame: NSRect.init(x: 0, y: top, width: self.frame.width, height: self.frame.height - top))
        let bottomView = NSView.init(frame: NSRect.init(x: 0, y: 0, width: self.frame.width, height: bottom))
        let leftView = NSView.init(frame: NSRect.init(x: 0, y: bottom, width: left, height: top - bottom))
        let rightView = NSView.init(frame: NSRect.init(x: right, y: bottom, width: self.frame.width - right, height: top - bottom))
        
        let alpha: CGFloat = 0.35
        
        topView.layer = CALayer()
        topView.layer!.backgroundColor = NSColor.clearColor().colorWithAlphaComponent(alpha).CGColor
        bottomView.layer = CALayer()
        bottomView.layer!.backgroundColor = NSColor.clearColor().colorWithAlphaComponent(alpha).CGColor
        leftView.layer = CALayer()
        leftView.layer!.backgroundColor = NSColor.clearColor().colorWithAlphaComponent(alpha).CGColor
        rightView.layer = CALayer()
        rightView.layer!.backgroundColor = NSColor.clearColor().colorWithAlphaComponent(alpha).CGColor
        
        self.contentView!.addSubview(topView)
        self.contentView!.addSubview(bottomView)
        self.contentView!.addSubview(leftView)
        self.contentView!.addSubview(rightView)
    }
    
    func gifRecordModeOff() {
        self.ignoresMouseEvents = false;
        let overlayView = self.contentView! as! OverlayContentView
        overlayView.cursor = NSCursor.crosshairCursor()
        overlayView.cursorUpdate(NSEvent())
        
        self.contentView!.subviews.forEach { (view) in
            view.removeFromSuperview()
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func cancelOperation(sender: AnyObject?) {
        Swift.print("Cancel")
        if onCancel != nil {
            onCancel!()
        }
    }
    
    override var canBecomeKeyWindow: Bool {
        return true
    }
    override var canBecomeMainWindow: Bool {
        return true
    }
}

class OverlayContentView: NSView {
    
    var cursor = NSCursor.crosshairCursor()
    
    override func cursorUpdate(event: NSEvent) {
        // There's a bug where the crosshair cursor won't show up, or will only show up for a few
        // frames, if the ibeam cursor was the previous cursor active (i.e. if a text input field
        // was previously in focus)
        Swift.print("cursor setting", cursor.isEqual(NSCursor.crosshairCursor()))
        cursor.set()
    }
    
    var trackingArea: NSTrackingArea!
    override func updateTrackingAreas() {
        if trackingArea != nil {
            self.removeTrackingArea(trackingArea)
            trackingArea = nil
        }
        // Add crosshair cursor tracking area
        let opts = NSTrackingAreaOptions.MouseMoved.rawValue | NSTrackingAreaOptions.MouseEnteredAndExited.rawValue | NSTrackingAreaOptions.ActiveAlways.rawValue | NSTrackingAreaOptions.CursorUpdate.rawValue
        trackingArea = NSTrackingArea.init(rect: self.bounds, options: NSTrackingAreaOptions.init(rawValue: opts), owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    deinit {
        Swift.print("======================")
        Swift.print("OVERLAY DEALLOC CALLED")
        NSCursor.arrowCursor().set()
    }
}