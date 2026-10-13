import QtQuick
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// Focused window: icon + marquee title. Slides when the window changes.
Item {
    id: root

    property real maxWidth: 280
    readonly property string cls: Hypr.activeClass
    readonly property bool hasWindow: Hypr.activeTitle !== "" && (Hypr.focusedWorkspace?.toplevels.values.length ?? 1) > 0
    readonly property string title: hasWindow ? Hypr.activeTitle : "Workspace " + Hypr.activeId

    implicitWidth: Math.min(maxWidth, icon.width + 8 + label.implicitWidth)
    implicitHeight: 28
    clip: true

    // slide only when focus moves to another window; apps like VS Code rewrite
    // their title constantly and re-animating each time costs full-rate redraws
    readonly property var win: Hypr.activeWindow ?? Hypr.activeWayland
    onWinChanged: swap.restart()

    AppIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        size: 18
        source: root.hasWindow ? Hypr.iconFor(root.cls) : ""
        visible: root.hasWindow
        width: visible ? 18 : 0
    }

    Marquee {
        id: label
        anchors.left: icon.right
        anchors.leftMargin: root.hasWindow ? 8 : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        pixelSize: 13
        weight: Font.Medium
        color: Theme.fg
        speed: 40
        hoverOnly: true
        hovered: titleHover.hovered
    }

    HoverHandler {
        id: titleHover
    }

    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: label; property: "opacity"; to: 0; duration: 90 }
            NumberAnimation { target: label; property: "anchors.verticalCenterOffset"; to: -8; duration: 90 }
        }
        PropertyAction { target: label; property: "anchors.verticalCenterOffset"; value: 8 }
        ParallelAnimation {
            NumberAnimation { target: label; property: "opacity"; to: 1; duration: 260 }
            NumberAnimation { target: label; property: "anchors.verticalCenterOffset"; to: 0; duration: 340; easing.type: Easing.OutBack }
        }
    }
}
