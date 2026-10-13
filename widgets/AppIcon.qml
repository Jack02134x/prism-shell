import QtQuick
import Quickshell.Widgets
import qs.common

// App icon from the icon theme, falling back to a glyph when the theme has none.
Item {
    id: root

    property string source: ""
    property real size: 18
    property string fallback: "application"
    property color fallbackColor: Theme.fgDim

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        anchors.fill: parent
        source: root.source
        visible: root.source !== "" && status !== Image.Error
        asynchronous: true
    }
    Icon {
        anchors.centerIn: parent
        visible: !img.visible
        icon: root.fallback
        size: root.size * 0.9
        color: root.fallbackColor
        bounce: false
    }
}
