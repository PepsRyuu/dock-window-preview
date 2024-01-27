let gui = require('gui');
let axlib = require('../axlib');
let config = require('./config');
let { bmp_img_encoder, Component } = require('./utils');

const DOCK_ON_LEFT = config.get().layout.dock === 'left';
const DOCK_ON_RIGHT = config.get().layout.dock === 'right';
const DOCK_ON_SIDE = DOCK_ON_LEFT || DOCK_ON_RIGHT; 
const MARGIN_FROM_DOCK = DOCK_ON_SIDE? 10 : 50;
const WINDOW_MARGIN = 5;
const PREVIEW_GAP = 20;
const PREVIEW_WIDTH = 200;
const CAPTION_HEIGHT = 14;
const THUMBNAIL_HEIGHT = 160;
const PREVIEW_HEIGHT = THUMBNAIL_HEIGHT + CAPTION_HEIGHT;
const PREVIEW_LAYOUT = config.get().layout.preview || 'fill';
const CAPTION_FONT = gui.Font.create('Arial', 11, 'normal', 'normal');
const CLOSE_BUTTON_FONT = gui.Font.create('Arial', 8, 'normal', 'normal');

const state = {
    showing_preview: false,
    mouse_inside_preview_window: false,
    hide_preview_timeout: undefined,
    prev_global_mouse_position: { x: 0, y: 0 },
    preview_hover_index: -1,
    preview_close_hover_index: -1,
    current_pid: undefined,
    current_owner: undefined,
    current_windows: [],
    current_dock_item: { x: 0, y: 0, width: 0 }
};

class PreviewComponent extends Component {
    onInit() {
        if (DOCK_ON_SIDE) {
            this.view.setStyle({ flexDirection: 'column' });
        } else {
            this.view.setStyle({ flexDirection: 'row' });
        }
    }

    setThumbs(windows) {
        let totalChildren = this.view.childCount();
        for (let i = 0; i < totalChildren; i++) {
            this.view.removeChildView(this.view.childAt(0));
        }

        for (let i = 0; i < windows.length; i++) {
            this.view.addChildView(new ThumbComponent(i).view);
        }

        this.view.schedulePaint();
    }

    onDraw(self, painter, bounds, theme) {
        painter.setStrokeColor(theme.preview['border:color']);
        painter.setLineWidth(2);
        painter.beginPath();
        painter.rect({ x: WINDOW_MARGIN, y: WINDOW_MARGIN, width: bounds.width - WINDOW_MARGIN * 2, height: bounds.height - WINDOW_MARGIN * 2 });
        painter.stroke();
    }
}

class ThumbComponent extends Component {
    onInit(index) {
        this.index = index;

        this.view.onMouseEnter = () => {
            state.preview_hover_index = index;
            this.view.getParent().schedulePaint();
        };

        this.view.setStyle({ 
            flex: 1, 
            ...(DOCK_ON_SIDE? ({
                marginTop: index === 0? WINDOW_MARGIN : 0,
                marginBottom: index === state.current_windows.length - 1? WINDOW_MARGIN : 0,
                marginLeft: WINDOW_MARGIN,
                marginRight: WINDOW_MARGIN
            }) : ({
                marginLeft: index === 0? WINDOW_MARGIN : 0,
                marginRight: index === state.current_windows.length - 1? WINDOW_MARGIN : 0,
                marginTop: WINDOW_MARGIN,
                marginBottom: WINDOW_MARGIN
            }))
        });

        this.view.addChildView(new CloseButtonComponent(index).view);
    }

