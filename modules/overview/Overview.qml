pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// Exposé: workspaces with live window previews, special workspaces in their
// own column on the right. Click a window to focus it, drag it onto another
// card to move it (drop on "Minimized" to minimize), right-click to minimize
// or restore, middle-click to close.
// Keys: 1–9 / 0 go to workspace 1–10 · N your other special workspace · Space minimized
// · arrows + Enter · Esc.
Overlay {
    id: win

    name: "overview"
    open: Panels.overview
    scrimOpacity: 0.55
    onDismiss: Panels.overview = false
    onOpened: {
        Hypr.refresh();
        keys.forceActiveFocus();
        selected = Math.max(0, ids.indexOf(Hypr.activeId));
    }

    readonly property var mon: Hyprland.focusedMonitor
    readonly property real monW: mon?.width ?? 1920
    readonly property real monH: mon?.height ?? 1080
    readonly property real monX: mon?.x ?? 0
    readonly property real monY: mon?.y ?? 0
    // same rule as the bar: 1..N always, higher ones while they have windows
    readonly property var ids: {
        const set = {};
        for (let i = 1; i <= Config.bar.workspaces; i++)
            set[i] = true;
        for (const w of Hypr.workspaces)
            if (w.id > 0 && w.toplevels.values.length > 0)
                set[w.id] = true;
        if (Hypr.activeId > 0)
            set[Hypr.activeId] = true;
        return Object.keys(set).map(Number).sort((a, b) => a - b);
    }
    readonly property int cols: Math.min(4, Math.max(1, ids.length))
    readonly property real cardW: Math.min(330, (width - 260) / (cols + 1) - 24)
    readonly property real cardH: cardW * monH / monW
    readonly property real scaleF: cardW / monW
    readonly property string filter: ""
    property int selected: 0
    // N jumps to the first configured special workspace that isn't "minimize"
    readonly property string nSpecial: Config.bar.specials.find(s => s !== "minimize") ?? ""
    property var dragging: null
    property point dragPos: Qt.point(0, 0)

    function matches(t) {
        return filter === "" || (t.title + " " + Hypr.classOf(t)).toLowerCase().includes(filter);
    }
    function firstMatch() {
        return Hypr.toplevels.find(t => matches(t)) ?? null;
    }
    function goWorkspace(id) {
        Panels.overview = false;
        Hypr.focusWorkspaceSoon(id);
    }
    function goSpecial(name) {
        Panels.overview = false;
        Hypr.toggleSpecialSoon(name);
    }
    function refreshLater() {
        refreshTimer.left = 3;
        refreshTimer.restart();
    }

    // keyboard: number keys jump straight to a workspace
    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const k = event.key;
            if (k >= Qt.Key_1 && k <= Qt.Key_9)
                win.goWorkspace(k - Qt.Key_0);
            else if (k === Qt.Key_0)
                win.goWorkspace(10);
            else if (k === Qt.Key_N && win.nSpecial !== "")
                win.goSpecial(win.nSpecial);
            else if (k === Qt.Key_Space)
                win.goSpecial("minimize");
            else if (k === Qt.Key_Right || k === Qt.Key_Tab)
                win.selected = Utils.clamp(win.selected + 1, 0, win.ids.length - 1);
            else if (k === Qt.Key_Left || k === Qt.Key_Backtab)
                win.selected = Utils.clamp(win.selected - 1, 0, win.ids.length - 1);
            else if (k === Qt.Key_Down)
                win.selected = Utils.clamp(win.selected + win.cols, 0, win.ids.length - 1);
            else if (k === Qt.Key_Up)
                win.selected = Utils.clamp(win.selected - win.cols, 0, win.ids.length - 1);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                win.goWorkspace(win.ids[win.selected] ?? 1);
            else
                return;
            event.accepted = true;
        }
    }

    // ---------------------------------------------------------------- layout
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 22
        opacity: win.progress
        scale: 0.92 + 0.08 * win.progress

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 28

            GridLayout {
                Layout.alignment: Qt.AlignTop
                columns: win.cols
                rowSpacing: 20
                columnSpacing: 20

                Repeater {
                    model: win.ids
                    WsCard {
                        win: win
                        required property int modelData
                        required property int index
                        target: modelData
                        ws: Hypr.workspace(modelData)
                        badge: String(modelData)
                        accent: Theme.accent(modelData - 1)
                        current: modelData === Hypr.activeId
                        selected: index === win.selected
                        order: index
                    }
                }
            }

            // special workspaces column
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.fillHeight: true
                implicitWidth: 2
                radius: 1
                color: Theme.alpha(Theme.tertiary, 0.35)
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 20
                Txt {
                    text: "SPECIAL"
                    font.pixelSize: 11
                    font.weight: Font.Black
                    font.letterSpacing: 3
                    color: Theme.tertiary
                }
                Repeater {
                    model: Hypr.specialNames
                    WsCard {
                        win: win
                        required property string modelData
                        required property int index
                        isSpecial: true
                        target: "special:" + modelData
                        ws: Hypr.special(modelData)
                        label: Hypr.specialLabel(modelData) + (modelData === win.nSpecial ? "  [N]" : modelData === "minimize" ? "  [Space]" : "")
                        badgeIcon: Hypr.specialIcon(modelData)
                        accent: Theme.tertiary
                        current: Hypr.activeSpecial === modelData
                        order: index + 4
                    }
                }
            }
        }

        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: "1–9 / 0 workspace  ·  " + (win.nSpecial !== "" ? "N " + Hypr.specialLabel(win.nSpecial).toLowerCase() + "  ·  " : "") + "Space minimized  ·  drag windows between cards  ·  right-click minimizes / restores  ·  middle-click closes"
            font.pixelSize: 11
            color: Qt.rgba(1, 1, 1, 0.6)
        }
    }

    // floating ghost that follows the cursor while dragging a window
    Rectangle {
        visible: win.dragging !== null && win.dragPos.x > 0
        x: win.dragPos.x - width / 2
        y: win.dragPos.y - height / 2
        z: 100
        width: ghostRow.implicitWidth + 24
        height: 48
        radius: 24
        color: Theme.alpha(Theme.surface, 0.95)
        border.width: 2
        border.color: Theme.accent(0)
        RowLayout {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 8
            AppIcon {
                size: 26
                source: Hypr.iconFor(Hypr.classOf(win.dragging))
            }
            Txt {
                text: win.dragging?.title ?? ""
                Layout.maximumWidth: 260
                font.weight: Font.DemiBold
            }
        }
    }

    // Hyprland re-tiles a moment after a move; refresh twice to catch it
    Timer {
        id: refreshTimer
        property int left: 0
        interval: 250
        repeat: true
        onTriggered: {
            Hypr.refresh();
            if (--left <= 0)
                stop();
        }
    }
}
