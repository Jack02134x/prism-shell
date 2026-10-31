import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Stopwatch with laps (Space starts / stops, L takes a lap). The fastest lap
// is marked in the accent colour, the slowest in red.
ColumnLayout {
    id: root

    property var win
    property real ms: Chrono.swElapsed
    readonly property var laps: Chrono.d.sw.laps
    readonly property real best: laps.length > 1 ? Math.min(...laps.map(l => l.split)) : -1
    readonly property real worst: laps.length > 1 ? Math.max(...laps.map(l => l.split)) : -1

    spacing: 14

    FrameAnimation {
        running: root.visible && Chrono.swRunning
        onTriggered: root.ms = Chrono.d.sw.acc + Date.now() - Chrono.d.sw.start
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 130
        Row {
            anchors.centerIn: parent
            readonly property string full: Utils.hmsc(root.ms)
            Txt {
                text: parent.full.slice(0, -3)
                font.family: Theme.display
                font.pixelSize: 72
                font.weight: Font.Light
                font.features: { "tnum": 1 }
            }
            Txt {
                y: 34
                text: parent.full.slice(-3)
                font.family: Theme.display
                font.pixelSize: 32
                font.weight: Font.Light
                font.features: { "tnum": 1 }
                color: Theme.fgDim
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        spacing: 10
        Btn {
            Layout.fillWidth: true
            implicitHeight: 46
            icon: Chrono.swRunning ? "flag_outline" : "restart"
            text: Chrono.swRunning ? "Lap" : "Reset"
            filled: false
            opacity: Chrono.swRunning || Chrono.d.sw.acc > 0 ? 1 : 0.4
            onClicked: Chrono.swRunning ? Chrono.swLap() : Chrono.swReset()
        }
        Btn {
            Layout.fillWidth: true
            implicitHeight: 46
            icon: Chrono.swRunning ? "pause" : "play"
            text: Chrono.swRunning ? "Stop" : (Chrono.d.sw.acc > 0 ? "Resume" : "Start")
            accent: Chrono.swRunning ? Theme.error : Theme.primary
            onClicked: Chrono.swToggle()
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        Layout.bottomMargin: 8
        clip: true
        model: root.laps
        spacing: 2
        delegate: RowLayout {
            id: lap
            required property var modelData
            required property int index
            readonly property color tint: modelData.split === root.best ? Theme.primary : modelData.split === root.worst ? Theme.error : Theme.fg
            width: ListView.view.width
            height: 40
            Txt {
                Layout.preferredWidth: 70
                text: "Lap " + (root.laps.length - lap.index)
                font.pixelSize: 13
                color: Theme.fgDim
            }
            Txt {
                Layout.fillWidth: true
                text: "+" + Utils.hmsc(lap.modelData.split)
                font.family: Theme.mono
                font.pixelSize: 14
                color: lap.tint
            }
            Txt {
                text: Utils.hmsc(lap.modelData.total)
                font.family: Theme.mono
                font.pixelSize: 14
            }
        }
        Txt {
            anchors.centerIn: parent
            visible: root.laps.length === 0
            text: "Space starts and stops · L takes a lap"
            font.pixelSize: 12
            color: Theme.fgDim
        }
    }
}
