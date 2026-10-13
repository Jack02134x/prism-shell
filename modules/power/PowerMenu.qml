pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets

// Orbit power menu. Destructive actions arm on the first press and fire on
// the second (within 4 s). Keys: ←/→ or 1–6, Enter, Esc.
Overlay {
    id: win

    name: "power"
    open: Panels.power
    scrimOpacity: 0.55
    openDuration: Motion.slower
    onDismiss: Panels.power = false
    onOpened: {
        selected = 0;
        armed = -1;
        keys.forceActiveFocus();
    }

    property int selected: 0
    property int armed: -1

    readonly property var actions: [
        { name: "Lock", icon: "lock", c: 0, confirm: false, run: () => Session.lock() },
        { name: "Suspend", icon: "power_sleep", c: 2, confirm: false, run: () => Session.suspend() },
        { name: "Log out", icon: "logout", c: 4, confirm: true, run: () => Session.logout() },
        { name: "Hibernate", icon: "snowflake", c: 5, confirm: true, run: () => Session.hibernate() },
        { name: "Reboot", icon: "restart", c: 7, confirm: true, run: () => Session.reboot() },
        { name: "Shut down", icon: "power", c: 9, confirm: true, run: () => Session.shutdown() }
    ]

    function trigger(i) {
        const a = actions[i];
        selected = i;
        if (a.confirm && armed !== i) {
            armed = i;
            armTimer.restart();
            return;
        }
        Panels.power = false;
        a.run();
    }

    Timer {
        id: armTimer
        interval: 4000
        onTriggered: win.armed = -1
    }

    // blurred wallpaper backdrop
    Image {
        id: wall
        anchors.fill: parent
        source: Theme.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 960
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.25
        opacity: win.progress
    }
    Aurora {
        anchors.fill: parent
        intensity: 0.9
        opacity: 0.45 * win.progress
        bg: Qt.rgba(0, 0, 0, 0)
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const n = win.actions.length;
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                win.selected = (win.selected + 1) % n;
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                win.selected = (win.selected + n - 1) % n;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                win.trigger(win.selected);
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6)
                win.trigger(event.key - Qt.Key_1);
            else
                return;
            event.accepted = true;
        }
    }

    Item {
        id: stage
        anchors.centerIn: parent
        width: 640
        height: 640
        scale: 0.8 + 0.2 * win.progress
        opacity: win.progress
        rotation: (1 - win.progress) * -40

        // orbit ring
        Rectangle {
            anchors.centerIn: parent
            width: 470
            height: 470
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.alpha(Theme.accent(win.actions[win.selected].c), 0.35)
            Behavior on border.color { ColAnim {} }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 300
            height: 300
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            rotation: Motion.t * 360
        }

        // centre
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            Avatar {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 130
                Layout.preferredHeight: 130
                ring: 4
            }
            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: win.armed >= 0 ? "Press again to " + win.actions[win.armed].name.toLowerCase() : "See you soon, " + Config.user.name
                font.pixelSize: 20
                font.weight: Font.Black
                font.family: Theme.display
                color: win.armed >= 0 ? Theme.accent(win.actions[win.armed].c) : "white"
            }
            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: "up " + Utils.human(SysStats.uptime) + "  ·  " + Power.percent + "% battery"
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.7)
            }
        }

        Repeater {
            model: win.actions
            Item {
                id: btn
                required property var modelData
                required property int index
                readonly property real angle: -90 + index * 360 / win.actions.length
                readonly property real r: 235 * Math.min(1, Math.max(0, win.progress * 1.4 - index * 0.06))
                readonly property bool sel: win.selected === index
                readonly property bool isArmed: win.armed === index
                readonly property color accent: Theme.accent(modelData.c)
                width: 104
                height: 104
                x: stage.width / 2 + Math.cos(angle * Math.PI / 180) * r - width / 2
                y: stage.height / 2 + Math.sin(angle * Math.PI / 180) * r - height / 2
                rotation: -stage.rotation

                Rectangle {
                    id: face
                    anchors.centerIn: parent
                    width: btn.sel ? 96 : 80
                    height: width
                    radius: btn.sel ? 30 : width / 2
                    color: btn.sel ? btn.accent : Theme.alpha(Theme.surface, 0.85)
                    border.width: 2
                    border.color: btn.accent
                    Behavior on width { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }
                    Behavior on radius { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
                    Behavior on color { ColAnim {} }

                    Icon {
                        anchors.centerIn: parent
                        icon: btn.modelData.icon
                        size: btn.sel ? 38 : 30
                        color: btn.sel ? Theme.on(btn.accent) : btn.accent
                    }

                    // confirm countdown ring
                    Ring {
                        anchors.centerIn: parent
                        width: parent.width + 18
                        height: width
                        visible: btn.isArmed
                        thickness: 4
                        color: btn.accent
                        trackColor: "transparent"
                        value: armProgress.value
                        QtObject {
                            id: armProgress
                            property real value: 1
                        }
                        NumberAnimation {
                            target: armProgress
                            property: "value"
                            from: 1
                            to: 0
                            duration: 4000
                            running: btn.isArmed
                        }
                    }
                }

                Txt {
                    anchors.top: face.bottom
                    anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: btn.modelData.name
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: btn.sel ? btn.accent : Qt.rgba(1, 1, 1, 0.75)
                }

                MouseArea {
                    anchors.fill: face
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.selected = btn.index
                    onClicked: win.trigger(btn.index)
                }
            }
        }
    }

    Txt {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: win.progress * 0.7
        text: "←/→ choose   ·   Enter confirm   ·   1–6 shortcut   ·   Esc cancel"
        font.pixelSize: 12
        color: "white"
    }
}
