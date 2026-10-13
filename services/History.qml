pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Launcher memory, kept as plain JSON under .state/:
//   web-history.json      websites you opened (only things that look like a
//                         site/URL, e.g. "youtube.com" — not plain searches)
//   command-history.json  shell commands run from the "$" mode, newest first
Singleton {
    id: root

    property var web: []
    property var commands: []
    readonly property int limit: 300

    function isSite(s) {
        s = String(s).trim();
        return /^https?:\/\//i.test(s) || /^[^\s\/]+\.[a-z]{2,}(\/\S*)?$/i.test(s);
    }

    function addWeb(s) {
        s = String(s).trim();
        if (!isSite(s))
            return;
        web = [s].concat(web.filter(x => x !== s)).slice(0, limit);
        webFile.setText(JSON.stringify(web, null, 1));
    }
    function addCommand(s) {
        s = String(s).trim();
        if (s === "")
            return;
        commands = [s].concat(commands.filter(x => x !== s)).slice(0, limit);
        cmdFile.setText(JSON.stringify(commands, null, 1));
    }
    function removeWeb(s) {
        web = web.filter(x => x !== s);
        webFile.setText(JSON.stringify(web, null, 1));
    }
    function removeCommand(s) {
        commands = commands.filter(x => x !== s);
        cmdFile.setText(JSON.stringify(commands, null, 1));
    }

    FileView {
        id: webFile
        path: Config.stateDir + "/web-history.json"
        printErrors: false
        onLoaded: {
            try {
                root.web = JSON.parse(text());
            } catch (e) {}
        }
    }
    FileView {
        id: cmdFile
        path: Config.stateDir + "/command-history.json"
        printErrors: false
        onLoaded: {
            try {
                root.commands = JSON.parse(text());
            } catch (e) {}
        }
    }
}
