import Cocoa
import IOKit
import IOKit.usb
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var notificationPort: IONotificationPortRef?
    var addedIterator: io_iterator_t = 0
    let notificationCenter = UNUserNotificationCenter.current()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification authorization
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
        
        // Create a notification port
        notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
        
        // Create a matching dictionary for USB devices
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        
        // Set up notifications for USB device addition
        let result = IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            matchingDict,
            { (pointer, iterator) in
                if let contextPtr = pointer {
                    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(contextPtr).takeUnretainedValue()
                    appDelegate.usbDeviceAdded(iterator: iterator)
                }
            },
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &addedIterator
        )
        
        if result == kIOReturnSuccess {
            // Add notification port to the current run loop
            let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
            
            // Handle any existing USB devices
            usbDeviceAdded(iterator: addedIterator)
        }
    }
    
    func usbDeviceAdded(iterator: io_iterator_t) {
        while case let usbDevice = IOIteratorNext(iterator), usbDevice != 0 {
            showNotification()
            IOObjectRelease(usbDevice)
        }
    }
    
    func showNotification() {
        let content = UNMutableNotificationContent()
        content.title = "USB Device Detected"
        content.body = "HELLO USB"
        content.sound = UNNotificationSound.default
        
        // Create a notification request with a unique identifier
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        // Add the notification request to the notification center
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }
}