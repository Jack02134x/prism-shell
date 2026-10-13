pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which popup panel is open. Opening one closes the others.
Singleton {
    id: root

    property bool launcher: false
    property string launcherQuery: ""
    property bool dashboard: false
    property int dashboardTab: 0
    property bool sidebar: false
    property bool controls: false
    property bool power: false
    property bool overview: false
    property bool wallpapers: false
    property string wallpaperQuery: ""
    property bool screenshot: false
    property bool cheatsheet: false
    property bool record: false
    property bool edit: false
    property bool switcher: false
    // true while grim/slurp/hyprpicker run: every Prism surface hides instantly
    property bool capturing: false

    readonly property var names: ["launcher", "dashboard", "sidebar", "controls", "power", "overview", "wallpapers", "screenshot", "cheatsheet", "record", "edit", "switcher"]
    readonly property bool anyOpen: launcher || dashboard || sidebar || controls || power || overview || wallpapers || screenshot || cheatsheet || record || edit || switcher

    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor?.name ?? "";
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    function closeAll(except) {
        for (const k of names)
            if (k !== except)
                root[k] = false;
    }

    function toggle(name) {
        const v = !root[name];
        // a plain toggle opens the launcher empty, not with the last prefix (":" ">")
        if (name === "launcher" && v)
            launcherQuery = "";
        closeAll(name);
        root[name] = v;
    }

    function show(name) {
        closeAll(name);
        root[name] = true;
    }

    function openLauncher(query) {
        launcherQuery = query ?? "";
        if (launcher && query !== undefined) {
            // re-trigger the query even if already open
            launcher = false;
        }
        show("launcher");
    }

    function openDashboard(tab) {
        if (tab !== undefined)
            dashboardTab = tab;
        show("dashboard");
    }

    function openWallpapers(query) {
        wallpaperQuery = query ?? "";
        show("wallpapers");
    }
}
