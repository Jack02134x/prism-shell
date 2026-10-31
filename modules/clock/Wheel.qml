import QtQuick
import qs.common
import qs.widgets

// A scroll wheel for picking a number (hours, minutes): drag, scroll or use
// the arrow keys. It loops.
PathView {
    id: root

    property int count: 60
    property var label: i => (i < 10 ? "0" : "") + i
    property real itemH: 42
    property real acc: 0
    signal moved(int index)

    implicitWidth: 86
    implicitHeight: itemH * 5
    model: count
    pathItemCount: 5
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange
    snapMode: PathView.SnapToItem
    clip: true
    focus: true
    onCurrentIndexChanged: moved(currentIndex)
    Keys.onUpPressed: decrementCurrentIndex()
    Keys.onDownPressed: incrementCurrentIndex()

    path: Path {
        startX: root.width / 2
        startY: 0
        PathLine {
            x: root.width / 2
            y: root.height
        }
    }

    delegate: Txt {
        required property int index
        width: root.width
        height: root.itemH
        horizontalAlignment: Text.AlignHCenter
        text: root.label(index)
        font.family: Theme.display
        font.pixelSize: PathView.isCurrentItem ? 30 : 20
        font.weight: PathView.isCurrentItem ? Font.Medium : Font.Light
        color: PathView.isCurrentItem ? Theme.fg : Theme.fgDim
        opacity: PathView.isCurrentItem ? 1 : 0.45
        Behavior on font.pixelSize { NumAnim { duration: Motion.fast } }
    }

    // touchpads send many small steps: add them up
    WheelHandler {
        onWheel: e => {
            root.acc += e.angleDelta.y;
            while (Math.abs(root.acc) >= 120) {
                root.acc > 0 ? root.decrementCurrentIndex() : root.incrementCurrentIndex();
                root.acc -= 120 * Math.sign(root.acc);
            }
        }
    }
}
