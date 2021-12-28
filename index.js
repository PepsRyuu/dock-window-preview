let gui = require('gui');
let fs = require('fs'); 
let path = require('path');

// Hides from the Dock
gui.app.setActivationPolicy('accessory');

// Load Global Debug utilities
require('./lib/debug');

// Manage config loader and watcher
require('./lib/config').init();

// Test for permissions and don't run the app unless
// the permissions are in place.
require('./lib/permissions').check(() => {
    require('./lib/preview').init();
    require('./lib/tray').init();
});

// For development purposes only
if (!process.versions.yode) {
    gui.MessageLoop.run();
    process.exit(0);
}