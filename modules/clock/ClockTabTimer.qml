import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Timer (type a time on the keypad) or Intervals (steps that repeat).
ColumnLayout {
    id: root

    property var win
    spacing: 10

    Segmented {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        options: [{ id: "timer", label: "Timer" }, { id: "interval", label: "Intervals" }]
        current: Chrono.d.win.tmode
        onPicked: id => {
            Chrono.d.win.tmode = id;
            Chrono.touch();
        }
    }
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        sourceComponent: Chrono.d.win.tmode === "interval" ? ivPane : timerPane
    }
    Component {
        id: timerPane
        TimerPane {
            win: root.win
        }
    }
    Component {
        id: ivPane
        IntervalsPane {
            win: root.win
        }
    }
}
