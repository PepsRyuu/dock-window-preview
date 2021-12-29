// https://nodejs.org/api/n-api.html

#include <node_api.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

// Exposing Private API
// https://opensource.apple.com/source/WebCore/WebCore-7606.4.5/PAL/pal/spi/cg/CoreGraphicsSPI.h.auto.html
uint32_t CGSMainConnectionID(void);
CFArrayRef CGSHWCaptureWindowList(uint32_t, CGWindowID* windowList, uint32_t, CGSWindowCaptureOptions);
typedef enum { kCGSWindowCaptureNominalResolution = 0x0200,  kCGSCaptureIgnoreGlobalClipShape = 0x0800 } CGSWindowCaptureOptions;

// Expose private api for getting the window ID from an accessibility element.
AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);

// Global accessibility object.
AXUIElementRef sys_wide;

/**
 * Returns whether or not the Accessibility API is enabled.
 *
 * @method AXHasAccessibilityPermission
 * @return {int}
 */
napi_value AXHasAccessibilityPermission (napi_env env, napi_callback_info args) {
    napi_value result;

    if (AXAPIEnabled()) {
        napi_create_int32(env, 1, &result);
    } else {
        napi_create_int32(env, 0, &result);
    }

    return result;
}

/**
 * Returns whether or not the Screen Recording API is enabled.
 *
 * @method AXHasScreenRecordingPermission
 * @return {int}
 */
napi_value AXHasScreenRecordingPermission (napi_env env, napi_callback_info args) {
    napi_value result;

    if (CGPreflightScreenCaptureAccess()) {
        napi_create_int32(env, 1, &result);
    } else {
        napi_create_int32(env, 0, &result);
    }

    return result;
}

/**
 * Returns x,y position of the mouse. 
 * Normalizes the result so Y maxes out when mouse moves to bottom of screen.
 * 
 * @method AXGetMousePosition
 * @return {Object}
 */
napi_value AXGetMousePosition (napi_env env, napi_callback_info info) {
    // Get global location of the mouse.
    NSPoint mouseLocation = [NSEvent mouseLocation];

    // Create Object
    napi_value result;
    napi_create_object(env, &result);

    // Set "x" property
    napi_value result_x;
    napi_create_int32(env, mouseLocation.x, &result_x);
    napi_set_named_property(env, result, "x", result_x);

    // All of the mouse co-ordinates for multiple monitors are based on the primary screen.
    // So if you have monitor A (1080) to your left, and monitor B to the right (1200), arranged in such a way 
    // that they are both vertically aligned to the top, if your mouse was on B at the bottom, it would 
    // report a position of -120 for the Y value. 
    //
    // The accessibility API uses the inverse, so we need to convert this Y value to something it understands.
    // To do this, we take the first primary display, and get it's height. 
    // So using the above example: 1080 - (-120) = 1200.
    CGFloat primary_display_height = NSMaxY([[[NSScreen screens] firstObject] frame]);
    int y = primary_display_height - mouseLocation.y;

    // Set "y" property
    napi_value result_y;
    napi_create_int32(env, y, &result_y);
    napi_set_named_property(env, result, "y", result_y);

    return result;
}

/**
 * Returns the accessibility element at the given location.
 * If it is a Dock item, provides further information about it.
 *
 * @method AXGetElementAtPosition
 * @param {Integer} x
 * @param {Integer} y
 * @return {Object}
 */