    onDraw(self, painter, bounds, theme) {
        painter.setFillColor(theme.preview[`background:color${state.preview_hover_index === this.index? ':hover': ''}`]);
        painter.beginPath();
        painter.rect({ x: 0, y: 0, width: bounds.width, height: bounds.height });
        painter.fill();

        let w = state.current_windows[this.index];
        painter.drawText(w.name, { x: PREVIEW_GAP, y: PREVIEW_GAP, width: (bounds.width - 16) - PREVIEW_GAP * 2, height: CAPTION_FONT.getSize() / 2 }, {
            font: CAPTION_FONT, 
            color: theme.preview['caption:color'], 
            wrap: false,
            ellipsis: true
        });

        let imgBoundWidth = bounds.width - PREVIEW_GAP * 2;
        let imgBoundHeight = THUMBNAIL_HEIGHT;
        let imgBoundX = PREVIEW_GAP;
        let imgBoundY = PREVIEW_GAP + CAPTION_HEIGHT;

        if (PREVIEW_LAYOUT === 'fill') {
            painter.drawImage(w.img.data, { 
                x: imgBoundX, 
                y: imgBoundY,
                width: imgBoundWidth,
                height: imgBoundHeight
            });
        }

        if (PREVIEW_LAYOUT === 'fit') {
            let scaleRatio = w.img.width > w.img.height? imgBoundWidth / w.img.width : imgBoundHeight / w.img.height;
            let scaledWidth = w.img.width * scaleRatio;
            let scaledHeight = w.img.height * scaleRatio;

            // Our target boundary is typically 200 wide and 160 high, so there's a possibility, typically when
            // a window is closer to a square shape, where the height might not be scaled down enough.
            if (scaledHeight > imgBoundHeight) {
                scaleRatio = w.img.width > w.img.height? imgBoundHeight / w.img.width : imgBoundHeight / w.img.height;
                scaledWidth = w.img.width * scaleRatio;
                scaledHeight = w.img.height * scaleRatio;
            }

            painter.drawImage(w.img.data, { 
                x: imgBoundX + ((imgBoundWidth - scaledWidth) / 2), 
                y: imgBoundY + ((imgBoundHeight - scaledHeight) / 2), 
                width: w.img.width * scaleRatio,
                height: w.img.height * scaleRatio
            });
        }   
    }
}

class CloseButtonComponent extends Component {
    onInit(index) {
        this.index = index;
        this.view.onMouseEnter = () => {
            state.preview_close_hover_index = index;
            this.view.schedulePaint();
        };

        this.view.onMouseLeave = () => {
            state.preview_close_hover_index = -1;
            this.view.schedulePaint();
        };

        this.view.setStyle({ position: 'absolute', top: 12, right: 20, width: 14, height: 14 });
    }

    onDraw(self, painter, bounds, theme) {
        if (state.preview_close_hover_index === this.index) {
            painter.setFillColor('#ff5f57');
            painter.beginPath();
            painter.arc({ x: 7, y: 7 }, 6, 0, Math.PI * 2);
            painter.fill();

            painter.setStrokeColor('#e8483f');
            painter.setLineWidth(1);
            painter.beginPath();
            painter.arc({ x: 7, y: 7 }, 6, 0, Math.PI * 2);
            painter.stroke();
        }

        painter.drawText('✕', { x: 4, y: 8, width: bounds.width, height: CLOSE_BUTTON_FONT.getSize() / 2 }, {
            font: CLOSE_BUTTON_FONT, 
            color: state.preview_close_hover_index === this.index ?'#730000' : '#ffffff', 
            wrap: false
        });
    }
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
        let contentview = new PreviewComponent();
        win.setContentView(contentview.view);

        win.getContentView().onMouseEnter = () => {
            DEBUG_LOG('Preview Mouse Enter');
            // There could be an instance where we moved away from the dock,
            // and then moved the mouse into the preview. If that's the case
            // we need to stop any existing hide in progress. 
            // When we move out of the preview window, the hide delay will trigger again.
            cancelHidePreviewDelay();
            state.mouse_inside_preview_window = true;
        };

        win.getContentView().onMouseLeave = () => {
            DEBUG_LOG('Preview Mouse Leave');
            state.mouse_inside_preview_window = false;
        };

        function isHidePreviewDelayActive () {
            return state.hide_preview_timeout !== undefined;
        }

        function cancelHidePreviewDelay () {
            clearTimeout(state.hide_preview_timeout);
            state.hide_preview_timeout = undefined;
        }

        function hidePreviewDelay () {
            if (!state.hide_preview_timeout && state.current_pid) {
                DEBUG_LOG('Trigger Hide Delay');
                clearTimeout(state.hide_preview_timeout);
                state.hide_preview_timeout = setTimeout(hidePreview, 500);
            }
        }

        function hidePreview () {
            if (state.current_pid) {
                DEBUG_LOG('Hide Preview');
                cancelHidePreviewDelay();
                win.setVisible(false);
                state.showing_preview = false;
                state.current_owner = undefined;
                state.current_pid = undefined;
                state.preview_hover_index = -1;
                state.preview_close_hover_index = -1;
                // Fixes weird issue where if we click on the top part of the preview
                // it won't open again because onMouseLeave does not trigger.
                state.mouse_inside_preview_window = false;
            }
        }

