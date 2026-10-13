pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// One workspace (or special workspace) card in the overview.
Item {
    id: card

    required property var win

    property var target: 1          // workspace id, or "special:<name>"
    property var ws: null
    property string label: ""
    property string badge: ""
    property string badgeIcon: ""
    property color accent: Theme.primary
    property bool isSpecial: false
    property bool selected: false
    property bool current: false
    property int order: 0
    readonly property var windows: ws?.toplevels.values ?? []
    readonly property string specialName: isSpecial ? String(target).replace("special:", "") : ""

    Layout.preferredWidth: win.cardW
    Layout.preferredHeight: win.cardH + 26

    opacity: 0
    transform: Translate { id: cardT; y: 30 }
    Connections {
        target: win
        function onOpened() {
            card.opacity = 0;
            cardT.y = 30;
            cardIn.restart();
        }
    }
    Component.onCompleted: cardIn.start()
    SequentialAnimation {
        id: cardIn
        PauseAnimation { duration: card.order * 28 }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: Motion.normal }
            NumberAnimation { target: cardT; property: "y"; to: 0; duration: Motion.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatial }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        height: 20
        spacing: 6
        Rectangle {
            implicitWidth: badgeRow.implicitWidth + 10
            implicitHeight: 18
            radius: 6
            color: card.accent
            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 3
                Icon {
                    visible: card.badgeIcon !== ""
                    icon: card.badgeIcon
                    size: 11
                    color: Theme.on(card.accent)
                    bounce: false
                }
                Txt {
                    visible: card.badge !== ""
                    text: card.badge
                    font.pixelSize: 11
                    font.weight: Font.Black
                    color: Theme.on(card.accent)
                }
            }
        }
        Txt {
            Layout.fillWidth: true
            text: card.label + (card.label !== "" ? "  ·  " : "") + (card.windows.length > 0 ? card.windows.length + (card.windows.length === 1 ? " window" : " windows") : "empty")
            font.pixelSize: 11
            color: Theme.fgDim
        }
        Txt {
            visible: card.current
            text: card.isSpecial ? "open" : "current"
            font.pixelSize: 10
            font.weight: Font.Bold
            color: card.accent
        }
    }

    Rectangle {
        id: frame
        y: 26
        width: win.cardW
        height: win.cardH
        radius: 14
        color: Theme.surfaceLowest
        border.width: card.selected || drop.containsDrag ? 3 : (card.current ? 2 : 1)
        border.color: card.selected || drop.containsDrag ? card.accent : card.current ? Theme.alpha(card.accent, 0.7) : Theme.alpha(Theme.outline, 0.3)
        scale: drop.containsDrag ? 1.05 : (hover.hovered ? 1.02 : 1)
        Behavior on scale { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }

        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: frame.border.width
            radius: frame.radius - 2
            color: "transparent"

            Image {
                anchors.fill: parent
                source: Theme.wallpaperUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 400
                asynchronous: true
                opacity: card.isSpecial ? 0.25 : 0.55
            }
            // special workspaces: big faint glyph behind the windows
            Icon {
                visible: card.isSpecial
                anchors.centerIn: parent
                icon: card.badgeIcon
                size: Math.min(parent.width, parent.height) * 0.4
                color: Theme.alpha(card.accent, 0.25)
                bounce: false
            }

            Repeater {
                model: card.windows
                delegate: Item {
                    id: wnd
                    required property var modelData
                    readonly property var ipc: modelData.lastIpcObject ?? {}
                    readonly property var at: ipc.at ?? [win.monX + win.monW / 4, win.monY + win.monH / 4]
                    readonly property var size: ipc.size ?? [win.monW / 2, win.monH / 2]
                    readonly property bool match: win.matches(modelData)
                    readonly property string cls: Hypr.classOf(modelData)

                    x: (at[0] - win.monX) * win.scaleF
                    y: (at[1] - win.monY) * win.scaleF
                    width: Math.max(24, size[0] * win.scaleF)
                    height: Math.max(18, size[1] * win.scaleF)
                    z: ipc.floating ? 2 : 1
                    opacity: match ? 1 : 0.25
                    Behavior on opacity { NumAnim {} }

                    Drag.active: dragArea.drag.active
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    Drag.keys: ["prism-window"]

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Theme.surfaceHigh
                        border.width: wndHover.hovered ? 2 : 1
                        border.color: wndHover.hovered ? card.accent : Theme.alpha(Theme.outline, 0.5)
                        clip: true

                        ScreencopyView {
                            id: shot
                            anchors.fill: parent
                            anchors.margins: 1
                            captureSource: win.open ? (wnd.modelData.wayland ?? null) : null
                            live: win.open
                            visible: hasContent
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            size: Math.min(36, parent.height * 0.5)
                            source: Hypr.iconFor(wnd.cls)
                        }
                    }

                    HoverHandler {
                        id: wndHover
                    }
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        drag.target: wnd
                        onPressed: mouse => {
                            if (mouse.button === Qt.LeftButton)
                                win.dragging = wnd.modelData;
                        }
                        onPositionChanged: mouse => {
                            if (drag.active)
                                win.dragPos = mapToItem(win.contentRoot, mouse.x, mouse.y);
                        }
                        onReleased: {
                            if (drag.active) {
                                const dest = wnd.Drag.target;
                                wnd.Drag.drop();
                                if (dest && String(dest.wsTarget) !== String(card.target))
                                    Hypr.moveWindow(Hypr.addr(wnd.modelData), dest.wsTarget);
                                card.win.refreshLater();
                            }
                            win.dragging = null;
                            win.dragPos = Qt.point(0, 0);
                            wnd.x = Qt.binding(() => (wnd.at[0] - win.monX) * win.scaleF);
                            wnd.y = Qt.binding(() => (wnd.at[1] - win.monY) * win.scaleF);
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                Hypr.closeWindow(wnd.modelData);
                                card.win.refreshLater();
                            } else if (mouse.button === Qt.RightButton) {
                                // minimized -> restore; anything else -> minimize
                                if (card.isSpecial)
                                    Hypr.restore(wnd.modelData);
                                else
                                    Hypr.moveWindow(Hypr.addr(wnd.modelData), "special:minimize");
                                card.win.refreshLater();
                            } else {
                                Panels.overview = false;
                                Hypr.activate(wnd.modelData);
                            }
                        }
                    }
                    Tip {
                        text: wnd.modelData.title + (card.isSpecial ? "  ·  right-click to restore" : "")
                        show: wndHover.hovered && !dragArea.drag.active
                    }
                }
            }
        }

        HoverHandler {
            id: hover
        }
        TapHandler {
            onTapped: {
                Panels.overview = false;
                if (card.isSpecial)
                    Hypr.toggleSpecialSoon(card.specialName);
                else
                    Hypr.focusWorkspaceSoon(card.target);
            }
        }
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["prism-window"]
            property var wsTarget: card.target
        }
    }
}
