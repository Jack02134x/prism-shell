import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets

// Quick-settings tile: morphs from a rounded square to a squircle filled with
// its accent when on. Right-click / long label for a secondary action.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool checked: false
    property color accent: Theme.primary

    signal clicked
    signal rightClicked

    implicitHeight: 74
    radius: checked ? 26 : 16
    color: checked ? accent : Theme.alpha(Theme.fg, 0.06)
    border.width: checked ? 0 : 1
    border.color: Theme.alpha(Theme.outline, 0.25)
    scale: ia.pressed ? 0.93 : 1

    Behavior on radius { NumAnim { duration: Motion.slow; easing.bezierCurve: Motion.spatial } }
    Behavior on color { ColAnim { duration: Motion.normal } }
    Behavior on scale { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 11
        spacing: 2
        Icon {
            icon: root.icon
            size: 21
            color: root.checked ? Theme.on(root.accent) : root.accent
            Layout.alignment: Qt.AlignLeft
        }
        Item { Layout.fillHeight: true }
        Txt {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: 12
            font.weight: Font.Bold
            color: root.checked ? Theme.on(root.accent) : Theme.fg
        }
        Txt {
            Layout.fillWidth: true
            visible: root.sub !== ""
            text: root.sub
            font.pixelSize: 10
            color: root.checked ? Theme.alpha(Theme.on(root.accent), 0.75) : Theme.fgDim
        }
    }

    Interactive {
        id: ia
        radius: root.radius
        tint: root.checked ? Theme.on(root.accent) : root.accent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