        function showPreview (pid, dockItem, windows) {
            DEBUG_LOG('Show Preview');

            // There could be an in progress hide action, from when we move away
            // from the desktop onto the dock itself, so cancel that to prevent out window 
            cancelHidePreviewDelay();

            state.showing_preview = true;

            // Track everything about the dock, pid, and windows
            state.current_dock_item = dockItem;
            state.current_pid = pid;
            state.current_windows = windows;
            state.preview_hover_index = -1;

            let win_x, win_y, win_w, win_h;

            if (DOCK_ON_SIDE) {
                let content_height = (windows.length * (PREVIEW_HEIGHT + PREVIEW_GAP * 2));
                win_y = dockItem.y - (content_height + WINDOW_MARGIN * 2) / 2 + dockItem.width / 2;
                win_h = content_height + WINDOW_MARGIN * 2;
                win_w = (PREVIEW_HEIGHT + PREVIEW_GAP * 2) + WINDOW_MARGIN * 2; 

                if (DOCK_ON_LEFT) {
                    win_x = dockItem.x + dockItem.width + MARGIN_FROM_DOCK;
                }

                if (DOCK_ON_RIGHT) {
                    win_x = dockItem.x - MARGIN_FROM_DOCK - (PREVIEW_WIDTH + PREVIEW_GAP);
                }
            } else {
                let content_width = (windows.length * (PREVIEW_WIDTH + PREVIEW_GAP * 2));
                win_x = dockItem.x - (content_width + WINDOW_MARGIN * 2) / 2 + dockItem.width / 2;
                win_y = dockItem.y - MARGIN_FROM_DOCK - (PREVIEW_HEIGHT + PREVIEW_GAP * 2) - WINDOW_MARGIN * 2;
                win_w = content_width + WINDOW_MARGIN * 2;
                win_h = (PREVIEW_HEIGHT + PREVIEW_GAP * 2) + WINDOW_MARGIN * 2; 
            }
            
            
            win.setVisible(true);
            win.setBounds({ x: win_x , y: win_y, width: win_w, height: win_h });
            contentview.setThumbs(state.current_windows);        
        }

        axlib.AXObserveLocalMouseDown(() => {
            DEBUG_LOG('Local Mouse Click');
            // We're using this method instead of "onMouseDown" because it will trigger a click
            // despite this application not being in focus. This means we can look at the preview
            // of our application without losing focus on the current application we're working with.
            if (state.mouse_inside_preview_window && state.preview_hover_index > -1) {
                // We have to check for mouse inside window, because clicking on the system menu
                // bar item also triggers this event.
                DEBUG_LOG('Preview Mouse Down');

                if (state.preview_close_hover_index > -1) {
                    DEBUG_LOG('Preview Close Mouse Down');

                    let window_id = state.current_windows[state.preview_close_hover_index].id;
                    state.preview_close_hover_index = -1;
                    axlib.AXPerformActionOnWindow(state.current_pid, window_id, axlib.ACTION_CLOSE);

                    let updated_windows = state.current_windows.filter(w => w.id !== window_id);
                    if (updated_windows.length > 0) {
                        showPreview(state.current_pid, state.current_dock_item, updated_windows);
                        return;
                    } 

                    hidePreview();
                    return;
                }

                let window_id = state.current_windows[state.preview_hover_index].id;
                axlib.AXPerformActionOnWindow(state.current_pid, window_id, axlib.ACTION_RAISE);
                hidePreview();
            }
        });

        axlib.AXObserveGlobalMouseDown(() => {
            DEBUG_LOG('Global Mouse Click');
            // There's a small possibility that the global event will trigger incorrectly.
            // This can typically happen on startup of the application for the very first click.
            if (!state.mouse_inside_preview_window) {
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
            if (state.mouse_inside_preview_window) {
                return;
            }

            let mouse_position = axlib.AXGetMousePosition();

            if (mouse_position.x === state.prev_global_mouse_position.x && mouse_position.y === state.prev_global_mouse_position.y) {
                return;
            }

            state.prev_global_mouse_position = mouse_position;

            let el = axlib.AXGetElementAtPosition(mouse_position.x, mouse_position.y);

            if (el && el.type === 'AXApplicationDockItem') {
                // Some apps have different titles when on the dock compared to the processes.
                // Not sure if there's another way of solving this, but it does the trick.
                let owner = config.get().aliases[el.title] || el.title;

                // If we're hovering over the same item, don't bother doing anything.
                // This will prevent unnecessary low-level calls.
                if (state.current_owner === owner) {
                    return;
                }

                DEBUG_LOG('Hovering Dock App: ' + owner);
                state.current_owner = owner;

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
                if (state.showing_preview && !isHidePreviewDelayActive()) {
                    hidePreviewDelay();
                }
            }
        });
    }
}
