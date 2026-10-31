import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.common
import qs.services
import qs.widgets

// Idle: type hh mm ss on the keypad (or the keyboard). Running: a ring that
// empties, with pause, reset and +1:00.
Item {
    id: root

    property var win
    readonly property bool idle: Chrono.d.timer.status === "idle"
    readonly property string digits: ("000000" + (Chrono.d.timer.digits || "")).slice(-6)

    // ---- idle ----
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 16
        visible: root.idle
        spacing: 10

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 6
            Repeater {
                model: [{ v: root.digits.slice(0, 2), u: "h" }, { v: root.digits.slice(2, 4), u: "m" }, { v: root.digits.slice(4, 6), u: "s" }]
                Row {
                    required property var modelData
                    spacing: 2
                    Txt {
                        text: parent.modelData.v
                        font.family: Theme.display
                        font.pixelSize: 54
                        font.weight: Font.Light
                        color: (Chrono.d.timer.digits || "") === "" ? Theme.fgDim : Theme.fg
                    }
                    Txt {
                        y: 30
                        text: parent.modelData.u
                        font.pixelSize: 18
                        color: Theme.fgDim
                    }
                }
            }
        }
        // quick picks
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Repeater {
                model: [1, 5, 10, 25]
                Btn {
                    required property int modelData
                    text: modelData + " min"
                    filled: false
                    implicitHeight: 30
                    fontSize: 12
                    onClicked: Chrono.timerStart(modelData * 60000)
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: 8
            columnSpacing: 8
            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "del"]
                Rectangle {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.r.lg
                    color: Theme.alpha(Theme.surfaceHighest, 0.55)
                    Txt {
                        anchors.centerIn: parent
                        visible: parent.modelData !== "del"
                        text: parent.modelData
                        font.family: Theme.display
                        font.pixelSize: 22
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: parent.modelData === "del"
                        icon: "backspace_outline"
                        size: 20
                        color: Theme.fgDim
                    }
                    Interactive {
                        radius: parent.radius
                        onClicked: {
                            for (const k of parent.modelData === "00" ? ["0", "0"] : [parent.modelData])
                                root.win.typeDigit(k);
                        }
                    }
                }
            }
        }
        Btn {
            Layout.fillWidth: true
            implicitHeight: 46
            icon: "play"
            text: "Start"
            fontSize: 15
            opacity: root.win && root.win.typedSecs() > 0 ? 1 : 0.4
            onClicked: root.win.startTyped()
        }
    }

    // ---- running / paused ----
    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: 20
        visible: !root.idle
        spacing: 18

        Item {
            id: ringBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real size: Math.min(width, height, 280)
            readonly property real frac: Chrono.d.timer.total > 0 ? Chrono.timerLeft / Chrono.d.timer.total : 0

            Shape {
                id: arc
                anchors.centerIn: parent
                width: parent.size
                height: parent.size
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.alpha(Theme.fg, 0.08)
                    strokeWidth: 10
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: arc.width / 2
                        centerY: arc.height / 2
                        radiusX: arc.width / 2 - 8
                        radiusY: radiusX
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
                ShapePath {
                    strokeColor: Chrono.timerPaused ? Theme.outline : Theme.primary
                    strokeWidth: 10
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: arc.width / 2
                        centerY: arc.height / 2
                        radiusX: arc.width / 2 - 8
                        radiusY: radiusX
                        startAngle: -90
                        sweepAngle: 360 * ringBox.frac
                    }
                }
            }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: Utils.hms(Math.ceil(Chrono.timerLeft / 1000))
                    font.family: Theme.display
                    font.pixelSize: 52
                    font.weight: Font.Light
                    font.features: { "tnum": 1 }
                }
                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: Chrono.timerPaused ? "Paused" : "Ends " + Chrono.fmtWhen(Chrono.d.timer.end)
                    font.pixelSize: 13
                    color: Theme.fgDim
                }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Btn {
                icon: "restart"
                text: "Reset"
                filled: false
                implicitHeight: 44
                onClicked: Chrono.timerReset()
            }
            Btn {
                icon: Chrono.timerRunning ? "pause" : "play"
                text: Chrono.timerRunning ? "Pause" : "Resume"
                implicitHeight: 44
                pad: 22
                onClicked: Chrono.timerPause()
            }
            Btn {
                text: "+1:00"
                filled: false
                implicitHeight: 44
                onClicked: Chrono.timerAdd(60000)
            }
        }
    }
}
