pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets

// Indicators, network, bluetooth, volume, battery, notifications, clock, power.
RowLayout {
    id: root

    spacing: 4

    // ---- transient indicators (only while active) ----
    Repeater {
        model: [
            { on: () => Toggles.caffeine, icon: "coffee", tip: "Caffeine — staying awake", act: () => Toggles.toggleCaffeine(), accent: 1 },
            { on: () => Notifs.dnd, icon: "bell_sleep", tip: "Do not disturb", act: () => { Notifs.dnd = false; }, accent: 7 },
            { on: () => Toggles.noise !== "off", icon: "waves", tip: "Noise: " + Toggles.noise, act: () => Toggles.cycleNoise(), accent: 4 },
            { on: () => Toggles.gameMode, icon: "gamepad_variant", tip: "Game mode", act: () => Toggles.toggleGameMode(), accent: 2 },
            { on: () => Toggles.warm, icon: "weather_night", tip: "Warm screen", act: () => Toggles.toggleWarm(), accent: 1 }
        ]
        delegate: IconBtn {
            required property var modelData
            readonly property bool isOn: modelData.on()
            size: isOn ? 28 : 0
            visible: size > 0.5
            opacity: isOn ? 1 : 0
            icon: modelData.icon
            iconSize: 15
            iconColor: modelData.icon === "record_rec" ? "#ff5a6a" : Theme.accent(modelData.accent)
            idleColor: Theme.alpha(Theme.accent(modelData.accent), 0.14)
            tooltip: modelData.tip
            onClicked: modelData.act()
            Behavior on size { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
            Behavior on opacity { NumAnim {} }
        }
    }

    // focus timer: ring + time left (click pause/resume, right-click stop)
    Rectangle {
        visible: Focus.active
        implicitHeight: 26
        implicitWidth: focusRow.implicitWidth + 14
        radius: 13
        color: Theme.alpha(Focus.tint, focusHover.hovered ? 0.3 : 0.16)
        border.width: 1
        border.color: Theme.alpha(Focus.tint, 0.6)
        RowLayout {
            id: focusRow
            anchors.centerIn: parent
            spacing: 5
            Ring {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                value: Focus.progress
                animated: false
                thickness: 2.5
                color: Focus.tint
            }
            Txt {
                text: (Focus.paused ? "⏸ " : "") + Focus.leftText
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.Bold
                color: Focus.tint
            }
        }
        HoverHandler {
            id: focusHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onTapped: (p, button) => button === Qt.RightButton ? Focus.stop() : Focus.pause()
        }
        Tip {
            text: Focus.label + " · round " + (Focus.round + 1) + " · click pause, right-click stop"
            show: focusHover.hovered
        }
    }

    // recording: small red dot + timer (click to stop)
    Rectangle {
        visible: Toggles.recording
        implicitHeight: 26
        implicitWidth: recRow.implicitWidth + 16
        radius: 13
        color: Theme.alpha("#ff4d5e", recHover.hovered ? 0.3 : 0.16)
        border.width: 1
        border.color: Theme.alpha("#ff4d5e", 0.6)
        RowLayout {
            id: recRow
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                implicitWidth: 9
                implicitHeight: 9
                radius: 5
                color: "#ff4d5e"
                SequentialAnimation on opacity {
                    running: Toggles.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }
            Txt {
                text: Utils.mmss((recClock.date.getTime() - Toggles.recordStart) / 1000)
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.Bold
                color: "#ff8a95"
            }
        }
        SystemClock {
            id: recClock
            precision: SystemClock.Seconds
            enabled: Toggles.recording
        }
        HoverHandler {
            id: recHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: Toggles.stopRecording()
        }
        Tip {
            text: "Recording — click to stop"
            show: recHover.hovered
        }
    }

    IconBtn {
        icon: Net.icon
        size: 30
        iconSize: 16
        iconColor: Net.connected ? Theme.fg : Theme.fgDim
        tooltip: Net.name + (Net.active ? " · " + Math.round(Net.strength * 100) + "%" : "")
        onClicked: mouse => mouse.button === Qt.RightButton ? Net.toggleWifi() : Panels.openDashboard(4)
    }

    IconBtn {
        visible: BT.available
        icon: BT.icon
        size: 30
        iconSize: 16
        iconColor: BT.connected.length > 0 ? Theme.accent(6) : BT.enabled ? Theme.fg : Theme.fgDim
        tooltip: "Bluetooth · " + BT.summary
        onClicked: mouse => mouse.button === Qt.RightButton ? BT.toggle() : Panels.openDashboard(4)
    }

    IconBtn {
        icon: Audio.icon
        size: 30
        iconSize: 16
        iconColor: Audio.muted ? Theme.error : Theme.fg
        tooltip: Audio.muted ? "Muted" : "Volume " + Math.round(Audio.volume * 100) + "% · scroll to change"
        onClicked: mouse => mouse.button === Qt.RightButton ? Panels.openDashboard(5) : Audio.toggleMute()
        onWheel: event => Audio.nudge(event.angleDelta.y > 0 ? 0.05 : -0.05)
    }

    // ---- battery capsule ----
    Item {
        id: bat
        visible: Power.present
        implicitWidth: capsule.width + 8
        implicitHeight: 28

        readonly property color fillColor: Power.critical ? Theme.error : Power.low ? "#ffb35c" : Power.charging ? "#7dee9b" : Theme.accent(3)

        Rectangle {
            id: capsule
            anchors.centerIn: parent
            width: 46
            height: 20
            radius: 7
            color: Theme.alpha(Theme.fg, 0.08)
            border.width: 1.5
            border.color: Theme.alpha(bat.fillColor, 0.7)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 3
                width: (parent.width - 6) * Power.level
                radius: 4
                color: bat.fillColor
                opacity: 0.85
                Behavior on width { NumAnim { duration: Motion.slow } }

                // charging shimmer
                Rectangle {
                    visible: Power.charging
                    width: 10
                    height: parent.height
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.55)
                    NumberAnimation on x {
                        running: Power.charging
                        from: -10
                        to: (capsule.width - 6) * Power.level
                        duration: 1300
                        loops: Animation.Infinite
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 1
                Icon {
                    visible: Power.charging || !Power.onBattery
                    icon: "flash"
                    size: 11
                    color: Theme.on(bat.fillColor)
                    bounce: false
                }
                Txt {
                    text: Power.percent
                    font.pixelSize: 11
                    font.weight: Font.Black
                    font.family: Theme.mono
                    color: Power.level > 0.45 ? Theme.on(bat.fillColor) : Theme.fg
                }
            }

            // critical pulse
            SequentialAnimation on opacity {
                running: Power.critical
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 500 }
                NumberAnimation { to: 1; duration: 500 }
            }
        }
        Rectangle {
            anchors.left: capsule.right
            anchors.leftMargin: 1
            anchors.verticalCenter: capsule.verticalCenter
            width: 3
            height: 8
            radius: 1.5
            color: Theme.alpha(bat.fillColor, 0.7)
        }

        HoverHandler {
            id: batHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onTapped: (p, button) => button === Qt.RightButton ? Panels.openDashboard(2) : Power.cycleProfile()
        }
        Tip {
            text: Power.percent + "% · " + Power.statusText + " · " + Power.profileName + " (click to cycle)"
            show: batHover.hovered
        }
    }

    // ---- notifications bell ----
    Item {
        id: bellBox
        implicitWidth: 30
        implicitHeight: 30
        IconBtn {
            id: bell
            anchors.fill: parent
            icon: Notifs.dnd ? "bell_sleep" : Notifs.unread > 0 ? "bell_ring" : "bell_outline"
            iconSize: 16
            active: Panels.sidebar
            accent: Theme.accent(7)
            tooltip: Notifs.count + " notifications"
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    Notifs.dnd = !Notifs.dnd;
                else
                    Panels.toggle("sidebar");
            }
        }
        Rectangle {
            visible: Notifs.unread > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2
            width: Math.max(16, badge.implicitWidth + 8)
            height: 16
            radius: 8
            color: Theme.error
            scale: visible ? 1 : 0
            Behavior on scale { NumAnim { easing.bezierCurve: Motion.bouncy } }
            Txt {
                id: badge
                anchors.centerIn: parent
                text: Notifs.unread > 99 ? "99+" : Notifs.unread
                font.pixelSize: 9
                font.weight: Font.Black
                color: Theme.fgError
            }
        }
        // wiggle on new notification
        property int lastUnread: Notifs.unread
        Connections {
            target: Notifs
            function onUnreadChanged() {
                if (Notifs.unread > bellBox.lastUnread)
                    wiggle.restart();
                bellBox.lastUnread = Notifs.unread;
            }
        }
        SequentialAnimation {
            id: wiggle
            NumberAnimation { target: bell; property: "rotation"; to: 18; duration: 70 }
            NumberAnimation { target: bell; property: "rotation"; to: -16; duration: 110 }
            NumberAnimation { target: bell; property: "rotation"; to: 10; duration: 110 }
            NumberAnimation { target: bell; property: "rotation"; to: 0; duration: 260; easing.type: Easing.OutBack }
        }
    }

    // ---- dark / light ----
    IconBtn {
        icon: Wallpapers.light ? "weather_sunny" : "weather_night"
        size: 30
        iconSize: 16
        iconColor: Wallpapers.light ? "#f2b84b" : Theme.accent(7)
        tooltip: (Wallpapers.light ? "Light" : "Dark") + " theme · click to switch"
        onClicked: Wallpapers.toggleMode()
    }

    // ---- floating clock: shows what's counting, pulses while ringing ----
    Rectangle {
        id: chronoBtn
        readonly property bool counting: Chrono.timerRunning || Chrono.ivRunning || Chrono.swRunning
        readonly property bool ringing: Chrono.ringing !== null
        implicitWidth: chronoRow.implicitWidth + 16
        implicitHeight: 30
        radius: 15
        color: ringing ? Theme.alpha(Theme.grad1, 0.35) : Chrono.open || counting ? Theme.alpha(Theme.grad1, chronoHover.hovered ? 0.24 : 0.14) : Theme.alpha(Theme.primary, chronoHover.hovered ? 0.16 : 0)
        Behavior on color { ColAnim {} }
        Behavior on implicitWidth { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
        SequentialAnimation on opacity {
            running: chronoBtn.ringing
            loops: Animation.Infinite
            onStopped: chronoBtn.opacity = 1
            NumberAnimation { to: 0.45; duration: 380 }
            NumberAnimation { to: 1; duration: 380 }
        }
        Row {
            id: chronoRow
            anchors.centerIn: parent
            spacing: 5
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Chrono.timerRunning || Chrono.ivRunning ? "timer_sand" : Chrono.swRunning ? "timer_outline" : "alarm"
                size: 15
                color: chronoBtn.counting || chronoBtn.ringing ? Theme.grad1 : Theme.fg
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: chronoBtn.counting
                text: Chrono.timerRunning ? Utils.hms(Math.ceil(Chrono.timerLeft / 1000)) : Chrono.ivRunning ? Utils.hms(Math.ceil(Chrono.ivState().left)) : Utils.hms(Chrono.swElapsed / 1000)
                font.pixelSize: 11
                font.family: Theme.mono
                color: Theme.fg
            }
        }
        HoverHandler {
            id: chronoHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: chronoBtn.ringing ? Chrono.stopRinging() : Chrono.toggle()
        }
        Tip {
            text: chronoBtn.ringing ? "Click to stop" : Chrono.nextAlarm ? "Clock · next alarm in " + Utils.human(Chrono.nextAlarm.inMs / 1000) : "Clock: alarms, world clock, timer, stopwatch"
            show: chronoHover.hovered
        }
    }

    // ---- clock ----
    Item {
        implicitWidth: clockCol.implicitWidth + 16
        implicitHeight: 34
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.alpha(Theme.primary, clockHover.hovered ? 0.16 : 0)
            Behavior on color { ColAnim {} }
        }
        Column {
            id: clockCol
            anchors.centerIn: parent
            spacing: -2
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(sysClock.date, "HH:mm")
                font.pixelSize: 15
                font.weight: Font.Black
                font.family: Theme.display
                color: Theme.fg
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(sysClock.date, "ddd d")
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.accent(2)
            }
        }
        HoverHandler {
            id: clockHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: Panels.toggle("sidebar")
        }
        // right-click: the floating clock
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: Chrono.toggle()
        }
        Tip {
            text: Qt.formatDate(sysClock.date, "dddd, d MMMM yyyy") + " · right-click: clock"
            show: clockHover.hovered
        }
        SystemClock {
            id: sysClock
            precision: SystemClock.Minutes
        }
    }

    IconBtn {
        icon: "power"
        size: 30
        iconSize: 16
        iconColor: hovered ? Theme.fgError : Theme.error
        idleColor: hovered ? Theme.error : "transparent"
        tooltip: "Power"
        onClicked: Panels.toggle("power")
    }
}
