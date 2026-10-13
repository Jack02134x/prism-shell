pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// Window switcher: every window, most recently used first, with live
// previews. Opens on your previous window (alt-tab style).
// Keys: ←/→/Tab move · type to filter · Enter switch · Shift+Del close · Esc.
Overlay {
    id: win

    name: "switcher"
    open: Panels.switcher
    scrimOpacity: 0.45
    onDismiss: Panels.switcher = false
    onOpened: {
        Hypr.refresh();
        search.text = "";
        search.focusInput();
        selected = windows.length > 1 ? 1 : 0;
    }

    property int selected: 0
    readonly property string q: search.text.trim().toLowerCase()
    // most recently focused first (Hyprland's focusHistoryID: 0 = current)
    readonly property var windows: Hypr.realToplevels.filter(t => q === "" || (t.title + " " + Hypr.classOf(t)).toLowerCase().includes(q)).slice().sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 99) - (b.lastIpcObject?.focusHistoryID ?? 99))
    readonly property int cols: Math.min(5, Math.max(1, windows.length))
    readonly property real cardW: Math.min(300, (width - 200) / cols - 18)
    readonly property real cardH: cardW * 0.62

    onWindowsChanged: if (selected >= windows.length) selected = Math.max(0, windows.length - 1)

    function go(t) {
        if (!t)
            return;
        Panels.switcher = false;
        Hypr.activate(t);
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 22
        opacity: win.progress
        scale: 0.94 + 0.06 * win.progress

        InputField {
            id: search
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 420
            placeholder: win.windows.length + " windows · type to filter"
            icon: "dock_window"
            accent: Theme.accent(win.selected)
            horizontalNav: true
            onNavigate: (delta, vertical) => {
                const n = win.windows.length;
                if (n === 0)
                    return;
                const step = vertical ? delta * win.cols : delta;
                win.selected = ((win.selected + step) % n + n) % n;
            }
            onAccepted: win.go(win.windows[win.selected])
            onDeleteRequested: {
                const t = win.windows[win.selected];
                if (t) {
                    Hypr.closeWindow(t);
                    refresh.restart();
                }
            }
        }

        Flickable {
            id: scroller
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: grid.implicitWidth + 24
            Layout.preferredHeight: Math.min(grid.implicitHeight + 24, win.height - 240)
            contentWidth: grid.implicitWidth + 24
            contentHeight: grid.implicitHeight + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: grid
            x: 12
            y: 12
            columns: win.cols
            rowSpacing: 18
            columnSpacing: 18

            Repeater {
                model: win.windows
                Item {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.selected
                    readonly property string cls: Hypr.classOf(modelData)
                    readonly property color accent: Theme.accent(index)
                    readonly property string wsName: String(modelData.workspace?.name ?? "?")

                    Layout.preferredWidth: win.cardW
                    Layout.preferredHeight: win.cardH + 44
                    scale: sel ? 1.06 : 1
                    z: sel ? 2 : 1
                    Behavior on scale { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }

                    Rectangle {
                        id: frame
                        width: parent.width
                        height: win.cardH
                        radius: 16
                        color: Theme.surfaceLowest
                        border.width: card.sel ? 3 : 1
                        border.color: card.sel ? card.accent : Theme.alpha(Theme.outline, 0.35)
                        Behavior on border.color { ColAnim {} }

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: frame.border.width
                            radius: 13
                            color: Theme.surfaceHigh
                            ScreencopyView {
                                id: shot
                                anchors.fill: parent
                                captureSource: win.open ? (card.modelData.wayland ?? null) : null
                                live: win.open && card.sel
                                visible: hasContent
                            }
                            AppIcon {
                                anchors.centerIn: parent
                                visible: !shot.hasContent
                                size: 48
                                source: Hypr.iconFor(card.cls)
                            }
                        }

                        // workspace badge
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            implicitWidth: wsTxt.implicitWidth + 12
                            implicitHeight: 20
                            radius: 10
                            color: card.wsName.startsWith("special:") ? Theme.tertiary : Theme.accent(Number(card.wsName) - 1)
                            Txt {
                                id: wsTxt
                                anchors.centerIn: parent
                                text: card.wsName.startsWith("special:") ? Hypr.specialLabel(card.wsName.slice(8)) : card.wsName
                                font.pixelSize: 10
                                font.weight: Font.Black
                                color: Theme.on(parent.color)
                            }
                        }
                    }

                    RowLayout {
                        anchors.top: frame.bottom
                        anchors.topMargin: 8
                        width: parent.width
                        spacing: 8
                        AppIcon {
                            size: 20
                            source: Hypr.iconFor(card.cls)
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: card.modelData.title
                            font.pixelSize: 12
                            font.weight: card.sel ? Font.Bold : Font.Medium
                            color: card.sel ? Theme.fg : Theme.fgDim
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onEntered: win.selected = card.index
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                Hypr.closeWindow(card.modelData);
                                refresh.restart();
                            } else {
                                win.go(card.modelData);
                            }
                        }
                    }
                }
            }
        }

        }

        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: "←/→ or Tab move  ·  type to filter  ·  Enter switch  ·  Shift+Del or middle-click closes"
            font.pixelSize: 11
            color: Qt.rgba(1, 1, 1, 0.6)
        }
    }

    Timer {
        id: refresh
        interval: 300
        onTriggered: Hypr.refresh()
    }
}
