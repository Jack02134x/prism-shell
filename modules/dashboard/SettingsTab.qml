pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets

// Live settings, written straight to ~/.config/quickshell/config.json.
Item {
    id: root

    property bool active: false

    component SettingRow: RowLayout {
        id: r
        property string icon
        property string title
        property string sub
        property bool checked
        property int accentIndex: 0
        signal toggled(bool v)
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            implicitWidth: 34
            implicitHeight: 34
            radius: 11
            color: Theme.alpha(Theme.accent(r.accentIndex), 0.16)
            Icon {
                anchors.centerIn: parent
                icon: r.icon
                size: 17
                color: Theme.accent(r.accentIndex)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt {
                Layout.fillWidth: true
                text: r.title
                font.weight: Font.DemiBold
            }
            Txt {
                Layout.fillWidth: true
                visible: r.sub !== ""
                text: r.sub
                font.pixelSize: 11
                color: Theme.fgDim
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
        StyledSwitch {
            checked: r.checked
            accent: Theme.accent(r.accentIndex)
            onToggled: v => r.toggled(v)
        }
    }

    // minutes stepper for one idle stage (0 = never)
    component IdleStep: RowLayout {
        id: st
        property string icon
        property string title
        property int seconds
        property int maxMinutes: 60
        signal picked(int seconds)
        readonly property int minutes: Math.round(seconds / 60)
        Layout.fillWidth: true
        spacing: 10
        Icon {
            icon: st.icon
            size: 16
            color: Theme.accent(6)
            Layout.leftMargin: 9
        }
        Txt {
            Layout.fillWidth: true
            text: st.title
        }
        IconBtn {
            icon: "minus"
            size: 28
            idleColor: Theme.alpha(Theme.fg, 0.08)
            onClicked: st.picked(Math.max(0, st.minutes - 1) * 60)
        }
        Txt {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignHCenter
            text: st.minutes > 0 ? st.minutes + "m" : "never"
            font.pixelSize: 14
            font.weight: Font.Black
            font.family: Theme.mono
            color: st.minutes > 0 ? Theme.accent(6) : Theme.fgDim
        }
        IconBtn {
            icon: "plus"
            size: 28
            idleColor: Theme.alpha(Theme.fg, 0.08)
            onClicked: st.picked(Math.min(st.maxMinutes, st.minutes + 1) * 60)
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 14

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active
            Flickable {
                anchors.fill: parent
                anchors.margins: 18
                contentHeight: col1.implicitHeight
                clip: true
                ColumnLayout {
                    id: col1
                    width: parent.width
                    spacing: 14
                    SectionTitle {
                        icon: "palette"
                        text: "Look & motion"
                        accent: Theme.accent(0)
                    }
                    // matugen scheme for the whole system
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 11
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.grad1 }
                                GradientStop { position: 1; color: Theme.grad2 }
                            }
                            Icon {
                                anchors.centerIn: parent
                                icon: "palette"
                                size: 17
                                color: Theme.on(Theme.grad1)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Txt {
                                text: "Colour scheme"
                                font.weight: Font.DemiBold
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: "How punchy matugen makes your wallpaper's colours (whole system)"
                                font.pixelSize: 11
                                color: Theme.fgDim
                                wrapMode: Text.Wrap
                                elide: Text.ElideNone
                            }
                        }
                        Btn {
                            readonly property var schemes: ["", "scheme-vibrant", "scheme-expressive", "scheme-fidelity", "scheme-content"]
                            text: Config.wallpaper.scheme === "" ? "default" : Config.wallpaper.scheme.replace("scheme-", "")
                            filled: false
                            implicitHeight: 30
                            fontSize: 11
                            onClicked: Config.wallpaper.scheme = schemes[(schemes.indexOf(Config.wallpaper.scheme) + 1) % schemes.length]
                        }
                        Btn {
                            text: "Apply"
                            accent: Theme.grad1
                            implicitHeight: 30
                            fontSize: 11
                            onClicked: Wallpapers.setMode(Config.wallpaper.mode)
                        }
                    }
                    SettingRow {
                        icon: "motion_play"
                        title: "Ambient motion"
                        sub: "Flowing borders, aurora, plasma orb (≈30 fps)"
                        checked: Config.fx.ambient
                        accentIndex: 1
                        onToggled: v => Config.fx.ambient = v
                    }
                    SettingRow {
                        icon: "battery_heart_variant"
                        title: "Ambient motion on battery"
                        checked: Config.fx.ambientOnBattery
                        accentIndex: 2
                        onToggled: v => Config.fx.ambientOnBattery = v
                    }
                    SettingRow {
                        icon: "rounded_corner"
                        title: "Rounded screen corners"
                        checked: Config.fx.corners
                        accentIndex: 3
                        onToggled: v => Config.fx.corners = v
                    }
                    SettingRow {
                        icon: "gesture_tap"
                        title: "Hot corner"
                        sub: "Top-left corner opens the overview"
                        checked: Config.fx.hotCorner
                        accentIndex: 4
                        onToggled: v => Config.fx.hotCorner = v
                    }
                    SectionTitle {
                        icon: "dock_top"
                        text: "Bar"
                        accent: Theme.accent(5)
                    }
                    SettingRow {
                        icon: "chart_donut"
                        title: "CPU / RAM / temp rings"
                        checked: Config.bar.showStats
                        accentIndex: 5
                        onToggled: v => Config.bar.showStats = v
                    }
                    SettingRow {
                        icon: "format_title"
                        title: "Window title"
                        checked: Config.bar.showTitle
                        accentIndex: 6
                        onToggled: v => Config.bar.showTitle = v
                    }
                    SettingRow {
                        icon: "apps"
                        title: "App icons in workspaces"
                        checked: Config.bar.workspaceIcons
                        accentIndex: 7
                        onToggled: v => Config.bar.workspaceIcons = v
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Txt {
                                text: "Workspaces always shown"
                                font.weight: Font.DemiBold
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: "Higher ones appear only while they have windows"
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }
                        }
                        IconBtn {
                            icon: "minus"
                            size: 30
                            idleColor: Theme.alpha(Theme.fg, 0.08)
                            onClicked: Config.bar.workspaces = Math.max(1, Config.bar.workspaces - 1)
                        }
                        Txt {
                            text: Config.bar.workspaces
                            font.pixelSize: 18
                            font.weight: Font.Black
                            font.family: Theme.mono
                            color: Theme.accent(5)
                            Layout.minimumWidth: 26
                            horizontalAlignment: Text.AlignHCenter
                        }
                        IconBtn {
                            icon: "plus"
                            size: 30
                            idleColor: Theme.alpha(Theme.fg, 0.08)
                            onClicked: Config.bar.workspaces = Math.min(10, Config.bar.workspaces + 1)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Txt {
                            text: "Bar opacity"
                            Layout.preferredWidth: 120
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            value: Config.bar.opacity
                            accent: Theme.accent(8)
                            accent2: Theme.accent(9)
                            onMoved: v => Config.bar.opacity = Math.round(Utils.clamp(v, 0.3, 1) * 100) / 100
                        }
                    }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active
            delay: 80
            Flickable {
                anchors.fill: parent
                anchors.margins: 18
                contentHeight: col2.implicitHeight
                clip: true
                ColumnLayout {
                    id: col2
                    width: parent.width
                    spacing: 14
                    SectionTitle {
                        icon: "monitor"
                        text: "Desktop & system"
                        accent: Theme.accent(2)
                    }
                    SettingRow {
                        icon: "dock_left"
                        title: "Left drawer"
                        sub: "Pull controls out from the left screen edge"
                        checked: Config.drawers.left
                        accentIndex: 2
                        onToggled: v => Config.drawers.left = v
                    }
                    SettingRow {
                        icon: "dock_right"
                        title: "Right drawer"
                        sub: "Pull notifications + calendar out from the right edge"
                        checked: Config.drawers.right
                        accentIndex: 3
                        onToggled: v => Config.drawers.right = v
                    }
                    SettingRow {
                        icon: "cursor_default_click"
                        title: "Open drawers on hover"
                        sub: "Rest the pointer on the edge instead of dragging"
                        checked: Config.drawers.hoverOpen
                        accentIndex: 4
                        onToggled: v => Config.drawers.hoverOpen = v
                    }
                    SettingRow {
                        icon: "bell_badge"
                        title: "Notification daemon"
                        sub: Notifs.foreignDaemon ? "swaync is running — stop it so Prism can take over" : "Prism handles org.freedesktop.Notifications"
                        checked: Config.notifications.server
                        accentIndex: 4
                        onToggled: v => Config.notifications.server = v
                    }
                    SettingRow {
                        icon: "eye_outline"
                        title: "Eye-break reminder"
                        sub: "Nudge to look away for 20 s after " + Config.breaks.everyMinutes + " min of use (idle time resets it)"
                        checked: Config.breaks.eyeReminder
                        accentIndex: 1
                        onToggled: v => Config.breaks.eyeReminder = v
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Txt {
                                text: "Focus timer"
                                font.weight: Font.DemiBold
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: Config.focus.breakMinutes + " min breaks · noise: " + Config.focus.noise + " · DND " + (Config.focus.silence ? "on" : "off")
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }
                        }
                        Btn {
                            text: Config.focus.noise
                            icon: "waves"
                            filled: false
                            implicitHeight: 30
                            fontSize: 11
                            onClicked: {
                                const k = ["off", "brown", "pink", "white"];
                                Config.focus.noise = k[(k.indexOf(Config.focus.noise) + 1) % k.length];
                            }
                        }
                        IconBtn {
                            icon: "minus"
                            size: 30
                            idleColor: Theme.alpha(Theme.fg, 0.08)
                            onClicked: Config.focus.workMinutes = Math.max(5, Config.focus.workMinutes - 5)
                        }
                        Txt {
                            text: Config.focus.workMinutes + "m"
                            font.pixelSize: 16
                            font.weight: Font.Black
                            font.family: Theme.mono
                            color: Theme.accent(0)
                        }
                        IconBtn {
                            icon: "plus"
                            size: 30
                            idleColor: Theme.alpha(Theme.fg, 0.08)
                            onClicked: Config.focus.workMinutes = Math.min(90, Config.focus.workMinutes + 5)
                        }
                    }
                    SettingRow {
                        icon: "sleep"
                        title: "Idle: dim, lock, screens off"
                        sub: Idle.hypridleRunning ? "hypridle is running, so it's in charge — stop it to use this" : "Media playing, caffeine and fullscreen video keep the screen awake"
                        checked: Config.idle.enabled
                        accentIndex: 6
                        onToggled: v => Config.idle.enabled = v
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: Config.idle.enabled
                        spacing: 4
                        IdleStep {
                            icon: "brightness_5"
                            title: "Dim the screen after"
                            seconds: Config.idle.dimAfter
                            onPicked: v => Config.idle.dimAfter = v
                        }
                        IdleStep {
                            icon: "lock_outline"
                            title: "Lock after"
                            seconds: Config.idle.lockAfter
                            onPicked: v => Config.idle.lockAfter = v
                        }
                        IdleStep {
                            icon: "monitor_off"
                            title: "Turn screens off after"
                            seconds: Config.idle.screenOffAfter
                            onPicked: v => Config.idle.screenOffAfter = v
                        }
                        IdleStep {
                            icon: "power_sleep"
                            title: "Suspend after"
                            seconds: Config.idle.suspendAfter
                            maxMinutes: 180
                            onPicked: v => Config.idle.suspendAfter = v
                        }
                    }
                    SettingRow {
                        visible: Config.idle.enabled
                        icon: "music"
                        title: "Playing media counts as use"
                        sub: "Music or a video playing anywhere keeps the screen on (like the screen-time tracker)"
                        checked: Config.idle.mediaKeepsAwake
                        accentIndex: 6
                        onToggled: v => Config.idle.mediaKeepsAwake = v
                    }
                    SettingRow {
                        visible: Config.idle.enabled
                        icon: "lock_clock"
                        title: "Lock before sleeping"
                        sub: "Lid closed or suspend: the lock screen is up before the laptop sleeps"
                        checked: Config.idle.lockBeforeSleep
                        accentIndex: 6
                        onToggled: v => Config.idle.lockBeforeSleep = v
                    }
                    SettingRow {
                        icon: "lock"
                        title: "Prism lock screen"
                        sub: "Use the Quickshell lock for `qs ipc call lock lock` instead of hyprlock. Preview it first."
                        checked: Config.lock.enabled
                        accentIndex: 5
                        onToggled: v => Config.lock.enabled = v
                    }
                    SettingRow {
                        icon: "shield_lock"
                        title: "Polkit agent"
                        sub: "Replace hyprpolkitagent (stop it first)"
                        checked: Config.polkit.enabled
                        accentIndex: 6
                        onToggled: v => Config.polkit.enabled = v
                    }
                    // weather location (wttr.in); empty = guess from IP
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 11
                            color: Theme.alpha(Theme.accent(1), 0.16)
                            Icon {
                                anchors.centerIn: parent
                                icon: "map_marker"
                                size: 17
                                color: Theme.accent(1)
                            }
                        }
                        InputField {
                            id: locField
                            Layout.fillWidth: true
                            implicitHeight: 38
                            icon: ""
                            fontSize: 13
                            accent: Theme.accent(1)
                            placeholder: "Weather location, e.g. Bhopal (empty = auto)"
                            text: Config.weather.location
                            onAccepted: {
                                Config.weather.location = locField.text.trim();
                                Weather.refresh();
                            }
                        }
                        Btn {
                            text: "Set"
                            accent: Theme.accent(1)
                            implicitHeight: 34
                            onClicked: {
                                Config.weather.location = locField.text.trim();
                                Weather.refresh();
                            }
                        }
                    }
                    SettingRow {
                        icon: "temperature_fahrenheit"
                        title: "Fahrenheit"
                        checked: Config.weather.fahrenheit
                        accentIndex: 7
                        onToggled: v => {
                            Config.weather.fahrenheit = v;
                            Weather.refresh();
                        }
                    }
                    SectionTitle {
                        icon: "lightning_bolt"
                        text: "Actions"
                        accent: Theme.accent(8)
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Btn {
                            icon: "lock_open_variant"
                            text: "Preview lock screen"
                            accent: Theme.accent(5)
                            onClicked: {
                                Panels.dashboard = false;
                                Session.preview = true;
                            }
                        }
                        Btn {
                            icon: "bell_ring"
                            text: "Test notification"
                            accent: Theme.accent(7)
                            onClicked: Notifs.local("Hello from Prism ✨", "Notifications look like this.", "creation", 1, "", [{ text: "Nice", run: () => {} }])
                        }
                        Btn {
                            icon: "image_multiple"
                            text: Wallpapers.thumbing ? "Thumbnailing…" : "Build thumbnails"
                            accent: Theme.accent(1)
                            onClicked: {
                                Wallpapers.load();
                            }
                        }
                        Btn {
                            icon: "code_json"
                            text: "Edit config.json"
                            filled: false
                            onClicked: Quickshell.execDetached([Config.apps.editor, Config.shellDir + "/config.json"])
                        }
                        Btn {
                            icon: "refresh"
                            text: "Reload shell"
                            filled: false
                            onClicked: Quickshell.reload(true)
                        }
                    }
                }
            }
        }
    }
}
