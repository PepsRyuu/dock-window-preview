let fs = require('fs');
let gui = require('gui');
let path = require('path');
let chokidar = require('chokidar');
let default_config = require('../config.json');

let config_path_dir = path.resolve(process.env.HOME, './.dock-window-preview');
let config_path_file = path.resolve(config_path_dir, './config.json');
let config = {};

function deep_merge (...sources) {
    let obj = {};

    for (let i = 0; i < sources.length; i++) {
        for (let prop in sources[i]) {
            if (typeof sources[i][prop] === 'object' && !Array.isArray(sources[i][prop])) {
                obj[prop] = obj[prop] || {};
                obj[prop] = deep_merge(obj[prop], sources[i][prop]);
            } else {
                obj[prop] = sources[i][prop];
            }
        }
    }

    return obj;
}

function load_config () {
    if (!fs.existsSync(config_path_dir)) {
        DEBUG_LOG('Creating config directory.');
        fs.mkdirSync(config_path_dir);
    }

    if (!fs.existsSync(config_path_file)) {
        DEBUG_LOG('Creating config file.');
        fs.writeFileSync(config_path_file, JSON.stringify(default_config, null, 4));
    }

    let custom_config = {};
    
    try {
        custom_config = JSON.parse(fs.readFileSync(config_path_file, 'utf8'));
    } catch (e) {
        DEBUG_LOG('Invalid config file.');
        let win = gui.Window.create({ frame: true });
        win.setTitle('Dock Window Preview');
        win.setAlwaysOnTop(true);
        win.setContentSize({ width: 300, height: 100 });
        win.setResizable(false);

        let contentview = gui.Container.create();
        contentview.setBackgroundColor('#dddddd')
        win.setContentView(contentview);

        let label = gui.Label.create('Failed to parse config.');
        label.setStyle({ marginTop: '20px' });
        contentview.addChildView(label);

        let btn = gui.Button.create('OK');
        btn.onClick = () => win.close();
        btn.setStyle({ marginTop: '20px', marginLeft: '20px', marginRight: '20px' });
        contentview.addChildView(btn);

        win.center();
        win.activate();
    }
    
    config = deep_merge(default_config, custom_config);
    DEBUG_LOG('Config: ' +JSON.stringify(config));
}

function onChange (e) {
    DEBUG_LOG('Config file changed.');
    load_config();
}

module.exports = {
    init () {
        load_config();
        let watcher = chokidar.watch(config_path_file, { ignoreInitial: true });
        watcher.on('add', onChange);
        watcher.on('change', onChange);
    },

    location () {
        return config_path_file;
    },

    get () {
        return config;
    }
}