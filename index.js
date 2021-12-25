let gui = require('gui');
let axlib = require('./axlib');
let PNG = require("pngjs").PNG;

let win = gui.Window.create({ frame: false, transparent: true });
win.setAlwaysOnTop(true);
win.setContentSize({ width: 1, height: 1 });
win.onClose = () => gui.MessageLoop.quit();

let contentview = gui.Container.create();
contentview.setMouseDownCanMoveWindow(false);
win.setContentView(contentview);

// Some apps have different titles when on the dock compared to the processes.
// Not sure if there's another way of solving this, but it does the trick.
// TODO: Make this a separate config file.
let app_aliases = {
    'Visual Studio Code': 'Code'
};

let prev_mouse_position = { x: 0, y: 0 };
let current_preview_id;
let current_preview_x;
let current_preview_y;
let current_preview_width;
let preview;

contentview.onDraw = (self, painter) => {
    if (preview) {
        let MARGIN_FROM_DOCK = 50;
        let WINDOW_MARGIN = 5;
        let CONTENT_WIDTH = 200;
        let CONTENT_HEIGHT = 200;

        let win_x = current_preview_x - (CONTENT_WIDTH + WINDOW_MARGIN * 2) / 2 + current_preview_width / 2;
        let win_y = current_preview_y - MARGIN_FROM_DOCK - CONTENT_HEIGHT - WINDOW_MARGIN * 2;
        let win_w = CONTENT_WIDTH + WINDOW_MARGIN * 2;
        let win_h = CONTENT_HEIGHT + WINDOW_MARGIN * 2; 
        win.setVisible(true);
        win.setBounds({ x: win_x , y: win_y, width: win_w, height: win_h });
        win.activate();

        let png = new PNG();
        png.width = preview.width;
        png.height = preview.height;
        png.data = preview.data;
        let buffer = PNG.sync.write(png);

        painter.setFillColor('#cc000000');
        painter.beginPath();
        painter.rect({ x: WINDOW_MARGIN, y: WINDOW_MARGIN, width: CONTENT_WIDTH, height: CONTENT_HEIGHT });
        painter.fill();

        painter.setStrokeColor('#ffffff');
        painter.setLineWidth(2);
        painter.beginPath();
        painter.rect({ x: WINDOW_MARGIN, y: WINDOW_MARGIN, width: CONTENT_WIDTH - 2, height: CONTENT_HEIGHT - 2 });
        painter.stroke();

        let img = gui.Image.createFromBuffer(buffer, 1);
        painter.drawImage(img, { 
            x: WINDOW_MARGIN + 20, y: WINDOW_MARGIN + 20, width: CONTENT_WIDTH - 40, height: CONTENT_HEIGHT - 40
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

setInterval(() => {
    let mouse_position = axlib.AXGetMousePosition();
    if (mouse_position.x === prev_mouse_position.x && mouse_position.y === prev_mouse_position.y) {
        return;
    }

    prev_mouse_position = mouse_position;

    let el = axlib.AXGetElementAtPosition(mouse_position.x, mouse_position.y);
    if (el && el.type === 'AXApplicationDockItem' && el.running) {
        let windows = axlib.AXGetWindowList(); 

        // TODO: Support multiple windows
        let name = app_aliases[el.title] || el.title;
        let found = windows.find(w => w.name === name);
        if (found) {
            if (found.window !== current_preview_id) {
                let img = axlib.AXGetWindowPreview(found.window);
                preview = img;
                current_preview_id = found.window;
                current_preview_x = el.position.x;
                current_preview_y = el.position.y;
                current_preview_width = el.size.width;
                contentview.schedulePaint();
            }
        } else {
            win.setVisible(false);
            current_preview_id = undefined;
        }
    } else {
        win.setVisible(false);
        current_preview_id = undefined;
    }
}, 100);

if (!process.versions.yode) {
    gui.MessageLoop.run();
    process.exit(0);
}