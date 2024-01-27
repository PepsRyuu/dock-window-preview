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

                CFRelease(value);
                CFRelease(axTitle);
                CFRelease(axIsApplicationRunning);
            }

            CFRelease(axSubrole);

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

        // The list we fetched is huge, and contains every possible window, both real and fake.
        // To determine real windows, they must be layer 0. Stuff like Finder has stuff on negative layers, and menubar is a higher layer.
        // Later on the AX API is used to determine if the window is visible to accessibility API.
        if (layer == 0) {
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
            napi_set_named_property(env, result_entry, "wid", result_entry_window);

            // Push to the array
            napi_set_element(env, result, i, result_entry);
        } 

    }

    CFRelease(windowList);

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
    int wid;
    napi_get_value_int64(env, args[0], &wid);

    // Generate the image. This will trigger permission request.
    CGImageRef img = NULL;

    // This is a private API method. It seems to be a LOT faster than the public method. 
    // The other reason to use this is because it also can take images of minimized windows.
    // Despite the name, it only allows to return one image, but that's fine for our purposes.  
    //
    // <PRIVATE API>
    CFArrayRef img_arr = CGSHWCaptureWindowList(CGSMainConnectionID(), &wid, 1, kCGSCaptureIgnoreGlobalClipShape | kCGSWindowCaptureNominalResolution);

    // If we have an image, take it from the "list". Again, it only returns a single image anyways.
    if (img_arr) {
        img = (CGImageRef)CFArrayGetValueAtIndex(img_arr, 0);
    }

    // If for some reason the above did not work, fallback to the slower function instead.
    if (!img) {
        img = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, wid, kCGWindowImageNominalResolution | kCGWindowImageBoundsIgnoreFraming);
    }

    if (img) {
        // Scale down the image
        int bitsPerComponent = CGImageGetBitsPerComponent(img);
        int bytesPerRow = CGImageGetBytesPerRow(img);
        CGColorSpaceRef colorSpace = CGImageGetColorSpace(img);

        // Scale down the image to a fixed size but maintain the aspect ratio.
        int nativeWidth = CGImageGetWidth(img);
        int nativeHeight = CGImageGetHeight(img);
        float scaleRatio = nativeWidth > nativeHeight? 500.0f / nativeWidth : 500.0f / nativeHeight;

        CGContextRef context = CGBitmapContextCreate(
            NULL, 
            (int)(nativeWidth * scaleRatio), 
            (int)(nativeHeight * scaleRatio), 
            bitsPerComponent, 
            bytesPerRow / nativeWidth * (int)(nativeWidth * scaleRatio), 
            colorSpace, 
            CGImageGetBitmapInfo(img)
        );

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
        CGContextRelease(context);
        CGImageRelease(scaled_img);
        CFRelease(raw_data_ref);

        if (img_arr) {
            CFRelease(img_arr);
        } else {
            CFRelease(img);
        }

        return result;
    }

    if (img_arr) {
        CFRelease(img_arr);
    } else {
        CFRelease(img);
    }
    
    return NULL;
}

/**
 * Objective-C class to avoid shared variables
 * between C functions and Objective-C.
 *
 * @class WindowActionPerformer
 */
@interface WindowActionPerformer:NSObject
- (int) trigger: (int)pid wid:(int)wid action:(int)action;
@end

@implementation WindowActionPerformer

- (int) trigger: (int)pid wid:(int)wid action:(int)action {
    
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
            CGWindowID current_wid;

            // <PRIVATE API>
            _AXUIElementGetWindow(windows[i], &current_wid);
            if (current_wid == wid) {
                if (action == 1) {
                    // As far as I can tell, this will tell the operating system to switch to this app.
                    // https://stackoverflow.com/questions/2333078/how-to-launch-application-and-bring-it-to-front-using-cocoa-api/2334362#2334362
                    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier: pid];
                    [app activateWithOptions: NSApplicationActivateIgnoringOtherApps];
                }

                // Perform the actual raising of the app. 
                // For closing minimised apps, we need to raise it before we can press the quit button.
                if (action == 1 || action == 2) {
                    AXError error = AXUIElementPerformAction(windows[i], kAXRaiseAction);
                }

                if (action == 2) {
                    CFTypeRef closeBtn = NULL;
                    AXUIElementCopyAttributeValue(windows[i], kAXCloseButtonAttribute, &closeBtn);
                    if (!closeBtn) {
                        return 0;
                    }

                    AXUIElementPerformAction(closeBtn, kAXPressAction);
                    CFRelease(closeBtn);
                }
            }
        }
    }

    return 0; 
}

