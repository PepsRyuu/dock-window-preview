let gui = require('gui');
let fs = require('fs'); 
let path = require('path');

// Find the config file for dev and prod environments.
let isAsar = __dirname.endsWith('/asar');
let config_path = path.resolve(__dirname, isAsar? '../../../../../config.json' : './config.json'); 
let config = JSON.parse(fs.readFileSync(config_path, 'utf8'));

// Slot in defaults for config
config.aliases = config.aliases || {};

// Hides from the Dock
gui.app.setActivationPolicy('accessory');

// Load Global Debug utilities
require('./lib/debug');

// Test for permissions and don't run the app unless
// the permissions are in place.
require('./lib/permissions').check(() => {
    require('./lib/preview').init(config);
    require('./lib/tray').init();
});

// For development purposes only
if (!process.versions.yode) {
    gui.MessageLoop.run();
    process.exit(0);
}