let gui = require('gui');
let { exec } = require('child_process');
let config = require('./config');
let login = require('./login');


module.exports = {
    init () {
        let tray = gui.Tray.createWithTitle('DWP');

        let tray_menu_items = [
            gui.MenuItem.create({
                label: 'Version ' + require('../package.json').version,
                enabled: false
            }),
            gui.MenuItem.create({
                type: 'separator'
            }),
            gui.MenuItem.create({
                label: 'Config...',
                onClick: () => exec('open -t ' + config.location())
            }),
            gui.MenuItem.create({
                type: 'separator'
            }),
            gui.MenuItem.create({
                type: 'checkbox',
                label: 'Run on Login',
                checked: login.status(),
                onClick: () => login.toggle()
            }),
            gui.MenuItem.create({
                type: 'separator'
            }),
            gui.MenuItem.create({
                label: 'About',
                onClick: () => exec('open https://github.com/PepsRyuu/dock-window-preview')
            }),
            gui.MenuItem.create({
                label: 'Quit Dock Window Preview',
                onClick: () => process.exit(0)
            })
        ];
        
        let tray_menu = gui.Menu.create(tray_menu_items);
        tray.setMenu(tray_menu);

        // Fixes garbage collection issue where when running in yode the tray will disappear after a few seconds.
        // https://github.com/yue/yue/commit/acd5be3df12ac90383a05bc523b3df72e34230e0
        global.tray = tray;
    }
}