@end

/**
 * Perform action on window (raise/close)
 *
 * @method AXPerformActionOnWindow
 * @param {int} pid
 * @param {int} window
 * @param {int} action
 */
napi_value AXPerformActionOnWindow (napi_env env, napi_callback_info info) {
    // Extract function arguments
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, &args, NULL, NULL);

    // Extract the parameters
    int pid;
    int wid;
    int action;
    napi_get_value_int64(env, args[0], &pid);
    napi_get_value_int64(env, args[1], &wid);
    napi_get_value_int64(env, args[2], &action);

    // This might look bizarre. Why create a separate class?
    // I think there's an C/ObjC interop issue? If I inline all of the code from this class into this function, the pid value will reset to 0.
    // Sometimes uncommenting and commenting unrelated lines of code also makes it work again.
    // I suspect because there's an int that's manipulated on a low-level by a C function, even if ObjC is called much later
    // it will refuse to use it, and instead reset to an empty value of 0.
    // Somehow this works around the issue. If anyone can explain this to me, it would be much appreciated.
    WindowActionPerformer* raiser = [[WindowActionPerformer alloc]init];
    [raiser trigger:pid wid:wid action:action];

    return NULL;
}

/**
 * Checks to see if the provided window is a real window.
 *
 * @method AXCheckIfStandardWindow
 * @param {int} pid
 * @param {int} window
 * @return {int}
 */
napi_value AXCheckIfStandardWindow (napi_env env, napi_callback_info info) {
     // Extract function arguments
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, &args, NULL, NULL);

    // Extract the parameters
    int pid;
    int wid;
    napi_get_value_int64(env, args[0], &pid);
    napi_get_value_int64(env, args[1], &wid);

    AXUIElementRef element = AXUIElementCreateApplication(pid);

    // This window list contains all of the visible onscreen and minimised windows.
    // Compare against this array and if the window is inside this array
    // then we should show it. This might seem somewhat redundant, but we can't
    // access this without the PID of the process, which we can only get from
    // the previous AXGetWindowList call. 
    CFArrayRef array;
    AXUIElementCopyAttributeValues(element, kAXWindowsAttribute, 0, 99999, &array);

    if (array == NULL) {
        return 0;
    }

    NSArray *windows = (NSArray *)CFBridgingRelease(array);
    CFIndex windowListLength = CFArrayGetCount(windows);

    for (int i = 0; i < windowListLength; i++) {
        CGWindowID current_wid;

        // <PRIVATE API>
        _AXUIElementGetWindow(windows[i], &current_wid);

        if (current_wid == wid) {
            NSString* axSubrole;

            if (AXUIElementCopyAttributeValue(windows[i], kAXSubroleAttribute, (CFTypeRef*)&axSubrole) == 0) {
                bool isStandardWindow = !CFEqual(axSubrole, kAXUnknownSubrole);
                CFRelease(axSubrole);

                if (isStandardWindow) {
                    napi_value result;
                    napi_create_int32(env, 1, &result);
                    return result;
                }
            }
        }
    }

    return NULL;
}

// Track the callbacks used for the mouse observers
// Example: https://giters.com/electron/electron/issues/30122
// Example: https://github.com/nodejs/node/blob/master/test/node-api/test_threadsafe_function/binding.c
// https://nodejs.org/api/n-api.html#napi_create_threadsafe_function
napi_threadsafe_function ts_func_global_mouse_move;
napi_threadsafe_function ts_func_global_mouse_down;
napi_threadsafe_function ts_func_local_mouse_down;
bool in_progress_move_callback = false;

/**
 * Triggers the given callback.
 *
 * @method TriggerJSCallback
 */
void TriggerJSCallback(napi_env env, napi_value callback, void* context, void* data) {
    napi_handle_scope scope;
    napi_open_handle_scope(env, &scope);
    napi_value this;
    napi_get_undefined(env, &this);
    napi_value result;
    napi_call_function(env, this, callback, 0, NULL, &result);
    napi_close_handle_scope(env, scope);
}

/**
 * Listens for mouse move event unrelated to this application.
 *
 * @method AXObserveGlobalMouseMove
 * @param {Function} callback
 */
