let gui = require('gui');
let axlib = require('../axlib');
let config = require('./config');

function bmp_img_encoder (img) {
    // http://www.ece.ualberta.ca/~elliott/ee552/studentAppNotes/2003_w/misc/bmp_file_format/bmp_file_format.htm
    let dataOffset = 54;
    let imageWidthSize =  4 * img.width;
    let buffer = new Buffer(dataOffset + img.height * imageWidthSize);
    
    let pos = 0;
    buffer.write('BM', pos, 2); pos += 2; // Signature
    buffer.writeUInt32LE(dataOffset + img.height * imageWidthSize, pos); pos += 4; // File Size
    buffer.writeUInt32LE(0, pos); pos += 4; // Reserved
    buffer.writeUInt32LE(dataOffset, pos); pos += 4; // DataOffset
    buffer.writeUInt32LE(40, pos); pos += 4; // InfoHeader Size
    buffer.writeUInt32LE(img.width, pos); pos += 4; // image width
    buffer.writeInt32LE(-img.height, pos); pos += 4; // image height, hack to ensure correct orientation
    buffer.writeUInt16LE(1, pos); pos += 2; // planes
    buffer.writeUInt16LE(32, pos); pos += 2; // Bits per Pixel
    buffer.writeUInt32LE(0, pos); pos += 4; // Compression (none)
    buffer.writeUInt32LE(img.height * imageWidthSize, pos); pos += 4; // Image Size
    buffer.writeUInt32LE(0, pos); pos += 4; // X Pixels Per Meter
    buffer.writeUInt32LE(0, pos); pos += 4; // Y Pixels Per Meter
    buffer.writeUInt32LE(0, pos); pos += 4; // Colors Used
    buffer.writeUInt32LE(0, pos); pos += 4; // Important Colors

    img.data.copy(buffer, pos);

    return buffer;
}