napi_value AXGetElementAtPosition (napi_env env, napi_callback_info info) {
    // Enable access to args.
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, &args, NULL, NULL);
  
    // Get X and Y params
    int x;
    int y;
    napi_get_value_int64(env, args[0], &x);
    napi_get_value_int64(env, args[1], &y);

    // This element will contain whatever we are hovering over.
    AXUIElementRef element = NULL;
    
    // Check to see what it is
    int err = AXUIElementCopyElementAtPosition(sys_wide, x, y, &element);

    // Check to see if this found something, if not, return undefined.
    if (err == kAXErrorSuccess) {
        NSString* axSubrole;

        if (AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, (CFTypeRef*)&axSubrole) == 0) {
            
            // We found something, prepare the output object.
            napi_value result;
            napi_create_object(env, &result);

            // Grab the type of the element we are hovering.
            napi_value result_type;
            napi_create_string_utf8(env, [axSubrole UTF8String], NAPI_AUTO_LENGTH, &result_type);
            napi_set_named_property(env, result, "type", result_type);

            // If this is a Dock item, gather more information.
            if ([axSubrole isEqualToString:@"AXApplicationDockItem"]) {
                AXValueRef value;
                NSRect rect;
                NSString* axTitle;
                NSNumber* axIsApplicationRunning;
  
                // Get the size of the element
                AXUIElementCopyAttributeValue(element, kAXSizeAttribute, (CFTypeRef*)&value);
                AXValueGetValue(value, kAXValueCGSizeType, (void *) &rect.size);

                // Get the position of the element
                AXUIElementCopyAttributeValue(element, kAXPositionAttribute, (CFTypeRef*) &value);
                AXValueGetValue(value, kAXValueCGPointType, (void *) &rect.origin);

                // Get the title of the element
                AXUIElementCopyAttributeValue(element, kAXTitleAttribute, (CFTypeRef*)&axTitle);

                // Get the running status of the element
                AXUIElementCopyAttributeValue(element, kAXIsApplicationRunningAttribute, (CFTypeRef*)&axIsApplicationRunning);

                // Output the title of the element
                napi_value result_title;
                napi_create_string_utf8(env, [axTitle UTF8String], NAPI_AUTO_LENGTH, &result_title);
                napi_set_named_property(env, result, "title", result_title);

                // Output the running status of the element
                napi_value result_running;
                napi_create_int32(env, [axIsApplicationRunning intValue], &result_running);
                napi_set_named_property(env, result, "running", result_running);

                // Create an object with X and Y position of the element
                napi_value result_position;
                napi_create_object(env, &result_position);
                napi_value result_position_x;
                napi_create_int32(env, rect.origin.x, &result_position_x);
                napi_set_named_property(env, result_position, "x", result_position_x);
                napi_value result_position_y;
                napi_create_int32(env, rect.origin.y, &result_position_y);
                napi_set_named_property(env, result_position, "y", result_position_y);
                napi_set_named_property(env, result, "position", result_position);

                // Create an object with the Width and Height of the element
                napi_value result_size;
                napi_create_object(env, &result_size);
                napi_value result_size_width;
                napi_create_int32(env, rect.size.width, &result_size_width);
                napi_set_named_property(env, result_size, "width", result_size_width);
                napi_set_named_property(env, result, "size", result_size);
                napi_value result_size_height;
                napi_create_int32(env, rect.size.height, &result_size_height);
                napi_set_named_property(env, result_size, "height", result_size_height);
                napi_set_named_property(env, result, "size", result_size);
            }

            return result;
        }
    }
  
    return NULL;
}

/**
 * Returns a list of all windows and their properties.
 *
 * @method AXGetWindowList
 * @return {Array<Object>}
 */
napi_value AXGetWindowList (napi_env env, napi_callback_info info) {
    // Get a list of all windows.
    // https://developer.apple.com/documentation/coregraphics/quartz_window_services/window_list_option_constants?language=objc
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    CFIndex windowListLength = CFArrayGetCount(windowList);

    // Create the array to store our window objects
    napi_value result;
    napi_create_array(env, &result);

    // List of window attributes
    // https://stackoverflow.com/questions/44680724/how-to-get-array-of-unique-pids-from-cgwindowlistcopywindowinfo-in-swift
    for (int i = 0; i < windowListLength; i++) {
        // Get the dictionary of keys for the window.
        NSDictionary* dict = CFArrayGetValueAtIndex(windowList, i);

        // Determining if we should show this window.
        NSString* name = [dict objectForKey:@"kCGWindowName"];
        int layer = [[dict objectForKey:@"kCGWindowLayer"] intValue];
        int onscreen = [[dict objectForKey:@"kCGWindowIsOnscreen"] intValue];

        // The list we fetched is huge, and contains every possible window, both real and fake.
        // To determine real windows, we're checking if they either have a proper name, or are on the screen.
        // Also they must be layer 0. Stuff like Finder has stuff on negative layers, and menubar is a higher layer.
        // Some windows may have name defined, but with no title, don't show them (eg. Fullscreen apps create a blank title window)
        // TODO: Need to figure out why some apps like VSCode still show fake windows.
        if ((name || onscreen) && layer == 0 && (name? name.length > 0 : true)) {
            // Prepare the object response
            napi_value result_entry;
            napi_create_object(env, &result_entry);

            if (name) {
                napi_value result_entry_name;
                napi_create_string_utf8(env, [name UTF8String], NAPI_AUTO_LENGTH, &result_entry_name);
                napi_set_named_property(env, result_entry, "name", result_entry_name);
            }  

            // Get the name of the Window.
            napi_value result_entry_owner;
            napi_create_string_utf8(env, [[dict objectForKey:@"kCGWindowOwnerName"] UTF8String], NAPI_AUTO_LENGTH, &result_entry_owner);
            napi_set_named_property(env, result_entry, "owner", result_entry_owner);

            // Get Onscreen status
            napi_value result_entry_onscreen;
            napi_create_int32(env, [[dict objectForKey:@"kCGWindowIsOnscreen"] intValue], &result_entry_onscreen);
            napi_set_named_property(env, result_entry, "onscreen", result_entry_onscreen);
        
            // Get the layer of the Window.
            napi_value result_entry_layer;
            napi_create_int64(env, [[dict objectForKey:@"kCGWindowLayer"] intValue], &result_entry_layer);
            napi_set_named_property(env, result_entry, "layer", result_entry_layer);

            // Get the PID of the Window
            napi_value result_entry_pid;
            napi_create_int32(env, [[dict objectForKey:@"kCGWindowOwnerPID"] intValue], &result_entry_pid);
            napi_set_named_property(env, result_entry, "pid", result_entry_pid);

            // Get the Window ID
            napi_value result_entry_window;
            napi_create_int32(env, [[dict objectForKey:@"kCGWindowNumber"] intValue], &result_entry_window);
            napi_set_named_property(env, result_entry, "window", result_entry_window);

            // Push to the array
            napi_set_element(env, result, i, result_entry);
        }
    }

    return result;
}