napi_value AXObserveGlobalMouseMove (napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, &args, NULL, NULL);
 
    napi_value name;
    napi_create_string_utf8(env, "AXObserveGlobalMouseMove", NAPI_AUTO_LENGTH, &name);

    napi_create_threadsafe_function(
        env, args[0], NULL, name, 50, 1,
        NULL, NULL, NULL,
        TriggerJSCallback, &ts_func_global_mouse_move
    );

    [NSEvent addGlobalMonitorForEventsMatchingMask:(NSMouseMovedMask) handler:^(NSEvent *event) {
        if (!in_progress_move_callback) {
            in_progress_move_callback = true;
            // Caps the CPU usage while the mouse is moving to roughly 3%
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^ {
                in_progress_move_callback = false;
                napi_acquire_threadsafe_function(ts_func_global_mouse_move);
                napi_call_threadsafe_function(ts_func_global_mouse_move, NULL, napi_tsfn_blocking);
            });
        }
    }];

    return NULL;
}

/**
 * Listens for mouse down events that are unrelated to this application.
 *
 * @method AXObserveGlobalMouseDown
 * @param {Function} callback
 */
napi_value AXObserveGlobalMouseDown (napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, &args, NULL, NULL);
 
    napi_value name;
    napi_create_string_utf8(env, "AXObserveGlobalMouseDown", NAPI_AUTO_LENGTH, &name);

    napi_create_threadsafe_function(
        env, args[0], NULL, name, 50, 1,
        NULL, NULL, NULL,
        TriggerJSCallback, &ts_func_global_mouse_down
    );

    // https://developer.apple.com/documentation/appkit/nsevent/1535472-addglobalmonitorforeventsmatchin
    [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDownMask) handler:^(NSEvent *event) {
        napi_acquire_threadsafe_function(ts_func_global_mouse_down);
        napi_call_threadsafe_function(ts_func_global_mouse_down, NULL, napi_tsfn_blocking);
    }];

    return NULL;
}

/**
 * Listens for mouse down events that are for this application.
 *
 * @method AXObserveLocalMouse
 * @param {Function} callback
 */
napi_value AXObserveLocalMouseDown (napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, &args, NULL, NULL);
 
    napi_value name;
    napi_create_string_utf8(env, "AXObserveLocalMouseDown", NAPI_AUTO_LENGTH, &name);

    napi_create_threadsafe_function(
        env, args[0], NULL, name, 50, 1,
        NULL, NULL, NULL,
        TriggerJSCallback, &ts_func_local_mouse_down
    );

    // https://developer.apple.com/documentation/appkit/nsevent/1534971-addlocalmonitorforeventsmatching
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown) handler:^NSEvent *(NSEvent *event) {
        napi_acquire_threadsafe_function(ts_func_local_mouse_down);
        napi_call_threadsafe_function(ts_func_local_mouse_down, NULL, napi_tsfn_blocking);
        return event;
    }];


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

    napi_value fn_AXPerformActionOnWindow;
    napi_create_function(env, NULL, 0, AXPerformActionOnWindow, NULL, &fn_AXPerformActionOnWindow);
    napi_set_named_property(env, exports, "AXPerformActionOnWindow", fn_AXPerformActionOnWindow);

    napi_value const_ACTION_RAISE;
    napi_create_int32(env, 1, &const_ACTION_RAISE);
    napi_set_named_property(env, exports, "ACTION_RAISE", const_ACTION_RAISE);
    
    napi_value const_ACTION_CLOSE;
    napi_create_int32(env, 2, &const_ACTION_CLOSE);
    napi_set_named_property(env, exports, "ACTION_CLOSE", const_ACTION_CLOSE);

    napi_value fn_AXCheckIfStandardWindow;
    napi_create_function(env, NULL, 0, AXCheckIfStandardWindow, NULL, &fn_AXCheckIfStandardWindow);
    napi_set_named_property(env, exports, "AXCheckIfStandardWindow", fn_AXCheckIfStandardWindow);

    napi_value fn_AXObserveGlobalMouseMove;
    napi_create_function(env, NULL, 0, AXObserveGlobalMouseMove, NULL, &fn_AXObserveGlobalMouseMove);
    napi_set_named_property(env, exports, "AXObserveGlobalMouseMove", fn_AXObserveGlobalMouseMove);

    napi_value fn_AXObserveGlobalMouseDown;
    napi_create_function(env, NULL, 0, AXObserveGlobalMouseDown, NULL, &fn_AXObserveGlobalMouseDown);
    napi_set_named_property(env, exports, "AXObserveGlobalMouseDown", fn_AXObserveGlobalMouseDown);

    napi_value fn_AXObserveLocalMouseDown;
    napi_create_function(env, NULL, 0, AXObserveLocalMouseDown, NULL, &fn_AXObserveLocalMouseDown);
    napi_set_named_property(env, exports, "AXObserveLocalMouseDown", fn_AXObserveLocalMouseDown);

    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, init)