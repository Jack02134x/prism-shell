import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// The clock shrunk to a pill: whatever is running (timer, intervals,
// stopwatch), else the time. Drag it anywhere; double-click to expand.
Item {
    id: root

    property var win

    // stopwatch centiseconds while it runs
    property real swMs: Chrono.swElapsed
    FrameAnimation {
        running: root.visible && Chrono.swRunning && root.what === "sw"
        onTriggered: root.swMs = Chrono.d.sw.acc + Date.now() - Chrono.d.sw.start
    }

    readonly property string what: Chrono.ringing ? "ring" : (Chrono.timerRunning || Chrono.timerPaused) ? "timer" : (Chrono.ivRunning || Chrono.ivPaused) ? "iv" : (Chrono.swRunning || Chrono.d.sw.acc > 0) ? "sw" : "clock"
    readonly property var iv: what === "iv" ? Chrono.ivState() : null
    readonly property var shown: new Date(Chrono.now + Chrono.fastOffset())

    MouseArea {
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: m => root.win.dragStart(m)
        onPositionChanged: m => root.win.dragMove(m)
        onReleased: root.win.dragEnd()
        onDoubleClicked: {
            Chrono.d.win.mini = false;
            Chrono.touch();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 10

        // play / pause (or stop the ringing)
        IconBtn {
            size: 40
            active: true
            accent: root.what === "ring" ? Theme.error : Theme.primary
            icon: root.what === "ring" ? "alarm_off" : root.what === "timer" ? (Chrono.timerRunning ? "pause" : "play") : root.what === "iv" ? (Chrono.ivRunning ? "pause" : "play") : root.what === "sw" ? (Chrono.swRunning ? "pause" : "play") : "alarm"
            onClicked: {
                if (root.what === "ring")
                    Chrono.stopRinging();
                else if (root.what === "timer")
                    Chrono.timerPause();
                else if (root.what === "iv")
                    Chrono.ivPause();
                else if (root.what === "sw")
                    Chrono.swToggle();
                else {
                    Chrono.d.win.mini = false;
                    Chrono.setTab("alarm");
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            Txt {
                Layout.fillWidth: true
                text: root.what === "ring" ? Chrono.ringing.title : root.what === "timer" ? Utils.hms(Math.ceil(Chrono.timerLeft / 1000)) : root.what === "iv" ? Utils.hms(Math.ceil(root.iv.left)) : root.what === "sw" ? Utils.hmsc(root.swMs) : Chrono.fmtClock(root.shown.getHours(), root.shown.getMinutes())
                font.family: root.what === "ring" ? Theme.font : Theme.display
                font.pixelSize: 22
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
            Txt {
                Layout.fillWidth: true
                text: root.what === "ring" ? Chrono.ringing.sub : root.what === "timer" ? (Chrono.timerPaused ? "Timer · paused" : "Timer") : root.what === "iv" ? root.iv.step.name + (Chrono.ivPaused ? " · paused" : "") : root.what === "sw" ? (Chrono.swRunning ? "Stopwatch" : "Stopwatch · paused") : (Chrono.nextAlarm ? "Alarm " + Chrono.fmtWhen(Chrono.nextAlarm.at) : Qt.formatDate(root.shown, "ddd d MMM"))
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }
        IconBtn {
            icon: "arrow_expand"
            size: 30
            tooltip: "Expand"
            onClicked: {
                Chrono.d.win.mini = false;
                Chrono.touch();
            }
        }
        IconBtn {
            icon: "close"
            size: 30
            tooltip: "Close"
            onClicked: Chrono.hide()
        }
    }
}
