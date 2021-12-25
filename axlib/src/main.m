// https://nodejs.org/api/addons.html#node-api

#include <node_api.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

AXUIElementRef sys_wide;

/**
 * Returns whether or not the Accessibility API is enabled.
 *
 * @method AXEnabled
 * @return {string}
 */
napi_value AXEnabled (napi_env env, napi_callback_info args) {
    napi_value result;

    if (AXAPIEnabled()) {
        napi_create_string_utf8(env, "Enabled", NAPI_AUTO_LENGTH, &result);
    } else {
        napi_create_string_utf8(env, "Not Enabled", NAPI_AUTO_LENGTH, &result);
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

    // Set "y" property. Inverse the y value based on screen height.
    int y = [[NSScreen mainScreen] frame].size.height - mouseLocation.y;
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
    // TODO: Get Minimized Windows
    // Possible approach: kCGWindowListOptionAll|kCGWindowListExcludeDesktopElements
    // https://developer.apple.com/documentation/coregraphics/quartz_window_services/window_list_option_constants?language=objc

    // Get a list of all windows.
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    CFIndex windowListLength = CFArrayGetCount(windowList);

    // Create the array to store our window objects
    napi_value result;
    napi_create_array(env, &result);

    // List of window attributes: https://stackoverflow.com/questions/44680724/how-to-get-array-of-unique-pids-from-cgwindowlistcopywindowinfo-in-swift
    for (int i = 0; i < windowListLength; i++) {
        // Get the dictionary of keys for the window.
        NSDictionary* dict = CFArrayGetValueAtIndex(windowList, i);

        // Prepare the object response
        napi_value result_entry;
        napi_create_object(env, &result_entry);
        
        // Get the name of the Window.
        napi_value result_entry_name;
        napi_create_string_utf8(env, [[dict objectForKey:@"kCGWindowOwnerName"] UTF8String], NAPI_AUTO_LENGTH, &result_entry_name);
        napi_set_named_property(env, result_entry, "name", result_entry_name);

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
    CGImageRef img = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, window, kCGWindowImageNominalResolution || kCGWindowImageBoundsIgnoreFraming);

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

/**
 * Exports all of the functions for this module.
 *
 * @method init
 */
napi_value init (napi_env env, napi_value exports) {

    // Accessibility Initialization
    sys_wide = AXUIElementCreateSystemWide();

    // Export functions to the exports object.
    napi_value fn_AXEnabled;
    napi_create_function(env, NULL, 0, AXEnabled, NULL, &fn_AXEnabled);
    napi_set_named_property(env, exports, "AXEnabled", fn_AXEnabled);

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

    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, init)