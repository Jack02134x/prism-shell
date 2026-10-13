pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets

// Big drop-down dashboard with a tab rail. Pages load lazily the first time
// they are shown and know when they're active (to start/stop polling).
Overlay {
    id: win

    name: "dashboard"
    open: Panels.dashboard
    scrimOpacity: 0.35
    openDuration: Motion.slower
    onDismiss: Panels.dashboard = false

    readonly property var tabs: [
        { name: "Home", icon: "view_dashboard", src: "HomeTab.qml" },
        { name: "Media", icon: "music", src: "MediaTab.qml" },
        { name: "System", icon: "chart_areaspline", src: "SystemTab.qml" },
        { name: "Screen", icon: "timer_outline", src: "ScreenTimeTab.qml" },
        { name: "Network", icon: "wifi", src: "NetworkTab.qml" },
        { name: "Audio", icon: "tune_variant", src: "AudioTab.qml" },
        { name: "Settings", icon: "cog", src: "SettingsTab.qml" }
    ]
    property int tab: Panels.dashboardTab
    property int prevTab: 0
    onTabChanged: Panels.dashboardTab = tab

    Connections {
        target: Panels
        function onDashboardTabChanged() {
            if (win.tab !== Panels.dashboardTab) {
                win.prevTab = win.tab;
                win.tab = Panels.dashboardTab;
            }
        }
    }

    function go(i) {
        if (i === tab)
            return;
        prevTab = tab;
        tab = (i + tabs.length) % tabs.length;
    }

    onOpened: keys.forceActiveFocus()

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab && event.modifiers & Qt.ControlModifier)
                win.go(win.tab + 1);
            else if (event.key === Qt.Key_Backtab)
                win.go(win.tab - 1);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down)
                win.go(win.tab + 1);
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up)
                win.go(win.tab - 1);
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_7)
                win.go(event.key - Qt.Key_1);
            else
                return;
            event.accepted = true;
        }
    }

    // reveal: a clipping frame that grows downward from the island
    Item {
        id: reveal
        anchors.horizontalCenter: parent.horizontalCenter
        y: Config.bar.height + Config.bar.margin + 8
        width: panel.width + 40
        height: (panel.height + 40) * Math.min(1, win.progress * 1.15)
        clip: true

        Rectangle {
            id: panel
            x: 20
            y: 4
            width: Math.min(1260, win.width - 60)
            height: Math.min(760, win.height - reveal.y - 30)
            radius: Theme.r.xl
            gradient: TintGradient { alpha: 0.96; amount: 0.14 }
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.7)
            opacity: Math.min(1, win.progress * 1.6)
            transform: Translate { y: (1 - win.progress) * -40 }

            MouseArea {
                anchors.fill: parent
                onWheel: wheel => wheel.accepted = false
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                // ---- tab rail ----
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 86
                    radius: Theme.r.lg
                    color: Theme.alpha(Theme.surfaceContainer, 0.8)

                    Rectangle {
                        id: railIndicator
                        x: 8
                        width: parent.width - 16
                        height: 64
                        y: rail.y + win.tab * (64 + rail.spacing)
                        radius: 18
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.accent(win.tab * 2) }
                            GradientStop { position: 1; color: Theme.accent(win.tab * 2 + 2) }
                        }
                        Behavior on y { NumAnim { duration: Motion.slow; easing.bezierCurve: Motion.spatial } }
                    }

                    Column {
                        id: rail
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10
                        spacing: 6
                        Repeater {
                            model: win.tabs
                            Item {
                                id: tabBtn
                                required property var modelData
                                required property int index
                                readonly property bool current: win.tab === index
                                width: 70
                                height: 64
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        icon: tabBtn.modelData.icon
                                        size: tabBtn.current ? 22 : 20
                                        color: tabBtn.current ? Theme.on(Theme.accent(win.tab * 2)) : Theme.fgDim
                                        Behavior on size { NumAnim { easing.bezierCurve: Motion.spatialFast } }
                                    }
                                    Txt {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: tabBtn.modelData.name
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: tabBtn.current ? Theme.on(Theme.accent(win.tab * 2)) : Theme.fgDim
                                    }
                                }
                                Interactive {
                                    radius: 18
                                    onClicked: win.go(tabBtn.index)
                                }
                            }
                        }
                    }

                    Txt {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Ctrl+Tab"
                        font.pixelSize: 9
                        color: Theme.alpha(Theme.fgDim, 0.6)
                    }
                }

                // ---- pages ----
                Item {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Repeater {
                        model: win.tabs
                        Loader {
                            id: page
                            required property var modelData
                            required property int index
                            readonly property bool current: win.tab === index
                            property bool visited: false
                            onCurrentChanged: if (current) visited = true
                            Component.onCompleted: if (current) visited = true
                            anchors.fill: parent
                            active: visited
                            source: modelData.src
                            visible: opacity > 0.01
                            opacity: current ? 1 : 0
                            Behavior on opacity { NumAnim { duration: Motion.normal } }
                            transform: Translate {
                                y: page.current ? 0 : (page.index > win.tab ? 40 : -40)
                                Behavior on y { NumAnim { duration: Motion.slow; easing.bezierCurve: Motion.spatial } }
                            }
                            onLoaded: item.active = Qt.binding(() => page.current && win.open)
                        }
                    }
                }
            }
        }
    }
}
