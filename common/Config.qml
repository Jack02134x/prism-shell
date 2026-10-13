pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, persisted to ~/.config/quickshell/config.json.
// Edit that file (or the Settings tab in the dashboard) and everything updates live.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string shellDir: Quickshell.shellDir
    readonly property string cacheDir: shellDir + "/.cache"
    readonly property string stateDir: shellDir + "/.state"

    property alias user: adapter.user
    property alias apps: adapter.apps
    property alias bar: adapter.bar
    property alias fx: adapter.fx
    property alias drawers: adapter.drawers
    property alias notifications: adapter.notifications
    property alias wallpaper: adapter.wallpaper
    property alias paths: adapter.paths
    property alias weather: adapter.weather
    property alias lock: adapter.lock
    property alias polkit: adapter.polkit
    property alias battery: adapter.battery
    property alias focus: adapter.focus
    property alias breaks: adapter.breaks
    property alias idle: adapter.idle

    property bool loaded: false

    FileView {
        id: file
        path: root.shellDir + "/config.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.loaded = true
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            property JsonObject user: JsonObject {
                property string name: Quickshell.env("USER") ?? "friend"
                property string avatar: root.home + "/.face"
            }

            property JsonObject apps: JsonObject {
                property string terminal: "kitty"
                property string browser: "firefox"
                property string files: "thunar"
                property string editor: "code"
                property string searchUrl: "https://www.google.com/search?q="
                // folders in the quick-edit menu (qs ipc call edit toggle), opened with `editor <path>`
                property list<string> editFolders: [
                    root.home + "/.config/hypr",
                    root.home + "/.config/quickshell"
                ]
            }

            property JsonObject bar: JsonObject {
                property int height: 42
                property int margin: 8
                property int workspaces: 10
                property bool showStats: true
                property bool showTitle: true
                property bool workspaceIcons: true
                // special workspaces always shown in the bar and overview
                property list<string> specials: ["minimize", "magic"]
                property real opacity: 0.86
            }

            property JsonObject fx: JsonObject {
                // slow ambient motion (gradient borders, aurora, orb)
                property bool ambient: true
                // keep ambient motion while on battery
                property bool ambientOnBattery: true
                property bool corners: true
                property bool hotCorner: true
                property int cornerRadius: 18
            }

            property JsonObject drawers: JsonObject {
                // pull-out panels on the screen edges
                property bool left: true
                property bool right: true
                // open when the pointer rests on the edge (otherwise drag/click)
                property bool hoverOpen: false
            }

            property JsonObject notifications: JsonObject {
                // run the notification daemon (stop swaync to use it)
                property bool server: true
                property int timeout: 6000
            }

            property JsonObject wallpaper: JsonObject {
                property string dir: root.home + "/Pictures/Wallpapers"
                property string videoDir: root.home + "/Videos/Wallpapers"
                property string transition: "random"
                property int matugenIndex: 0
                // matugen scheme mode for the whole system: dark | light
                property string mode: "dark"
                // matugen scheme: "" (default tonal-spot) | scheme-vibrant | scheme-expressive | scheme-fidelity | scheme-content
                property string scheme: ""
                // optional: write the wallpaper's name to this file ("" = off)
                property string nameFile: ""
                // a copy of the current wallpaper (handy for hyprlock etc.)
                property string copyTo: root.stateDir + "/wallpaper"
            }

            property JsonObject paths: JsonObject {
                // written by matugen from matugen/prism-colors.lua (see install.sh)
                property string matugenColors: root.stateDir + "/colors.lua"
                // keybind files shown in the cheatsheet
                property string binds: root.home + "/.config/hypr/hyprland.lua"
                property string extraBinds: ""
                // optional hypr-screentime tracker folder (Screen time tab)
                property string screentime: ""
                property string screenshots: root.home + "/Pictures/Screenshots"
                property string recordings: root.home + "/Videos/Recordings"
            }

            property JsonObject weather: JsonObject {
                // empty = auto-detect from IP
                property string location: ""
                property bool fahrenheit: false
            }

            property JsonObject lock: JsonObject {
                // use the Quickshell lock screen for `qs ipc call lock lock`
                property bool enabled: false
                property string pamConfig: "hyprlock"
            }

            property JsonObject polkit: JsonObject {
                // replace hyprpolkitagent (stop it first)
                property bool enabled: false
            }

            property JsonObject focus: JsonObject {
                property int workMinutes: 25
                property int breakMinutes: 5
                property int longBreakMinutes: 15
                // study noise during focus: off | brown | pink | white
                property string noise: "brown"
                // do-not-disturb during focus
                property bool silence: true
            }

            property JsonObject breaks: JsonObject {
                // 20-20-20: after N minutes of non-idle use, look away for 20 s
                property bool eyeReminder: true
                property int everyMinutes: 20
            }

            property JsonObject idle: JsonObject {
                // Prism's own idle manager (instead of hypridle). Seconds; 0 = never.
                property bool enabled: true
                property int dimAfter: 180
                property int dimTo: 10 // backlight %, while dimmed
                property int lockAfter: 240
                property int screenOffAfter: 300
                property int suspendAfter: 0
                // media playing (any MPRIS player: music, videos) counts as being in use
                property bool mediaKeepsAwake: true
                // lock the screen before the system suspends
                property bool lockBeforeSleep: true
            }

            property JsonObject battery: JsonObject {
                property int warn: 20
                property int critical: 8
            }
        }
    }
}
