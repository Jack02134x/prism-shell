import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// The panel that slides up over the tab for editors and settings.
Rectangle {
    id: root

    property var win
    property bool open: false

    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.min(parent.height - 40, (loader.item?.implicitHeight ?? 200) + 40)
    y: open ? parent.height - height : parent.height + 10
    visible: y < parent.height
    radius: Theme.r.xl
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.alpha(Theme.grad1, 0.25)
    Behavior on y { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.decel } }

    // the grab handle
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        width: 36
        height: 4
        radius: 2
        color: Theme.alpha(Theme.fg, 0.25)
    }
    MouseArea {
        anchors.fill: parent
        onWheel: {}
    }
    Flickable {
        anchors.fill: parent
        anchors.topMargin: 24
        anchors.bottomMargin: 16
        contentHeight: loader.item?.implicitHeight ?? 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Loader {
            id: loader
            x: 20
            width: parent.width - 40
            active: root.win.sheet !== ""
            // keep showing the last one while it slides away
            property string name: ""
            source: name !== "" ? "Sheet" + name.charAt(0).toUpperCase() + name.slice(1) + ".qml" : ""
            onLoaded: item.win = root.win
            Connections {
                target: root.win
                function onSheetChanged() {
                    if (root.win.sheet !== "")
                        loader.name = root.win.sheet;
                }
            }
        }
    }
}
