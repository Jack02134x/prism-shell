import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// KDE Connect phone: battery ring + ring / ping / send clipboard / send file.
Card {
    id: root

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Ring {
            Layout.preferredWidth: 62
            Layout.preferredHeight: 62
            value: Phone.battery >= 0 ? Phone.battery / 100 : 0
            thickness: 6
            color: Phone.charging ? "#7dee9b" : Theme.accent(5)
            Column {
                anchors.centerIn: parent
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: Phone.charging ? "battery_charging" : "cellphone"
                    size: 16
                    color: Theme.accent(5)
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Phone.battery >= 0 ? Phone.battery + "%" : "—"
                    font.pixelSize: 10
                    font.weight: Font.Black
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Txt {
                Layout.fillWidth: true
                text: Phone.available ? Phone.name : "No phone"
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Txt {
                Layout.fillWidth: true
                text: Phone.available ? "KDE Connect · reachable" : "Pair a device with KDE Connect"
                font.pixelSize: 10
                color: Theme.fgDim
            }
            RowLayout {
                spacing: 4
                enabled: Phone.available
                opacity: enabled ? 1 : 0.4
                IconBtn {
                    icon: "phone_ring"
                    size: 30
                    iconSize: 15
                    idleColor: Theme.alpha(Theme.accent(0), 0.15)
                    iconColor: Theme.accent(0)
                    tooltip: "Ring (find my phone)"
                    tipAbove: true
                    onClicked: Phone.ring()
                }
                IconBtn {
                    icon: "hand_wave"
                    size: 30
                    iconSize: 15
                    idleColor: Theme.alpha(Theme.accent(2), 0.15)
                    iconColor: Theme.accent(2)
                    tooltip: "Ping"
                    tipAbove: true
                    onClicked: Phone.ping()
                }
                IconBtn {
                    icon: "content_paste"
                    size: 30
                    iconSize: 15
                    idleColor: Theme.alpha(Theme.accent(4), 0.15)
                    iconColor: Theme.accent(4)
                    tooltip: "Send clipboard"
                    tipAbove: true
                    onClicked: Phone.sendClipboard()
                }
                IconBtn {
                    icon: "file_send"
                    size: 30
                    iconSize: 15
                    idleColor: Theme.alpha(Theme.accent(6), 0.15)
                    iconColor: Theme.accent(6)
                    tooltip: "Send a file"
                    tipAbove: true
                    onClicked: Phone.sendFile()
                }
            }
        }
    }
}
