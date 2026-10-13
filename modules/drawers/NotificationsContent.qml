pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets
import qs.modules.notifications

// Right drawer: date, calendar, notification history grouped by app.
ColumnLayout {
    id: root

    property bool active: false
    onActiveChanged: if (active) Notifs.unread = 0

    readonly property var groups: {
        const map = {};
        const order = [];
        for (const e of Notifs.list) {
            if (!map[e.appName]) {
                map[e.appName] = [];
                order.push(e.appName);
            }
            map[e.appName].push(e);
        }
        return order.map(k => ({ app: k, items: map[k] }));
    }

    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Column {
            Layout.fillWidth: true
            Txt {
                text: Qt.formatDate(clock.date, "dddd")
                font.pixelSize: 13
                font.weight: Font.Bold
                color: Theme.accent(2)
            }
            Txt {
                text: Qt.formatDate(clock.date, "d MMMM")
                font.pixelSize: 30
                font.weight: Font.Black
                font.family: Theme.display
            }
        }
        Column {
            Layout.alignment: Qt.AlignTop
            Txt {
                anchors.right: parent.right
                text: Qt.formatTime(clock.date, "HH:mm")
                font.pixelSize: 30
                font.weight: Font.Thin
                font.family: Theme.display
            }
            Txt {
                anchors.right: parent.right
                visible: Weather.ready
                text: Weather.tempText + " · " + Weather.desc
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }
    }

    Card {
        Layout.fillWidth: true
        implicitHeight: cal.implicitHeight + 28
        shown: root.active
        delay: 60
        Calendar {
            id: cal
            anchors.fill: parent
            anchors.margins: 14
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        SectionTitle {
            Layout.fillWidth: true
            icon: "bell"
            text: "Notifications" + (Notifs.count > 0 ? "  " + Notifs.count : "")
            accent: Theme.accent(7)
        }
        Btn {
            icon: "bell_sleep"
            text: "DND"
            filled: Notifs.dnd
            accent: Theme.accent(7)
            implicitHeight: 30
            fontSize: 12
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        Btn {
            icon: "broom"
            text: "Clear"
            filled: false
            implicitHeight: 30
            fontSize: 12
            enabled: Notifs.count > 0
            opacity: enabled ? 1 : 0.4
            onClicked: Notifs.clear()
        }
    }

    Rectangle {
        visible: Notifs.foreignDaemon
        Layout.fillWidth: true
        implicitHeight: warn.implicitHeight + 16
        radius: Theme.r.md
        color: Theme.alpha(Theme.tertiary, 0.14)
        Txt {
            id: warn
            anchors.fill: parent
            anchors.margins: 8
            wrapMode: Text.Wrap
            font.pixelSize: 11
            color: Theme.tertiary
            text: "swaync is running, so app notifications go there. Stop swaync (and drop it from autostart) to receive them here."
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 14
        model: ScriptModel {
            values: root.groups
        }

        delegate: ColumnLayout {
            id: group
            required property var modelData
            required property int index
            width: list.width
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: Theme.accentFor(group.modelData.app)
                }
                Txt {
                    Layout.fillWidth: true
                    text: group.modelData.app + "  ·  " + group.modelData.items.length
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }
                IconBtn {
                    icon: "close"
                    size: 24
                    iconSize: 12
                    tooltip: "Clear group"
                    onClicked: group.modelData.items.slice().forEach(e => e.dismiss())
                }
            }

            Repeater {
                model: group.modelData.items.slice(0, 6)
                NotifCard {
                    required property var modelData
                    Layout.fillWidth: true
                    entry: modelData
                    compact: true
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: Notifs.count === 0
            spacing: 10
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: Notifs.dnd ? "bell_sleep" : "bell_check_outline"
                size: 54
                color: Theme.alpha(Theme.accent(7), 0.6)
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All caught up"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.fgDim
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