module.exports = {
    init () {
        // Create empty window to start off with.
        // This window will be used for previewing.
        let win = gui.Window.create({ frame: false, transparent: true });
        win.setAlwaysOnTop(true);
        win.setContentSize({ width: 1, height: 1 });
        win.onClose = () => gui.MessageLoop.quit();

        // Create writable view to render into.
        let contentview = gui.Container.create();
        contentview.setMouseDownCanMoveWindow(false);
        win.setContentView(contentview);

        const MARGIN_FROM_DOCK = 50;
        const WINDOW_MARGIN = 5;
        const PREVIEW_GAP = 20;
        const PREVIEW_WIDTH = 200;
        const CAPTION_HEIGHT = 14;
        const THUMBNAIL_HEIGHT = 160;
        const PREVIEW_HEIGHT = THUMBNAIL_HEIGHT + CAPTION_HEIGHT;
        const font = gui.Font.create('Arial', 11, 'normal', 'normal');

        function MouseToPreviewIndex (x) {
            let index = parseInt(x / (PREVIEW_WIDTH + PREVIEW_GAP * 2));
            return Math.min(current_windows.length - 1, index);
        }

        let showing_preview = false;
        let mouse_inside_preview_window = false;

        let hide_preview_timeout;
        let prev_global_mouse_position = { x: 0, y: 0 };
        let preview_mouse_position = { x: 0, y: 0 };
        let current_pid;
        let current_owner;
        let current_windows = [];
        let current_dock_item = { x: 0, y: 0, width: 0 };

        function isHidePreviewDelayActive () {
            return hide_preview_timeout !== undefined;
        }

        function cancelHidePreviewDelay () {
            clearTimeout(hide_preview_timeout);
            hide_preview_timeout = undefined;
        }

        function hidePreviewDelay () {
            if (!hide_preview_timeout && current_pid) {
                DEBUG_LOG('Trigger Hide Delay');
                clearTimeout(hide_preview_timeout);
                hide_preview_timeout = setTimeout(hidePreview, 500);
            }
        }

        function hidePreview () {
            if (current_pid) {
                DEBUG_LOG('Hide Preview');
                cancelHidePreviewDelay();
                win.setVisible(false);
                showing_preview = false;
                current_owner = undefined;
                current_pid = undefined;

                // Fixes weird issue where if we click on the top part of the preview
                // it won't open again because onMouseLeave does not trigger.
                mouse_inside_preview_window = false;
            }
        }

        function showPreview (pid, dockItem, windows) {
            DEBUG_LOG('Show Preview');

            // There could be an in progress hide action, from when we move away
            // from the desktop onto the dock itself, so cancel that to prevent out window 
            cancelHidePreviewDelay();

            showing_preview = true;

            // Track everything about the dock, pid, and windows
            current_dock_item = dockItem;
            current_pid = pid;
            current_windows = windows;

            let content_width = (current_windows.length * (PREVIEW_WIDTH + PREVIEW_GAP * 2));
            let win_x = current_dock_item.x - (content_width + WINDOW_MARGIN * 2) / 2 + current_dock_item.width / 2;
            let win_y = current_dock_item.y - MARGIN_FROM_DOCK - (PREVIEW_HEIGHT + PREVIEW_GAP * 2) - WINDOW_MARGIN * 2;
            let win_w = content_width + WINDOW_MARGIN * 2;
            let win_h = (PREVIEW_HEIGHT + PREVIEW_GAP * 2) + WINDOW_MARGIN * 2; 

            win.setVisible(true);
            win.setBounds({ x: win_x , y: win_y, width: win_w, height: win_h });

            contentview.schedulePaint();
        }

        contentview.onMouseEnter = (self) => {
            DEBUG_LOG('Preview Mouse Enter');
            // There could be an instance where we moved away from the dock,
            // and then moved the mouse into the preview. If that's the case
            // we need to stop any existing hide in progress. 
            // When we move out of the preview window, the hide delay will trigger again.
            cancelHidePreviewDelay();
            mouse_inside_preview_window = true;
        };

        contentview.onMouseMove = (self, evt) => {
            preview_mouse_position = { x: evt.positionInView.x, y: evt.positionInView.y };    
            contentview.schedulePaint();
        }

        contentview.onMouseLeave = (self) => {
            DEBUG_LOG('Preview Mouse Leave');
            mouse_inside_preview_window = false;
        };

        axlib.AXObserveLocalMouseDown(() => {
            DEBUG_LOG('Local Mouse Click');
            // We're using this method instead of "onMouseDown" because it will trigger a click
            // despite this application not being in focus. This means we can look at the preview
            // of our application without losing focus on the current application we're working with.
            if (mouse_inside_preview_window) {
                // We have to check for mouse inside window, because clicking on the system menu
                // bar item also triggers this event.
                DEBUG_LOG('Preview Mouse Down');
                let x = preview_mouse_position.x;
                let index = MouseToPreviewIndex(x);
                let window_id = current_windows[index].id;
                axlib.AXRaiseAppWindow(current_pid, window_id, index);
                hidePreview();
            }
            
        });

        axlib.AXObserveGlobalMouseDown(() => {
            DEBUG_LOG('Global Mouse Click');
            // There's a small possibility that the global event will trigger incorrectly.
            // This can typically happen on startup of the application for the very first click.
            if (!mouse_inside_preview_window) {
                DEBUG_LOG('Outside Preview Mouse Down');
                 // We want to hide the preview if you click anywhere outside of the preview.
                // The only exception is if we're clicking on the dock, otherwise it will flicker
                // the preview and show it again.
                let mouse_position = axlib.AXGetMousePosition();
                let el = axlib.AXGetElementAtPosition(mouse_position.x, mouse_position.y);

                if (el && el.type === 'AXApplicationDockItem') {
                    return;
                }

                hidePreview();
            }
           
        });

        contentview.onDraw = (self, painter) => {
            let theme = config.get().theme.preview;
            if (current_windows && current_windows.length > 0) {
                let content_width = (current_windows.length * (PREVIEW_WIDTH + PREVIEW_GAP * 2));

                painter.setFillColor(theme['background:color']);
                painter.beginPath();
                painter.rect({ x: WINDOW_MARGIN, y: WINDOW_MARGIN, width: content_width, height: (PREVIEW_HEIGHT + PREVIEW_GAP * 2) });
                painter.fill();

                let hover_index = MouseToPreviewIndex(preview_mouse_position.x);
                painter.setFillColor(theme['background:color:hover']);
                painter.beginPath();
                painter.rect({ x: WINDOW_MARGIN + (PREVIEW_WIDTH + PREVIEW_GAP * 2) * hover_index, y: WINDOW_MARGIN, width: PREVIEW_WIDTH + PREVIEW_GAP * 2, height: (PREVIEW_HEIGHT + PREVIEW_GAP * 2) });
                painter.fill();

                painter.setStrokeColor(theme['border:color']);
                painter.setLineWidth(2);
                painter.beginPath();
                painter.rect({ x: WINDOW_MARGIN, y: WINDOW_MARGIN, width: content_width - 2, height: (PREVIEW_HEIGHT + PREVIEW_GAP * 2) - 2 });
                painter.stroke();

                current_windows.forEach((w, i) => {
                    let x = WINDOW_MARGIN + PREVIEW_GAP + i * PREVIEW_WIDTH + i * PREVIEW_GAP * 2;
                    let y = WINDOW_MARGIN + PREVIEW_GAP;
                    let width = PREVIEW_WIDTH;

                    painter.drawText(w.name, { 
                        x, y, width, height: font.getSize() / 2 
                    }, {
                        font, color: theme['caption:color'], wrap: false
                    });

                    painter.drawImage(w.img.data, { x, y: y + CAPTION_HEIGHT, width, height: THUMBNAIL_HEIGHT });
                });
            }
        };

        win.center();
        win.activate();

        // Hide app after starting it. 
        // Can't seem to work around this.
        setTimeout(() => {
            win.setVisible(false);
        }, 100);


        // TODO: Is the CPU usage for this too high?
        axlib.AXObserveGlobalMouseMove(() => {
            // If the mouse is inside the preview window,
            // then don't bother with any of these checks.
            // When we leave the window this will work again.
            if (mouse_inside_preview_window) {
                return;
            }

            let mouse_position = axlib.AXGetMousePosition();

            if (mouse_position.x === prev_global_mouse_position.x && mouse_position.y === prev_global_mouse_position.y) {
                return;
            }

            prev_global_mouse_position = mouse_position;

            let el = axlib.AXGetElementAtPosition(mouse_position.x, mouse_position.y);

            if (el && el.type === 'AXApplicationDockItem') {
                // Some apps have different titles when on the dock compared to the processes.
                // Not sure if there's another way of solving this, but it does the trick.
                let owner = config.get().aliases[el.title] || el.title;

                // If we're hovering over the same item, don't bother doing anything.
                // This will prevent unnecessary low-level calls.
                if (current_owner === owner) {
                    return;
                }

                DEBUG_LOG('Hovering Dock App: ' + owner);
                current_owner = owner;

                if (el.running) {
                    DEBUG_LOG('App is running: ' + el.running);

                    // Find all of the windows currently active.
                    let windows = axlib.AXGetWindowList();

                    // Grab matching windows and if there's any to show
                    // we'll pass them into the preview. Note that the Mac API only returns
                    // the first 30 characters for owners, so we have to substring when comparing.
                    let found = windows.filter(w => {
                        return (
                            w.owner.substring(0, 30) === owner.substring(0, 30) ||
                            w.owner.includes('.app') && el.title + '.app' === w.owner // Bug with Mac, on reboot, owner uses the .app filename rather than the proper title
                        );
                    }).filter(w => {
                        // This checks to see if the window is a real window by seeing if the Accessibility API sees it.
                        // Some apps (eg. XQuartz) may have windows with "onscreen" set to true, but are invisible to Accessibility.
                        // Such apps need to be updated to implement the proper accessibility support. They cannot be raised without this.
                        return axlib.AXCheckIfStandardWindow(w.pid, w.wid);
                    });

                    if (found.length > 0) {
                        DEBUG_LOG('Found windows: ' + found.length);
                        let windows = found.map(w => {
                            // TODO: Window fetching here is slow. 50ms approx per large window.
                            // This is purely to do with the Mac window capture function.
                            // We will need to implement a caching and observation mechanism.
                            // Cache inactive windows, fetch preview for active window.
                            let win_img = axlib.AXGetWindowPreview(w.wid);
                            
                            // May not have permissions, so just avoid failing for the time being.
                            if (win_img) {
                                // The window preview image we get from native is a raw image.
                                // Yue unfortunately only accepts image files, so we have to convert
                                // the raw image into an image file format and pass that buffer in.
                                // There's probably a far more efficient way of doing this.
                                let img = gui.Image.createFromBuffer(bmp_img_encoder(win_img), 1);

                                return {
                                    img: {
                                        width: win_img.width,
                                        height: win_img.height,
                                        data: img
                                    },
                                    id: w.wid,
                                    name: w.name || w.owner
                                };
                            }

                            return null;
                        }).filter(w => w !== null);

                        if (windows.length > 0) {
                            DEBUG_LOG('Preview Windows: ' + windows.length);
                            
                            showPreview(found[0].pid, {
                                x: el.position.x,
                                y: el.position.y,
                                width: el.size.width
                            }, windows);
                        }
                    } else {
                        // No windows to show, hide instantly.
                        hidePreview();
                    }
                } else {
                    // We're hovering over a dock item, but it's not running.
                    // So we hide the preview instantly in this case.
                    hidePreview();
                }
            } else {
                // If we're not hovering over any dock item, 
                // and the preview is currently showing, then hide it with a delay.
                // We also ensure that we're not constantly postpong it by checking if
                // there is an existing hide command in progress.
                if (showing_preview && !isHidePreviewDelayActive()) {
                    hidePreviewDelay();
                }
            }
        });
    }
}
