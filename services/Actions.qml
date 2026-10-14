pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Command palette entries (launcher "/" prefix, and mixed into normal search).
Singleton {
    id: root

    function sh(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
    function term(cmd) {
        Quickshell.execDetached([Config.apps.terminal, "-e", "sh", "-c", cmd]);
    }

    readonly property var list: [
        { name: "Dashboard", desc: "Overview, media, weather, stats", icon: "view_dashboard", kw: "home control center", run: () => Panels.openDashboard(0) },
        { name: "Now Playing", desc: "Big media view with visualizer", icon: "music", kw: "music player spotify", run: () => Panels.openDashboard(1) },
        { name: "System Monitor", desc: "CPU, memory, GPU, network", icon: "chart_areaspline", kw: "cpu ram gpu stats htop", run: () => Panels.openDashboard(2) },
        { name: "Screen Time", desc: "Today's usage from your tracker", icon: "timer_outline", kw: "usage hours apps", run: () => Panels.openDashboard(3) },
        { name: "Wi-Fi & Bluetooth", desc: "Networks and devices", icon: "wifi", kw: "network bluetooth connect", run: () => Panels.openDashboard(4) },
        { name: "Audio Mixer", desc: "Outputs, inputs, per-app volume", icon: "tune_variant", kw: "volume sound mixer speaker", run: () => Panels.openDashboard(5) },
        { name: "Shell Settings", desc: "Toggle Prism features", icon: "cog", kw: "config preferences prism", run: () => Panels.openDashboard(6) },
        { name: "Notification Center", desc: "Right drawer: history, calendar, DND", icon: "bell", kw: "notifications dnd sidebar", run: () => Panels.show("sidebar") },
        { name: "Control Drawer", desc: "Left drawer: sliders and toggles", icon: "dock_left", kw: "quick settings controls", run: () => Panels.show("controls") },
        { name: "Workspace Overview", desc: "All workspaces with live previews", icon: "view_grid", kw: "expose windows", run: () => Panels.show("overview") },
        { name: "Wallpapers", desc: "Pick a wallpaper (recolours everything)", icon: "palette", kw: "wallpaper background theme matugen", run: () => Panels.openWallpapers("") },
        { name: "Random Wallpaper", desc: "Surprise me", icon: "dice_multiple", kw: "wallpaper shuffle", run: () => Wallpapers.random() },
        { name: "Screenshot", desc: "Region, window or screen", icon: "monitor_screenshot", kw: "capture grim print", run: () => Panels.show("screenshot") },
        { name: "Record Screen", desc: "Toggle region recording (wf-recorder)", icon: "record_rec", kw: "video capture", run: () => Toggles.toggleRecording() },
        { name: "Color Picker", desc: "Pick a colour and copy its hex", icon: "eyedropper", kw: "hyprpicker colour", run: () => Shot.pickColor() },
        { name: "Clipboard History", desc: "Search cliphist", icon: "clipboard_text_outline", kw: "paste copy", run: () => Panels.openLauncher(">") },
        { name: "Emoji Picker", desc: "Search and copy emoji", icon: "emoticon_happy_outline", kw: "emoji smiley", run: () => Panels.openLauncher(":") },
        { name: "Keybind Cheatsheet", desc: "Every Hyprland bind", icon: "keyboard", kw: "shortcuts keys help", run: () => Panels.show("cheatsheet") },
        { name: "Clock", desc: "Floating clock: timer, stopwatch, alarms", icon: "alarm", kw: "timer stopwatch alarm countdown clock", run: () => Chrono.toggle() },
        { name: "Focus Timer", desc: "Pomodoro: " + Config.focus.workMinutes + " min focus with " + Config.focus.noise + " noise", icon: "timer_outline", kw: "pomodoro study focus", run: () => Focus.toggle() },
        { name: "Window Switcher", desc: "All windows with live previews", icon: "dock_window", kw: "alt tab switch windows", run: () => Panels.show("switcher") },
        { name: "Light / Dark Theme", desc: "Switch the whole system's matugen scheme", icon: "theme_light_dark", kw: "theme light dark mode", run: () => Wallpapers.toggleMode() },
        { name: "EasyEffects", desc: "Start in background / quit completely", icon: "tune_variant", kw: "audio equalizer effects easyeffects", run: () => Toggles.toggleEasyEffects() },
        { name: "Caffeine", desc: "Keep the screen awake", icon: "coffee", kw: "always on idle inhibit", run: () => Toggles.toggleCaffeine() },
        { name: "Do Not Disturb", desc: "Silence notification popups", icon: "bell_sleep", kw: "dnd quiet", run: () => { Notifs.dnd = !Notifs.dnd; } },
        { name: "Study Noise", desc: "Cycle brown / pink / white noise", icon: "waves", kw: "focus noise music brown", run: () => Toggles.cycleNoise() },
        { name: "Game Mode", desc: "Strip animations, blur, gaps", icon: "gamepad_variant", kw: "performance fps", run: () => Toggles.toggleGameMode() },
        { name: "Warm Screen", desc: "Tint the screen warm for the night", icon: "weather_night", kw: "night light blue", run: () => Toggles.toggleWarm() },
        { name: "GLava", desc: "Toggle the desktop visualizer", icon: "equalizer", kw: "visualizer audio", run: () => Toggles.toggleGlava() },
        { name: "Power Profile", desc: "Cycle saver / balanced / performance", icon: "speedometer", kw: "battery performance", run: () => Power.cycleProfile() },
        { name: "Fix Monitors", desc: "Power-cycle every display (DPMS off / on)", icon: "monitor", kw: "dpms hdmi display", run: () => root.sh("hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'; sleep 1; hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'") },
        { name: "Copy Wallpaper Name", desc: "Current wallpaper to clipboard", icon: "content_copy", kw: "wallpaper name", run: () => { Quickshell.execDetached(["wl-copy", Utils.stem(Theme.wallpaper)]); Notifs.local("Wallpaper", Utils.stem(Theme.wallpaper), "palette"); } },
        { name: "Quick Edit", desc: "Open a favourite folder in your editor", icon: "code_braces", kw: "code edit folders projects", run: () => Panels.show("edit") },
        { name: "Edit Hyprland Config", desc: "~/.config/hypr", icon: "code_braces", kw: "hypr config", run: () => Quickshell.execDetached([Config.apps.editor, Config.home + "/.config/hypr"]) },
        { name: "Edit Shell Config", desc: "~/.config/quickshell", icon: "code_braces", kw: "quickshell prism", run: () => Quickshell.execDetached([Config.apps.editor, Config.shellDir]) },
        { name: "Scripts", desc: "~/.scripts", icon: "script_text_outline", kw: "scripts", run: () => Quickshell.execDetached([Config.apps.editor, Config.home + "/.scripts"]) },
        { name: "Projects", desc: "~/Projects", icon: "folder_star", kw: "code", run: () => Quickshell.execDetached([Config.apps.editor, Config.home + "/Projects"]) },
        { name: "Bluetooth TUI", desc: "bluetuith", icon: "bluetooth", kw: "bluetooth", run: () => root.term("bluetuith") },
        { name: "Network TUI", desc: "nmtui", icon: "lan", kw: "wifi network", run: () => root.term("nmtui") },
        { name: "Screen Time App", desc: "Open the full tracker GUI", icon: "chart_bar", kw: "usage", run: () => ScreenTime.openGui() },
        { name: "Find My Phone", desc: "Ring " + (Phone.name || "phone") + " via KDE Connect", icon: "cellphone_sound", kw: "kdeconnect ring", run: () => Phone.ring() },
        { name: "Reload Shell", desc: "Restart Quickshell config", icon: "refresh", kw: "restart quickshell", run: () => Quickshell.reload(true) },
        { name: "Lock", desc: "Lock the session", icon: "lock", kw: "lock screen", run: () => Session.lock() },
        { name: "Suspend", desc: "Sleep", icon: "power_sleep", kw: "sleep", run: () => Session.suspend() },
        { name: "Log Out", desc: "Exit Hyprland", icon: "logout", kw: "exit logout", run: () => Panels.show("power") },
        { name: "Reboot", desc: "Restart the computer", icon: "restart", kw: "restart", run: () => Panels.show("power") },
        { name: "Shut Down", desc: "Power off", icon: "power", kw: "poweroff shutdown", run: () => Panels.show("power") }
    ]
}
