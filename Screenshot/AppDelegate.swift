//
//  AppDelegate.swift
//  Screenshot
//
//  Created by Alexander5175 Lamar on 7/21/16.
//  Copyright © 2016 Alexander5175 Lamar. All rights reserved.
//

import Cocoa
import CoreGraphics
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBar = NSStatusBar.systemStatusBar()
    var statusBarItem = NSStatusItem()

    var recorder: MovieRecorder?
    var screenshotCaptureMode: Bool = false
    var gifCaptureMode: Bool = false
    // True if the gif recorder is recording
    var capturingGif: Bool = false

    weak var rectangleView: NSView?
    var overlayWindow: OverlayWindow?
    
    @IBOutlet weak var menu: NSMenu!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Terminate application if it is already running somewhere else
        if NSRunningApplication.runningApplicationsWithBundleIdentifier(NSBundle.mainBundle().bundleIdentifier!).count > 1 {
            NSApp.terminate(nil)
        }
        
        // Create local temp file directory
        do {
            let paths = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)
            var path = paths[0] as NSString
            path = path.stringByAppendingPathComponent("Screenshot")
            
            try NSFileManager.defaultManager().createDirectoryAtPath(path as String, withIntermediateDirectories: true, attributes: nil)
        } catch {
            let nsError = error as NSError
            print(nsError.localizedDescription)
        }

        // Create global shortcuts
        let gifKeyMask = NSEventModifierFlags.CommandKeyMask.rawValue | NSEventModifierFlags.ShiftKeyMask.rawValue
        let gifShortcut = MASShortcut(keyCode: UInt(kVK_ANSI_5), modifierFlags: gifKeyMask)
        MASShortcutMonitor.sharedMonitor().registerShortcut(gifShortcut) {
            print("Gif shortcut hit")
            self.gifCaptureMode = true
            self.beginScreenshotMode(nil)
        }
        let screenshotKeyMask = NSEventModifierFlags.CommandKeyMask.rawValue
        let screenshotShortcut = MASShortcut(keyCode: UInt(kVK_ANSI_5), modifierFlags: screenshotKeyMask)
        MASShortcutMonitor.sharedMonitor().registerShortcut(screenshotShortcut) {
            print("Screenshot shortcut hit")
            self.screenshotCaptureMode = true
            self.beginScreenshotMode(nil)
        }

        // Create mouse handlers
        NSEvent.addLocalMonitorForEventsMatchingMask(NSEventMask.LeftMouseDownMask, handler: mouseDown)
        NSEvent.addLocalMonitorForEventsMatchingMask(NSEventMask.LeftMouseDraggedMask, handler: mouseDragged)
        NSEvent.addLocalMonitorForEventsMatchingMask(NSEventMask.LeftMouseUpMask, handler: mouseUp)
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        MASShortcutMonitor.sharedMonitor().unregisterAllShortcuts()
    }
    
    @IBAction func exit(sender: AnyObject) {
        NSApp.terminate(nil)
    }
    
    override func awakeFromNib() {
        self.statusBarItem = statusBar.statusItemWithLength(-1)
        self.statusBarItem.title = "S"
        self.statusBarItem.menu = menu
    }

    @IBAction func beginScreenshotMode(sender: AnyObject?) {
        print("screenshot")
        if overlayWindow != nil {
            return
        }
        // Add a transparent overlay window over the entire screen
        let screenSize = NSScreen.mainScreen()!.frame.size;
        overlayWindow = OverlayWindow.init(contentRect: CGRect.init(origin: CGPoint.zero, size: screenSize/*CGSize.init(width: screenSize.width / 2, height: screenSize.height / 2)*/), styleMask: NSTitledWindowMask, backing: NSBackingStoreType.Buffered, defer: false)
        overlayWindow!.makeKeyAndOrderFront(nil)
        
        if (self.gifCaptureMode) {
            // Begin initializing the gif recorder
            self.recorder = MovieRecorder()
        }
        
        // Add a global escape shortcut so the overlay can always be cancelled.
        let escapeShortcut = MASShortcut(keyCode: UInt(kVK_Escape), modifierFlags: 0)
        MASShortcutMonitor.sharedMonitor().registerShortcut(escapeShortcut) {
            print("Escape hit")
            self.handleEscapeFromWindow()
        }
        
        // Give the current app focus
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }
    
    func endScreenshotMode() {
        print("End screenshot mode called")
        let escapeShortcut = MASShortcut(keyCode: UInt(kVK_Escape), modifierFlags: 0)
        MASShortcutMonitor.sharedMonitor().unregisterShortcut(escapeShortcut)
        if overlayWindow != nil {
            overlayWindow!.close()
            overlayWindow = nil
        }
    }
    
    func handleEscapeFromWindow() {
        if capturingGif != false {
            stopCapturingGif()
        }
        endScreenshotMode()
    }
    
    func captureImage(rect: CGRect) {
        let display = CGMainDisplayID()
        let image = CGDisplayCreateImageForRect(display, rect)
        let nsimage = NSImage.init(CGImage: image!, size: NSSize.zero)
        // Save to file
        let data: NSData! = nsimage.TIFFRepresentation
        let bitmap: NSBitmapImageRep! = NSBitmapImageRep(data: data!)
        let pngImage = bitmap!.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [:])
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "image.png"
        if let window = overlayWindow {
            panel.beginSheetModalForWindow(window) { (res) in
                if (res == NSFileHandlingPanelOKButton) {
                    let file = panel.URL
                    print("WRITING TO", file!.absoluteString)
                    do {
                        try pngImage!.writeToFile(file!.path!, options: NSDataWritingOptions.AtomicWrite)
                    } catch {
                        let nsError = error as NSError
                        print(nsError.localizedDescription)
                    }
                }
                self.endScreenshotMode()
            }
        }
        
        //postMedia(pngImage!, ext: "png") {
        //
        //}
    }
    func captureGIF(rect: CGRect) {
        if let window = self.overlayWindow {
            self.capturingGif = true
            window.gifRecordModeOn(rect)
            self.recorder!.startRecordingToTemp(rect)
        }
    }

    func stopCapturingGif() {
        if overlayWindow == nil || self.capturingGif == false || self.recorder == nil {
            return
        }
        let window = overlayWindow!
        window.gifRecordModeOff()
        self.attachStatusWindow()
        self.recorder!.stopRecording { (outputFileURL) in
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "movie.gif"
            panel.beginSheetModalForWindow(window) { (res) in
                let data = NSData(contentsOfURL: outputFileURL)
                if data == nil {
                    print("Failed loading GIF")
                    return
                }
                if (res == NSFileHandlingPanelOKButton) {
                    let toFile = panel.URL
                    print("WRITING TO", toFile!.absoluteString)
                    do {
                        //self.postMedia(data!, ext: "gif") {
                        //
                        //}

                        // Copy temp file
                        try NSFileManager.defaultManager().copyItemAtURL(outputFileURL, toURL: toFile!)
                    } catch {
                        let nsError = error as NSError
                        if (nsError.code == NSFileWriteFileExistsError) {
                            // Delete the file and write to its location.
                            do {
                                try NSFileManager.defaultManager().removeItemAtURL(toFile!)
                                try NSFileManager.defaultManager().copyItemAtURL(outputFileURL, toURL: toFile!)
                            } catch {
                                let nsError = error as NSError
                                print(nsError.localizedDescription)
                            }
                        } else {
                            // General error.
                            print(nsError.localizedDescription)
                        }
                    }
                }
                // Delete temp file
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(outputFileURL)
                } catch {
                    let nsError = error as NSError
                    print(nsError.localizedDescription)
                }
                self.capturingGif = false
                self.recorder = nil
                self.endScreenshotMode()
            }
        }
    }
    
    @IBAction func preferences(sender: AnyObject) {
        print("preferences")
    }

    // Create rectangle view on mouse down
    var origin: CGPoint!
    func mouseDown(event: NSEvent) -> NSEvent {
        // Ignore events when sheet overlay is open
        if overlayWindow != nil && overlayWindow!.attachedSheet != nil {
            return event
        }
        print("Mouse down")
        origin = CGPoint(x: event.locationInWindow.x, y:event.locationInWindow.y)
        attachView(origin)
        return event
    }

    func mouseDragged(event: NSEvent) -> NSEvent {
        if origin == nil || rectangleView == nil {
            return event
        }
        let width = (event.locationInWindow.x - origin.x)
        let height = (event.locationInWindow.y - origin.y)
        if let view = rectangleView {
            view.frame = CGRectMake(origin.x, origin.y, width, height)
        }
        return event
    }
    
    func mouseUp(event: NSEvent) -> NSEvent {
        if origin == nil || rectangleView == nil || overlayWindow == nil {
            return event
        }
        var captureArea = rectangleView!.frame;
        // Normalize the area so the origin is in bottom left
        captureArea = CGRectStandardize(captureArea)
        detachView()
        // Convert the area to display coordinates (display (0,0) is at the top-left)
        print(captureArea)
        var flippedArea = captureArea
        flippedArea.origin.y = NSMaxY(overlayWindow!.frame) - NSMaxY(captureArea)
        // Take screenshot after a delay so the capture area view has time to go away.
        let seconds = 0.1
        let time = dispatch_time(dispatch_time_t(DISPATCH_TIME_NOW), Int64(seconds * Double(NSEC_PER_SEC)))
        dispatch_after(time, dispatch_get_main_queue()) {
            if (self.screenshotCaptureMode) {
                self.captureImage(flippedArea)
            } else {
                self.captureGIF(captureArea)
            }
            self.screenshotCaptureMode = false
            self.gifCaptureMode = false
        }
        return event
    }
    
    func attachStatusWindow() {
        // TODO: Implement
    }
    
    func detachStatusWindow() {
        // TODO: Implement
    }
    
    func attachView(origin: CGPoint) {
        if overlayWindow == nil {
            return
        }
        let view = NSView.init(frame: CGRect.init(origin: origin, size: CGSizeZero))
        view.layer = CALayer()
        view.layer!.backgroundColor = NSColor.clearColor().colorWithAlphaComponent(0.1).CGColor
        view.layer!.borderColor = NSColor.blackColor().colorWithAlphaComponent(0.3).CGColor
        view.alphaValue = 1.0
        view.layer!.borderWidth = 1.0;
        self.overlayWindow!.contentView!.addSubview(view)
        rectangleView = view
    }
    
    func detachView() {
        if let view = rectangleView {
            view.removeFromSuperview()
        }
    }
    
    func postMedia(media: NSData, ext: NSString, callback: () -> Void) {
        let base64 = media.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        let json = "{\"data\": \"\(base64)\", \"extension\": \"\(ext)\"}"
        let request = NSMutableURLRequest(URL: NSURL(string: "http://127.0.0.1:8000/media")!)
        request.HTTPMethod = "POST"
        request.HTTPBody = json.dataUsingEncoding(NSUTF8StringEncoding)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
            guard error == nil && data != nil else {
                print("error=\(error)")
                return
            }
            
            if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(response)")
            }
            
            let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
            print("responseString = \(responseString)")
        }
        task.resume()
    }
}

class MovieRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    var session: AVCaptureSession?
    var output: AVCaptureMovieFileOutput?
    var input: AVCaptureScreenInput?
    
    var callback: ((outputUrl: NSURL) -> Void)?
    
    var ready: Int32 = 0
    
    override init() {
        super.init()
        // Begin aynchronously setting up session and output objects
        let queue = dispatch_queue_create("recorder_init", DISPATCH_QUEUE_CONCURRENT)
        dispatch_async(queue) {
            self.session = AVCaptureSession()
            self.session!.sessionPreset = AVCaptureSessionPresetHigh
            self.output = AVCaptureMovieFileOutput()
            if(self.session!.canAddOutput(self.output)) {
                print("Adding output")
                self.session!.addOutput(self.output)
            }
            let display = CGMainDisplayID()
            self.input = AVCaptureScreenInput.init(displayID: display)
            if(self.session!.canAddInput(self.input)) {
                print("Adding input")
                self.session!.addInput(self.input)
            }
            self.session!.startRunning()
            // Indicate that object is ready
            self.ready += 1
            print("Recorder Ready")
        }
    }
    
    func startRecordingToTemp(rect: CGRect) {
        print("Starting recording function")
        func start(rect: CGRect) {
            self.input!.cropRect = rect
            let tempPath = ("file://" + tempPathName()).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
            self.output!.startRecordingToOutputFileURL(NSURL.init(string: tempPath), recordingDelegate: self)
            print("Started")
        }
        
        let queue = dispatch_queue_create("recorder_start", DISPATCH_QUEUE_CONCURRENT)
        dispatch_async(queue) { 
            while self.ready != 1 {
                // spin
            }
            dispatch_async(dispatch_get_main_queue()) {
                start(rect)
            }
        }
    }
    
    func stopRecording(callback: (outputUrl: NSURL) -> Void) {
        if output == nil {
            // This skips the callback, not a huge deal but be aware that it won't run
            return
        }
        self.callback = callback
        self.output!.stopRecording()
        self.output = nil
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        print("Capture Output", outputFileURL.absoluteString)
        session?.stopRunning()
        session = nil
        // Convert file to GIF using ffmpeg. FIXME: Add spinner during execution
        let filename = outputFileURL.lastPathComponent!
        print("Filename", filename)
        let id = filename.componentsSeparatedByString(".")[0]
        print("ID", id)
        let gifOutputURL = outputFileURL.URLByDeletingLastPathComponent!.URLByAppendingPathComponent("\(id).gif")
        let task = NSTask()
        task.launchPath = "/usr/local/bin/ffmpeg"
        task.arguments =  ["-i", "\(filename)", "-pix_fmt", "rgb24", "\(id).gif"]
        print("Launch path", task.launchPath)
        task.currentDirectoryPath = applicationDirectory() as String
        task.terminationHandler = { (task: NSTask) -> () in
            print("*****************\nTask done")
            // Execute callback on main thread
            dispatch_async(dispatch_get_main_queue()) {
                self.callback!(outputUrl: gifOutputURL)
                self.callback = nil
            }
        }
        task.launch()
    }
    
    func tempPathName() -> String {
        let uuid = NSUUID().UUIDString
        let filename = "tmp_\(uuid).mov"
        return applicationDirectory().stringByAppendingPathComponent(filename)
        
    }
    
    func applicationDirectory() -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)
        let path = paths[0] as NSString
        return path.stringByAppendingPathComponent("Screenshot")
    }
    
    deinit {
        print("=======================")
        print("Recorder dealloc called")
    }
}

