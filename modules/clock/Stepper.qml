import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets

// − value +  (the mouse wheel works too)
RowLayout {
    id: root

    property string text: ""
    property real textWidth: 84
    signal step(int delta)

    spacing: 4
    IconBtn {
        icon: "minus"
        size: 32
        idleColor: Theme.alpha(Theme.fg, 0.06)
        onClicked: root.step(-1)
    }
    Txt {
        Layout.preferredWidth: root.textWidth
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        font.pixelSize: 14
        font.weight: Font.DemiBold
        WheelHandler {
            onWheel: e => root.step(e.angleDelta.y > 0 ? 1 : -1)
        }
    }
    IconBtn {
        icon: "plus"
        size: 32
        idleColor: Theme.alpha(Theme.fg, 0.06)
        onClicked: root.step(1)
    }
}
