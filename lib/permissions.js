let gui = require('gui');
let axlib = require('../axlib');

let permissions = getPermissions();

function getPermissions () {
    return {
        accessibility: axlib.AXHasAccessibilityPermission(),
        screen_recording: axlib.AXHasScreenRecordingPermission()
    };
}

function getLabelText () {
    return [
        '',
        'Permissions not enabled.',
        '',
        'Please open "Security & Privacy" settings and provide the following to "Dock Window Preview.app":',
        '',
        `    ${permissions.accessibility? '✓' : '•'} Accessibility`,
        `    ${permissions.screen_recording? '✓' : '•'} Screen Recording`,
        '',
        'Once added, press "Retry" or "Quit" the application.'
    ].join('\n')
}

function ShowMessage (callback) {
    let retrying = false;

    // Create the window
    let win = gui.Window.create({ frame: true });
    win.setTitle('Dock Window Preview');
    win.setAlwaysOnTop(true);
    win.setContentSize({ width: 400, height: 320 });
    win.setResizable(false);
    win.onClose = () => {
        if (!retrying) {
            process.exit(0);
        }
    };
    
    // Set the content view
    let contentview = gui.Container.create();
    contentview.setBackgroundColor('#dddddd')
    win.setContentView(contentview);

    // Add the label explaining the problem
    let label = gui.Label.create(getLabelText());
    contentview.addChildView(label);

    // Open Security and Preferences
    let open_button = gui.Button.create('Open Security & Privacy Settings');
    contentview.addChildView(open_button);
    open_button.onClick = () => require('child_process').exec('open "x-apple.systempreferences:com.apple.preference.security"');
    open_button.setStyle({ 
        marginTop: '20px',
        marginRight: '20px',
        marginBottom: '20px',
        marginLeft: '20px' 
    });

    // Retry Button
    let retry_button = gui.Button.create('Retry');
    contentview.addChildView(retry_button);
    retry_button.onClick = () => {
        clearInterval(interval);
        retrying = true;
        check(callback);
        win.close();
    };
    retry_button.setStyle({ 
        marginRight: '20px',
        marginBottom: '20px',
        marginLeft: '20px' 
    });

    // Quit Button
    let quit_button = gui.Button.create('Quit');
    contentview.addChildView(quit_button);
    quit_button.onClick = () => process.exit(0);
    quit_button.setStyle({ 
        marginRight: '20px',
        marginLeft: '20px' 
    });

    // Display the window
    win.center();
    win.activate();

    // Weird bug with Yue. If I don't have a setInterval
    // in place, CPU skyrockets when showing this window.
    // Probably something to do with message loop checks.
    let interval = setInterval(() => {
        permissions = getPermissions();
        label.setText(getLabelText());
    }, 1000);
}

function check (callback) {
    // Update permissions structure with latest status
    permissions = getPermissions();
    DEBUG_LOG('Permissions: ' + JSON.stringify(permissions));

    // If the permissions are satisfactory, proceed with the app
    // else show the message dialog about the permissions.
    if (permissions.accessibility && permissions.screen_recording) {
        callback();
    } else {
        ShowMessage(callback);
    }
}

module.exports = { check };