import QtQuick
import qs.common
import qs.widgets

// A Material segmented control: options [{id, label}], one picked.
Rectangle {
    id: root

    property var options: []
    property string current: ""
    signal picked(string id)

    implicitHeight: 40
    radius: height / 2
    color: Theme.alpha(Theme.surfaceHighest, 0.6)

    readonly property int index: Math.max(0, options.findIndex(o => o.id === current))
    readonly property real cell: options.length ? (width - 8) / options.length : 0

    // the moving highlight
    Rectangle {
        x: 4 + root.cell * root.index
        y: 4
        width: root.cell
        height: root.height - 8
        radius: height / 2
        color: Theme.primary
        Behavior on x { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
    }
    Row {
        x: 4
        y: 4
        Repeater {
            model: root.options
            Item {
                required property var modelData
                required property int index
                width: root.cell
                height: root.height - 8
                Txt {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: parent.index === root.index ? Theme.on(Theme.primary) : Theme.fgDim
                    Behavior on color { ColAnim {} }
                }
                Interactive {
                    radius: height / 2
                    onClicked: root.picked(parent.modelData.id)
                }
            }
        }
    }
}
