//@ pragma UseQApplication
//@ pragma IconTheme breeze-dark

// Prism — a Quickshell shell for Hyprland.
// Colours come live from matugen (template: matugen/prism-colors.lua);
// settings live in ./config.json; see README.md for IPC calls and keybinds.

import QtQuick
import Quickshell
import qs.common
import qs.services
import qs.widgets
import qs.modules.bar
import qs.modules.cheatsheet
import qs.modules.corners
import qs.modules.dashboard
import qs.modules.drawers
import qs.modules.edit
import qs.modules.launcher
import qs.modules.lock
import qs.modules.notifications
import qs.modules.overview
import qs.modules.polkit
import qs.modules.power
import qs.modules.screenshot
import qs.modules.switcher
import qs.modules.wallpaper

ShellRoot {
    // per-monitor layers
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Variants {
        model: Quickshell.screens
        Drawers {}
    }
    Variants {
        model: Quickshell.screens
        Corners {}
    }

    // popups (shown on the focused monitor), built only while open (+20 s)
    // notifications pop up in the bar's island (no separate toasts)
    LazyPanel { want: Panels.launcher; Launcher {} }
    LazyPanel { want: Panels.dashboard; Dashboard {} }
    LazyPanel { want: Panels.overview; Overview {} }
    LazyPanel { want: Panels.wallpapers; WallpaperPicker {} }
    LazyPanel { want: Panels.screenshot; ScreenshotMenu {} }
    LazyPanel { want: Panels.record; RecordMenu {} }
    LazyPanel { want: Panels.cheatsheet; Cheatsheet {} }
    LazyPanel { want: Panels.edit; QuickEdit {} }
    LazyPanel { want: Panels.switcher; Switcher {} }
    LazyPanel { want: Panels.power; PowerMenu {} }
    Lock {}

    LazyLoader {
        active: Config.polkit.enabled
        PolkitDialog {}
    }

    Ipc {}

    // start services that nothing on screen touches right away
    Component.onCompleted: {
        Weather.ready;
        ScreenTime.available;
        Phone.available;
        Keybinds.sections;
        Emojis.all;
        Breaks.enabled;
        Focus.active;
        Idle.active;
    }
}
