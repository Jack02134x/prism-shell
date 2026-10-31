import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets

// A settings line: label (+ hint) on the left, a control on the right.
RowLayout {
    id: root

    property string label: ""
    property string hint: ""
    default property alias control: slot.data

    spacing: 12
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Txt {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: 14
        }
        Txt {
            Layout.fillWidth: true
            visible: root.hint !== ""
            text: root.hint
            font.pixelSize: 11
            color: Theme.fgDim
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }
    Item {
        id: slot
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
