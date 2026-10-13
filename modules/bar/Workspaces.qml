pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// Workspace strip with a liquid indicator: the leading edge races ahead and
// the trailing edge catches up, so it stretches like a droplet.
Item {
    id: root

    property var monitor: null
    readonly property int activeId: monitor?.activeWorkspace?.id ?? Hypr.activeId
    // 1..N always shown; beyond N only workspaces that have windows (or are focused)
    readonly property var ids: {
        const set = {};
        for (let i = 1; i <= Config.bar.workspaces; i++)
            set[i] = true;
        for (const w of Hypr.workspaces)
            if (w.id > 0 && w.toplevels.values.length > 0)
                set[w.id] = true;
        if (activeId > 0)
            set[activeId] = true;
        return Object.keys(set).map(Number).sort((a, b) => a - b);
    }
    property int dir: 1
    property int lastId: 1

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    function sync() {
        const it = rep.itemAt((ids ?? []).indexOf(activeId));
        if (!it)
            return;
        indicator.l = it.x;
        indicator.r = it.x + it.width;
    }

    onActiveIdChanged: {
        dir = activeId >= lastId ? 1 : -1;
        lastId = activeId;
        sync();
    }

    // liquid indicator
    Rectangle {
        id: indicator
        property real l: 0
        property real r: 30
        x: l
        width: Math.max(8, r - l)
        height: 28
        anchors.verticalCenter: parent.verticalCenter
        radius: 14
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accent(root.activeId - 1) }
            GradientStop { position: 1; color: Theme.accent(root.activeId + 1) }
        }
        Behavior on l { NumAnim { duration: root.dir > 0 ? 520 : 240; easing.bezierCurve: Motion.spatial } }
        Behavior on r { NumAnim { duration: root.dir > 0 ? 240 : 520; easing.bezierCurve: Motion.spatial } }

        // soft glow under the indicator
        Rectangle {
            z: -1
            anchors.centerIn: parent
            width: parent.width + 10
            height: parent.height + 8
            radius: height / 2
            color: Theme.alpha(Theme.accent(root.activeId - 1), 0.25)
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            id: rep
            model: root.ids
            onCountChanged: Qt.callLater(root.sync)

            delegate: Item {
                id: ws
                required property int modelData
                required property int index
                readonly property int wsId: modelData
                readonly property var workspace: Hypr.workspaces.find(w => w.id === wsId) ?? null
                readonly property var windows: workspace?.toplevels.values ?? []
                readonly property bool occupied: windows.length > 0
                readonly property bool active: wsId === root.activeId
                readonly property bool urgent: workspace?.urgent ?? false
                readonly property color accent: Theme.accent(wsId - 1)
                // keyed on a string so the icon row only rebuilds when the apps change,
                // not on every window-title update
                readonly property string classKey: {
                    const seen = [];
                    for (const t of windows) {
                        const c = Hypr.classOf(t);
                        if (c !== "" && !seen.includes(c))
                            seen.push(c);
                    }
                    return seen.slice(0, 3).join("\n");
                }
                readonly property var classes: classKey === "" ? [] : classKey.split("\n")
                readonly property bool showIcons: Config.bar.workspaceIcons && classes.length > 0

                width: showIcons ? classes.length * 19 + 13 : (active ? 40 : 26)
                height: 28
                onXChanged: if (active) root.sync()
                onWidthChanged: if (active) root.sync()
                onActiveChanged: if (active) root.sync()

                Behavior on width { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }

                // hover halo
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: ws.accent
                    opacity: hover.hovered && !ws.active ? 0.16 : 0
                    Behavior on opacity { NumAnim { duration: Motion.fast } }
                }

                // urgent pulse
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.error
                    visible: ws.urgent
                    SequentialAnimation on opacity {
                        running: ws.urgent
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 450 }
                        NumberAnimation { to: 1; duration: 450 }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    visible: ws.showIcons
                    Repeater {
                        model: ws.classes
                        AppIcon {
                            required property string modelData
                            size: 16
                            source: Hypr.iconFor(modelData)
                            fallbackColor: ws.active ? Theme.on(ws.accent) : ws.accent
                            opacity: ws.active ? 1 : 0.85
                            scale: hover.hovered ? 1.15 : 1
                            Behavior on scale { NumAnim { duration: Motion.fast; easing.bezierCurve: Motion.spatialFast } }
                        }
                    }
                }

                // empty workspace: dot, or the number when active
                Rectangle {
                    visible: !ws.showIcons
                    anchors.centerIn: parent
                    width: ws.active ? 0 : (ws.occupied ? 9 : 6)
                    height: width
                    radius: width / 2
                    color: ws.occupied ? ws.accent : Theme.alpha(Theme.fgDim, 0.5)
                    Behavior on width { NumAnim { easing.bezierCurve: Motion.spatialFast } }
                }
                Txt {
                    visible: !ws.showIcons
                    anchors.centerIn: parent
                    text: ws.wsId
                    font.pixelSize: 12
                    font.weight: Font.Black
                    font.family: Theme.mono
                    color: Theme.on(ws.accent)
                    opacity: ws.active ? 1 : 0
                    scale: ws.active ? 1 : 0.4
                    Behavior on opacity { NumAnim {} }
                    Behavior on scale { NumAnim { easing.bezierCurve: Motion.spatialFast } }
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: Hypr.focusWorkspace(ws.wsId)
                }
                Tip {
                    text: ws.occupied ? ws.wsId + " · " + ws.windows.map(t => Hypr.appName(Hypr.classOf(t))).join(", ") : ""
                    show: hover.hovered
                }
            }
        }

        // special workspaces (configured ones always, others while they have windows)
        Repeater {
            model: Hypr.specialNames
            delegate: Rectangle {
                id: sp
                required property string modelData
                readonly property var ws: Hypr.special(modelData)
                readonly property var windows: ws?.toplevels.values ?? []
                readonly property bool open: Hypr.activeSpecial === modelData
                readonly property color accent: Theme.tertiary
                readonly property string classKey: {
                    const seen = [];
                    for (const t of windows) {
                        const c = Hypr.classOf(t);
                        if (c !== "" && !seen.includes(c))
                            seen.push(c);
                    }
                    return seen.slice(0, 2).join("\n");
                }
                width: spRow.implicitWidth + 16
                height: 26
                anchors.verticalCenter: parent?.verticalCenter
                radius: open ? 9 : 13
                color: open ? accent : Theme.alpha(accent, spHover.hovered ? 0.28 : (windows.length > 0 ? 0.16 : 0.06))
                border.width: 1
                border.color: Theme.alpha(accent, open ? 1 : 0.45)
                Behavior on radius { NumAnim { easing.bezierCurve: Motion.spatial } }
                Behavior on color { ColAnim {} }

                Row {
                    id: spRow
                    anchors.centerIn: parent
                    spacing: 4
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Hypr.specialIcon(sp.modelData)
                        size: 13
                        color: sp.open ? Theme.on(sp.accent) : sp.accent
                    }
                    Repeater {
                        model: sp.classKey === "" ? [] : sp.classKey.split("\n")
                        AppIcon {
                            required property string modelData
                            size: 14
                            source: Hypr.iconFor(modelData)
                        }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sp.windows.length > 2 || sp.windows.length === 0
                        text: sp.windows.length
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: sp.open ? Theme.on(sp.accent) : sp.accent
                    }
                }
                HoverHandler {
                    id: spHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: Hypr.toggleSpecial(sp.modelData)
                }
                Tip {
                    text: Hypr.specialLabel(sp.modelData) + (sp.windows.length > 0 ? " · " + sp.windows.map(t => Hypr.appName(Hypr.classOf(t))).join(", ") : " · empty")
                    show: spHover.hovered
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Hypr.focusWorkspace(event.angleDelta.y > 0 ? "e-1" : "e+1")
    }

    Component.onCompleted: Qt.callLater(sync)
}
