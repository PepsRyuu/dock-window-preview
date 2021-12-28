let fs = require('fs');
let path = require('path');
let pkgJson = require('../package.json');

let launch_file = path.resolve(process.env.HOME + '/Library/LaunchAgents/' + pkgJson.build.appId + '.plist');

let metadata = `
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
        <key>KeepAlive</key>
	        <dict>
		        <key>Crashed</key>
		        <true/>
		        <key>SuccessfulExit</key>
		        <false/>
	    </dict>
		<key>Label</key>
		<string>${pkgJson.build.appId.id}</string>
		<key>Program</key>
		<string>${process.execPath}</string>
		<key>RunAtLoad</key>
		<true/>
	</dict>
</plist>
`.trim();

module.exports = {
    status () {
        return fs.existsSync(launch_file);
    },

    toggle () {
        if (global.DEBUG) {
            DEBUG_LOG('Cannot use login features in development.');
            return;
        }

        if (fs.existsSync(launch_file)) {
            fs.unlinkSync(launch_file);
        } else {
            fs.writeFileSync(launch_file, metadata);
        }
    }
}