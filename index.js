let gui = require('gui');
let fs = require('fs'); 
let path = require('path');

// Asar patching is broken.
// This patch works around the optional opts that's being passed to lstat
// from chokidar. Asar is not aware of this optional parameter.
// To debug issues like this, add "--unpack \"*.{json,node,js}\" to yackage.
if (fs.lstat.toString().indexOf('isAsar') > -1) {
    let lstat = fs.lstat;
    fs.lstat = function (...args) {
        let p = args[0];
        let callback = args.length === 3? args[2]: args[1];
        lstat(p, callback);
    };
}

// Hides from the Dock
gui.app.setActivationPolicy('accessory');

// Load Global Debug utilities
require('./lib/debug');

// Manage config loader and watcher
require('./lib/config').init();

// Test for permissions and don't run the app unless
// the permissions are in place.
require('./lib/permissions').check(() => {
    // TODO: Laggy menu item due to not being activated
    gui.app.setActivationPolicy('prohibited'); // prevents activation of preview window
    require('./lib/preview').init();
    require('./lib/tray').init();
});

// For development purposes only
if (!process.versions.yode) {
    gui.MessageLoop.run();
    process.exit(0);
}