/**
 * Returns a scaled image object of the selected window.
 *
 * @method AXGetWindowPreview
 * @param {Integer} window
 * @return {Object}
 */
napi_value AXGetWindowPreview (napi_env env, napi_callback_info info) {
    // Extract function arguments
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, &args, NULL, NULL);

    // Extract the window ID parameter    
    int window;
    napi_get_value_int64(env, args[0], &window);

    // Generate the image. This will trigger permission request.
    CGImageRef img = NULL;

    // This is a private API method. It seems to be a LOT faster than the public method. 
    // The other reason to use this is because it also can take images of minimized windows.
    // Despite the name, it only allows to return one image, but that's fine for our purposes.  
    //
    // <PRIVATE API>
    CFArrayRef img_arr = CGSHWCaptureWindowList(CGSMainConnectionID(), &window, 1, kCGSCaptureIgnoreGlobalClipShape | kCGSWindowCaptureNominalResolution);

    // If we have an image, take it from the "list". Again, it only returns a single image anyways.
    if (img_arr) {
        img = (CGImageRef)CFArrayGetValueAtIndex(img_arr, 0);
    }

    // If for some reason the above did not work, fallback to the slower function instead.
    if (!img) {
        img = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, window, kCGWindowImageNominalResolution | kCGWindowImageBoundsIgnoreFraming);
    }

    if (img) {
        // Scale down the image
        int bitsPerComponent = CGImageGetBitsPerComponent(img);
        int bytesPerRow = CGImageGetBytesPerRow(img);
        CGColorSpaceRef colorSpace = CGImageGetColorSpace(img);
        // TODO: Have the width and height as parameters
        CGContextRef context = CGBitmapContextCreate(NULL, 500, 500, bitsPerComponent, bytesPerRow / CGImageGetWidth(img) * 500, colorSpace, CGImageGetBitmapInfo(img));
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        CGContextDrawImage(context, CGContextGetClipBoundingBox(context), img);

        // Get new image reference to output.
        CGImageRef scaled_img = CGBitmapContextCreateImage(context);

        // Create the object response
        napi_value result;
        napi_create_object(env, &result);

        // Set the width property on the object
        napi_value result_width;
        napi_create_int32(env, CGImageGetWidth(scaled_img), &result_width);
        napi_set_named_property(env, result, "width", result_width);

        // Set the height property on the object
        napi_value result_height;
        napi_create_int32(env, CGImageGetHeight(scaled_img), &result_height);
        napi_set_named_property(env, result, "height", result_height);

        // Extract the raw byte array buffer from the image
        CFDataRef raw_data_ref = CGDataProviderCopyData(CGImageGetDataProvider(scaled_img));
        UInt8* raw_data_bytes = (UInt8*)CFDataGetBytePtr(raw_data_ref); 
        int raw_data_length = CFDataGetLength(raw_data_ref);

        // Create an instance of Buffer and attach the object response
        napi_value result_data;
        napi_create_buffer_copy(env, raw_data_length, raw_data_bytes, NULL, &result_data);
        napi_set_named_property(env, result, "data", result_data);

        // Clean up pointers
        CFRelease(raw_data_ref);

        return result;
    }
    
    return NULL;
}

/**
 * Objective-C class to avoid shared variables
 * between C functions and Objective-C.
 *
 * @class WindowRaiser
 */
@interface WindowRaiser:NSObject
- (int) trigger: (int)pid window:(int)window index:(int)index;
@end

@implementation WindowRaiser

