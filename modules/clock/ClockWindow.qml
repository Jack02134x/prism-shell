import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.widgets

// The floating clock: Alarm, Clock, Timer and Stopwatch tabs. It's a layer
// surface on the Overlay layer, so it stays above fullscreen windows. Drag it
// by its header; the pin keeps it on one workspace; mini shrinks it to a pill.
PanelWindow {
    id: win

    readonly property real fullW: 380
    readonly property real fullH: 620
    readonly property real miniW: 270
    readonly property real miniH: 60
    readonly property bool mini: Chrono.d.win.mini
    readonly property real w: mini ? miniW : fullW
    readonly property real h: mini ? miniH : fullH

    screen: Quickshell.screens.find(s => s.name === Chrono.d.win.screen) ?? Panels.focusedScreen
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool onThisWs: Chrono.d.win.pinWs === 0 || monitor?.activeWorkspace?.id === Chrono.d.win.pinWs

    visible: Chrono.open && onThisWs
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors {
        top: true
        left: true
    }
    implicitWidth: w
    implicitHeight: h

    // position: saved, or the top right corner below the bar
    readonly property real sw: screen?.width ?? 1920
    readonly property real sh: screen?.height ?? 1080
    property real dragX: -1
    property real dragY: -1
    readonly property real px: Utils.clamp(dragX >= 0 ? dragX : Chrono.d.win.x >= 0 ? Chrono.d.win.x : sw - fullW - 18, 0, Math.max(0, sw - w))
    readonly property real py: Utils.clamp(dragY >= 0 ? dragY : Chrono.d.win.y >= 0 ? Chrono.d.win.y : 64, 0, Math.max(0, sh - h))
    margins {
        left: px
        top: py
    }

    // ---- dragging (header, mini pill): move by how far the pointer moved ----
    property real pressX: 0
    property real pressY: 0
    function dragStart(m) {
        pressX = m.x;
        pressY = m.y;
        dragX = px;
        dragY = py;
    }
    function dragMove(m) {
        dragX = Utils.clamp(dragX + m.x - pressX, 0, sw - w);
        dragY = Utils.clamp(dragY + m.y - pressY, 0, sh - h);
    }
    function dragEnd() {
        Chrono.d.win.x = Math.round(dragX);
        Chrono.d.win.y = Math.round(dragY);
        Chrono.d.win.screen = screen?.name ?? "";
        dragX = dragY = -1;
        Chrono.touch();
    }

    // ---- sheets (editors that slide up over the tab) ----
    property string sheet: ""
    property var draft: null
    function openSheet(name, data) {
        draft = data ?? null;
        sheet = name;
    }
    function closeSheet() {
        sheet = "";
    }
    function setDraft(k, v) {
        const x = Object.assign({}, draft);
        x[k] = v;
        draft = x;
    }
    function editAlarm(a, groupId) {
        const now = new Date();
        openSheet("alarm", a ? JSON.parse(JSON.stringify(a)) : { id: 0, h: now.getHours(), m: (Math.ceil(now.getMinutes() / 5) * 5) % 60, label: "", days: 0, rep: null, group: groupId ?? 0, tone: "", skip: 0 });
    }

    // ---- a short message at the bottom ----
    function toast(msg) {
        toastTxt.text = msg;
        toastBox.shown = true;
        toastHide.restart();
    }

    readonly property var titles: ({ alarm: "Alarm", clock: "Clock", timer: "Timer", stopwatch: "Stopwatch" })
    readonly property string tab: Chrono.d.win.tab

    onVisibleChanged: if (visible) keys.forceActiveFocus()
    // children with their own `win` property can't say `win: win` (that's
    // themselves): they take the window from here
    QtObject {
        id: ref
        readonly property var w: win
    }


    // ================================================================ card ===
    Rectangle {
        id: card
        anchors.fill: parent
        radius: win.mini ? height / 2 : Theme.r.xl
        gradient: TintGradient { alpha: 1; amount: 0.12; orientation: Gradient.Vertical }
        border.width: 1
        border.color: Theme.alpha(Theme.grad1, Chrono.ringing ? 0.8 : 0.3)
        clip: true

        // ---- mini ----
        ClockMini {
            anchors.fill: parent
            visible: win.mini
            win: ref.w
        }

        // ---- full ----
        ColumnLayout {
            anchors.fill: parent
            visible: !win.mini
            spacing: 0

            // header: the title, then keep awake, pin, mini, settings, close
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                MouseArea {
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: m => win.dragStart(m)
                    onPositionChanged: m => win.dragMove(m)
                    onReleased: win.dragEnd()
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 12
                    spacing: 2
                    Txt {
                        Layout.fillWidth: true
                        text: win.titles[win.tab] ?? "Clock"
                        font.pixelSize: 21
                        font.weight: Font.Bold
                    }
                    IconBtn {
                        icon: Toggles.caffeine ? "coffee" : "coffee_outline"
                        size: 34
                        active: Toggles.caffeine
                        tooltip: Toggles.caffeine ? "Staying awake (click to allow sleep)" : "Keep the screen awake"
                        onClicked: Toggles.toggleCaffeine()
                    }
                    IconBtn {
                        icon: Chrono.d.win.pinWs ? "pin" : "pin_outline"
                        size: 34
                        active: Chrono.d.win.pinWs !== 0
                        tooltip: Chrono.d.win.pinWs ? "Only on workspace " + Chrono.d.win.pinWs + " (click: every workspace)" : "On every workspace (click: only this one)"
                        onClicked: {
                            Chrono.d.win.pinWs = Chrono.d.win.pinWs ? 0 : (win.monitor?.activeWorkspace?.id ?? 0);
                            Chrono.d.win.screen = win.screen?.name ?? "";
                            Chrono.touch();
                        }
                    }
                    IconBtn {
                        icon: "arrow_collapse"
                        size: 34
                        tooltip: "Mini"
                        onClicked: {
                            Chrono.d.win.mini = true;
                            Chrono.touch();
                        }
                    }
                    IconBtn {
                        icon: "tune_variant"
                        size: 34
                        tooltip: "Settings"
                        onClicked: win.openSheet("settings")
                    }
                    IconBtn {
                        icon: "close"
                        size: 34
                        tooltip: "Close (Esc) · alarms still ring"
                        onClicked: Chrono.hide()
                    }
                }
            }

            // the tab
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: win.tab === "alarm" ? alarmTab : win.tab === "timer" ? timerTab : win.tab === "stopwatch" ? swTab : clockTab
            }

            // bottom navigation
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: Theme.alpha(Theme.surfaceHigh, 0.5)
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.alpha(Theme.outline, 0.2)
                }
                Row {
                    anchors.fill: parent
                    Repeater {
                        model: [
                            { id: "alarm", label: "Alarm", icon: "alarm" },
                            { id: "clock", label: "Clock", icon: "clock_outline" },
                            { id: "timer", label: "Timer", icon: "timer_sand" },
                            { id: "stopwatch", label: "Stopwatch", icon: "timer_outline" }
                        ]
                        Item {
                            id: navItem
                            required property var modelData
                            readonly property bool on: win.tab === modelData.id
                            width: parent.width / 4
                            height: parent.height
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 10
                                width: navItem.on ? 60 : 30
                                height: 30
                                radius: 15
                                color: navItem.on ? Theme.alpha(Theme.primary, 0.9) : "transparent"
                                Behavior on width { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
                                Icon {
                                    anchors.centerIn: parent
                                    icon: navItem.modelData.icon
                                    size: 19
                                    color: navItem.on ? Theme.on(Theme.primary) : Theme.fgDim
                                }
                            }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 45
                                text: navItem.modelData.label
                                font.pixelSize: 11
                                font.weight: navItem.on ? Font.Bold : Font.Normal
                                color: navItem.on ? Theme.fg : Theme.fgDim
                            }
                            Interactive {
                                hoverOpacity: 0.04
                                onClicked: {
                                    win.closeSheet();
                                    Chrono.setTab(navItem.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- sheet ----
        Rectangle {
            anchors.fill: parent
            visible: opacity > 0
            opacity: win.sheet !== "" && !win.mini ? 1 : 0
            color: Qt.rgba(0, 0, 0, 0.4)
            Behavior on opacity { NumAnim { duration: Motion.fast } }
            MouseArea {
                anchors.fill: parent
                onClicked: win.closeSheet()
                onWheel: {}
            }
        }
        ClockSheet {
            win: ref.w
            open: win.sheet !== "" && !win.mini
        }

        // ---- toast ----
        Rectangle {
            id: toastBox
            property bool shown: false
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 84 - height + (shown ? 0 : 20)
            visible: opacity > 0 && !win.mini
            opacity: shown ? 1 : 0
            width: Math.min(parent.width - 40, toastTxt.implicitWidth + 32)
            height: 36
            radius: 18
            color: Theme.inverseSurface
            Behavior on opacity { NumAnim { duration: Motion.fast } }
            Behavior on y { NumAnim { duration: Motion.normal } }
            Txt {
                id: toastTxt
                anchors.centerIn: parent
                width: parent.width - 32
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.surface
            }
            Timer {
                id: toastHide
                interval: 2600
                onTriggered: toastBox.shown = false
            }
        }
    }

    // ---- keys: Esc closes; digits type into the timer; Space / L for the stopwatch ----
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) {
                win.sheet !== "" ? win.closeSheet() : Chrono.hide();
            } else if (win.sheet !== "" || win.mini) {
                return;
            } else if (win.tab === "timer" && Chrono.d.win.tmode === "timer" && Chrono.d.timer.status === "idle" && e.text >= "0" && e.text <= "9" && e.text.length === 1) {
                win.typeDigit(e.text);
            } else if (win.tab === "timer" && Chrono.d.timer.status === "idle" && e.key === Qt.Key_Backspace) {
                win.typeDigit("del");
            } else if (win.tab === "timer" && Chrono.d.timer.status === "idle" && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) {
                win.startTyped();
            } else if (win.tab === "stopwatch" && e.key === Qt.Key_Space) {
                Chrono.swToggle();
            } else if (win.tab === "stopwatch" && e.key === Qt.Key_L && Chrono.swRunning) {
                Chrono.swLap();
            } else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4 && (e.modifiers & Qt.AltModifier)) {
                Chrono.setTab(["alarm", "clock", "timer", "stopwatch"][e.key - Qt.Key_1]);
            } else {
                return;
            }
            e.accepted = true;
        }
    }

    // the timer's typed digits: hhmmss filled from the right
    function typeDigit(k) {
        let s = Chrono.d.timer.digits || "";
        s = k === "del" ? s.slice(0, -1) : (s + k).replace(/^0+/, "").slice(0, 6);
        Chrono.d.timer.digits = s;
        Chrono.touch();
    }
    function typedSecs() {
        const s = ("000000" + (Chrono.d.timer.digits || "")).slice(-6);
        return parseInt(s.slice(0, 2)) * 3600 + parseInt(s.slice(2, 4)) * 60 + parseInt(s.slice(4, 6));
    }
    function startTyped() {
        const secs = typedSecs();
        if (secs > 0)
            Chrono.timerStart(secs * 1000);
    }

    Component {
        id: alarmTab
        ClockTabAlarm {
            win: ref.w
        }
    }
    Component {
        id: clockTab
        ClockTabClock {
            win: ref.w
        }
    }
    Component {
        id: timerTab
        ClockTabTimer {
            win: ref.w
        }
    }
    Component {
        id: swTab
        ClockTabStopwatch {
            win: ref.w
        }
    }
}
