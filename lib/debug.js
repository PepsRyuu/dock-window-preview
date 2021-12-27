// Debug logging capabilities
let DEBUG = process.argv.indexOf('--debug') > -1;

function DEBUG_LOG(msg) {
    if (DEBUG) { 
        console.log('[DEBUG] ' + Date.now() + ' ' + msg);
    }
}

global.DEBUG = DEBUG;
global.DEBUG_LOG = DEBUG_LOG;