- (int) trigger: (int)pid window:(int)window index:(int)index {
    // As far as I can tell, this will tell the operating system to switch to this app.
    // https://stackoverflow.com/questions/2333078/how-to-launch-application-and-bring-it-to-front-using-cocoa-api/2334362#2334362
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: pid];
    [app activateWithOptions: NSApplicationActivateIgnoringOtherApps];

    // After switching the app, we need to bring the correct window into focus.
    // Due to a limitation with the accessibility API, we have to use the window index.
    // https://stackoverflow.com/questions/47066205/macos-activate-a-window-given-its-window-id
    AXUIElementRef element = AXUIElementCreateApplication(pid);

    if (element) {
        CFArrayRef array;
        // This includes all windows, but in order of front -> back.
        // This is inconsistent with the window list option kCGWindowListOptionAll.
        AXUIElementCopyAttributeValues(element, kAXWindowsAttribute, 0, 99999, &array);

        if (array == NULL) {
            return 0;
        }

        NSArray *windows = (NSArray *)CFBridgingRelease(array);
        CFIndex windowListLength = CFArrayGetCount(windows);

        // Since the window list order from accessibility api is not the same as the window
        // list order from the kCGWindowListOptionAll, we have to find the correct window ourselves.
        // Unfortunately there's no way of doing this cleanly. So we're using the private API method
        // to get the id of the window and seeing if that's the one we clicked.
        // Other approaches could be to check the position, size, and title of the windows.
        for (int i = 0; i < windowListLength; i++) {
            CGWindowID winId;

            // <PRIVATE API>
            _AXUIElementGetWindow(windows[i], &winId);
            if (winId == window) {
                AXError error = AXUIElementPerformAction(windows[i], kAXRaiseAction);
            }
        }
    }

    return 0; 
}

@end

/**
 * Tries to raise the selected window.
 *
 * @method AXRaiseAppWindow
 * @param {int} pid
 * @param {int} window
 * @param {int} window_index
 */
napi_value AXRaiseAppWindow (napi_env env, napi_callback_info info) {
    // Extract function arguments
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, &args, NULL, NULL);

    // Extract the parameters
    int pid;
    int window;
    int index;
    napi_get_value_int64(env, args[0], &pid);
    napi_get_value_int64(env, args[1], &window);
    napi_get_value_int64(env, args[2], &index);

    // This might look bizarre. Why create a separate class?
    // I think there's an C/ObjC interop issue? If I inline all of the code from this class into this function, the pid value will reset to 0.
    // Sometimes uncommenting and commenting unrelated lines of code also makes it work again.
    // I suspect because there's an int that's manipulated on a low-level by a C function, even if ObjC is called much later
    // it will refuse to use it, and instead reset to an empty value of 0.
    // Somehow this works around the issue. If anyone can explain this to me, it would be much appreciated.
    WindowRaiser* raiser = [[WindowRaiser alloc]init];
    [raiser trigger:pid window:window index:index];

    return NULL;
}

/**
 * Exports all of the functions for this module.
 *
 * @method init
 */
napi_value init (napi_env env, napi_value exports) {

    // Accessibility Initialization
    sys_wide = AXUIElementCreateSystemWide();

    // Export functions to the exports object.
    napi_value fn_AXHasAccessibilityPermission;
    napi_create_function(env, NULL, 0, AXHasAccessibilityPermission, NULL, &fn_AXHasAccessibilityPermission);
    napi_set_named_property(env, exports, "AXHasAccessibilityPermission", fn_AXHasAccessibilityPermission);

    napi_value fn_AXHasScreenRecordingPermission;
    napi_create_function(env, NULL, 0, AXHasScreenRecordingPermission, NULL, &fn_AXHasScreenRecordingPermission);
    napi_set_named_property(env, exports, "AXHasScreenRecordingPermission", fn_AXHasScreenRecordingPermission);

    napi_value fn_AXGetElementAtPosition;
    napi_create_function(env, NULL, 0, AXGetElementAtPosition, NULL, &fn_AXGetElementAtPosition);
    napi_set_named_property(env, exports, "AXGetElementAtPosition", fn_AXGetElementAtPosition);

    napi_value fn_AXGetWindowList;
    napi_create_function(env, NULL, 0, AXGetWindowList, NULL, &fn_AXGetWindowList);
    napi_set_named_property(env, exports, "AXGetWindowList", fn_AXGetWindowList);

    napi_value fn_AXGetWindowPreview;
    napi_create_function(env, NULL, 0, AXGetWindowPreview, NULL, &fn_AXGetWindowPreview);
    napi_set_named_property(env, exports, "AXGetWindowPreview", fn_AXGetWindowPreview);

    napi_value fn_AXGetMousePosition;
    napi_create_function(env, NULL, 0, AXGetMousePosition, NULL, &fn_AXGetMousePosition);
    napi_set_named_property(env, exports, "AXGetMousePosition", fn_AXGetMousePosition);

    napi_value fn_AXRaiseAppWindow;
    napi_create_function(env, NULL, 0, AXRaiseAppWindow, NULL, &fn_AXRaiseAppWindow);
    napi_set_named_property(env, exports, "AXRaiseAppWindow", fn_AXRaiseAppWindow);

    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, init)