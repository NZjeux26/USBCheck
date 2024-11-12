//
//  AppDelegate.swift
//  USBCheck
//
//  Created by Phillip Brown on 08/11/2024.
//
import Cocoa
import IOKit
import IOKit.usb
import UserNotifications
import Security

class AppDelegate: NSObject, NSApplicationDelegate {
    // Properties to manage USB notification and events
    var notificationPort: IONotificationPortRef?  // Port for receiving USB notifications
    var addedIterator: io_iterator_t = 0          // Iterator to track added USB devices
    let notificationCenter = UNUserNotificationCenter.current()  // Notification center for displaying alerts
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request authorization to send user notifications
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
        
        // Create a notification port to listen for USB events
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        
        // Create a matching dictionary to detect USB devices
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        
        // Register for notifications when a USB device is added
        let result = IOServiceAddMatchingNotification(
            notificationPort,                 // Notification port
            kIOFirstMatchNotification,         // Type of event (first match for device add)
            matchingDict,                     // Matching dictionary for USB devices
            { (pointer, iterator) in          // Closure called when a USB device is added
                if let contextPtr = pointer {
                    // Retrieve AppDelegate instance and call usbDeviceAdded method
                    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(contextPtr).takeUnretainedValue()
                    appDelegate.usbDeviceAdded(iterator: iterator)
                }
            },
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), // Pass `self` to closure
            &addedIterator                    // Store result iterator to track added devices
        )
        
        if result == kIOReturnSuccess {
            // Add the notification port to the main run loop to process events
            let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
            
            // Process any USB devices currently connected at startup
            usbDeviceAdded(iterator: addedIterator)
        }
    }
    
    // Method to handle when a new USB device is detected
    func usbDeviceAdded(iterator: io_iterator_t) {
        while case let usbDevice = IOIteratorNext(iterator), usbDevice != 0 {
            //get the device name
            let deviceIdentifer = getDeviceIdentifier(for: usbDevice)
            print(deviceIdentifer)
            showNotification()  // Display a notification for each detected device **Might want to pass device name so it's in the notifcation
            //stright away pass to function to challange
            if let deviceIdentifer = deviceIdentifer {
                challangeUSB(deviceIdentifer: deviceIdentifer)
            }
            //release for memory
            IOObjectRelease(usbDevice)  // Release the device object
        }
    }
    
    // Method to configure and show a local notification
    func showNotification() {
        let content = UNMutableNotificationContent()
        content.title = "USB Device Detected"
        content.body = "USB mounted"  // Message to display in the notification
        content.sound = UNNotificationSound.default
        
        // Create a unique notification request
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, // Unique identifier for the notification
            content: content,              // Notification content
            trigger: nil                   // Immediate delivery
        )
        
        // Add the notification to the center, handling errors if any
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }
    
    func unmountDrive(deviceIdentifier: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["unmount", deviceIdentifier]
        
        task.launch()
        task.waitUntilExit()
    }
    
    func reqAuth() -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [.interactionAllowed, .extendRights], &authRef)
        if status != errSecSuccess {
            print("Error creating authorization: \(status)")
            return nil
        }
        return authRef
    }
    
    func mountDrive(deviceIdentifer: String, authRef: AuthorizationRef){
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["mount", deviceIdentifer]
        
        task.launch()
        task.waitUntilExit()
    }
    //might want to swap the logic, if success then procede vs if not unsuccessfull
    func challangeUSB(deviceIdentifer: String){
        unmountDrive(deviceIdentifier: deviceIdentifer) //unmount device when detected
        //request auth
//        guard let authRef = reqAuth() else{ //failure
//            print("User did not Authorise") //might be abel to move to a notification
//            return
//        }
//        //if successfull then procede
//        mountDrive(deviceIdentifer: deviceIdentifer, authRef: authRef)
    }
    
    func getDeviceIdentifier(for usbDevice: io_object_t) -> String? {
        var deviceIdentifier: String?

        // Try to retrieve the device name from the USB Device tree
        if let deviceNameCF = IORegistryEntrySearchCFProperty(
            usbDevice,
            kIOServicePlane,
            kUSBProductString as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        ), let deviceName = deviceNameCF as? String {
            deviceIdentifier = deviceName
        } else {
            // Fallback to retrieve vendor/product ID if product name is unavailable
            if let vendorIDCF = IORegistryEntryCreateCFProperty(usbDevice, kUSBVendorID as CFString, kCFAllocatorDefault, 0),
               let productIDCF = IORegistryEntryCreateCFProperty(usbDevice, kUSBProductID as CFString, kCFAllocatorDefault, 0),
               let vendorID = vendorIDCF.takeUnretainedValue() as? NSNumber,
               let productID = productIDCF.takeUnretainedValue() as? NSNumber {
                deviceIdentifier = String(format: "VendorID: %04x, ProductID: %04x", vendorID.intValue, productID.intValue)
            }
        }
        
        return deviceIdentifier
    }
    
//    func getDeviceIdentifier(for usbDevice: io_object_t) -> String? {
//        var deviceIdentifier: String?
//        if let bsdNameCString = IORegistryEntryCreateCFProperty(usbDevice, kIOBSDNameKey as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
//            deviceIdentifier = bsdNameCString
//        }
//        return deviceIdentifier
//    }
}
