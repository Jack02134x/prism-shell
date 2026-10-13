pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Wi-Fi networks (connect with password inline) and Bluetooth devices.
Item {
    id: root

    property bool active: false
    property var pwFor: null

    onActiveChanged: {
        Net.scan(active);
        BT.scan(active);
    }
    Component.onDestruction: {
        Net.scan(false);
        BT.scan(false);
    }

    RowLayout {
        anchors.fill: parent
        spacing: 14

        // ================= Wi-Fi =================
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    SectionTitle {
                        Layout.fillWidth: true
                        icon: Net.icon
                        text: "Wi-Fi"
                        accent: Theme.accent(0)
                    }
                    Icon {
                        visible: Net.wifiEnabled
                        icon: "radar"
                        size: 16
                        color: Theme.accent(0)
                        RotationAnimation on rotation {
                            running: root.active && Net.wifiEnabled
                            from: 0
                            to: 360
                            duration: 2400
                            loops: Animation.Infinite
                        }
                    }
                    StyledSwitch {
                        checked: Net.wifiEnabled
                        accent: Theme.accent(0)
                        onToggled: Net.toggleWifi()
                    }
                }

                Rectangle {
                    visible: Net.wiredUp
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Theme.r.md
                    color: Theme.alpha(Theme.accent(2), 0.15)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Icon {
                            icon: "ethernet"
                            color: Theme.accent(2)
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: "Ethernet connected"
                            font.weight: Font.DemiBold
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: Net.wifiEnabled ? Net.networks : []

                    delegate: Rectangle {
                        id: net
                        required property var modelData
                        required property int index
                        readonly property bool expanded: root.pwFor === modelData
                        width: ListView.view.width
                        implicitHeight: expanded ? 104 : 56
                        radius: Theme.r.md
                        color: modelData.connected ? Theme.alpha(Theme.accent(0), 0.2) : Theme.alpha(Theme.fg, 0.04)
                        border.width: modelData.connected ? 1 : 0
                        border.color: Theme.alpha(Theme.accent(0), 0.6)
                        clip: true
                        Behavior on implicitHeight { NumAnim { easing.bezierCurve: Motion.spatial } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Icon {
                                    icon: Net.iconOf(net.modelData)
                                    size: 20
                                    color: net.modelData.connected ? Theme.accent(0) : Theme.fg
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Txt {
                                        Layout.fillWidth: true
                                        text: net.modelData.name
                                        font.weight: Font.DemiBold
                                    }
                                    Txt {
                                        text: (net.modelData.connected ? "Connected" : net.modelData.stateChanging ? "Connecting…" : net.modelData.known ? "Saved" : "") + (Net.secured(net.modelData) ? "  🔒" : "") + "  " + Math.round(Net.strengthOf(net.modelData) * 100) + "%"
                                        font.pixelSize: 10
                                        color: Theme.fgDim
                                    }
                                }
                                Btn {
                                    visible: net.modelData.known && !net.modelData.connected
                                    text: "Forget"
                                    filled: false
                                    implicitHeight: 28
                                    fontSize: 11
                                    onClicked: net.modelData.forget()
                                }
                                Btn {
                                    text: net.modelData.connected ? "Disconnect" : "Connect"
                                    filled: !net.modelData.connected
                                    accent: Theme.accent(0)
                                    implicitHeight: 28
                                    fontSize: 11
                                    onClicked: {
                                        if (net.modelData.connected)
                                            net.modelData.disconnect();
                                        else if (!net.modelData.known && Net.secured(net.modelData))
                                            root.pwFor = net.expanded ? null : net.modelData;
                                        else
                                            Net.connectTo(net.modelData, "");
                                    }
                                }
                            }
                            RowLayout {
                                visible: net.expanded
                                Layout.fillWidth: true
                                InputField {
                                    id: pw
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    icon: "key"
                                    password: true
                                    placeholder: "Password for " + net.modelData.name
                                    fontSize: 13
                                    onVisibleChanged: if (visible) focusInput()
                                    onAccepted: {
                                        Net.connectTo(net.modelData, pw.text);
                                        root.pwFor = null;
                                    }
                                }
                                Btn {
                                    icon: "arrow_right"
                                    accent: Theme.accent(0)
                                    implicitHeight: 36
                                    onClicked: {
                                        Net.connectTo(net.modelData, pw.text);
                                        root.pwFor = null;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ================= Bluetooth =================
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active
            delay: 80

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    SectionTitle {
                        Layout.fillWidth: true
                        icon: BT.icon
                        text: "Bluetooth"
                        accent: Theme.accent(6)
                    }
                    Txt {
                        visible: BT.discovering
                        text: "scanning…"
                        font.pixelSize: 11
                        color: Theme.accent(6)
                        SequentialAnimation on opacity {
                            running: BT.discovering && root.active
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600 }
                            NumberAnimation { to: 1; duration: 600 }
                        }
                    }
                    StyledSwitch {
                        checked: BT.enabled
                        accent: Theme.accent(6)
                        onToggled: BT.toggle()
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: BT.enabled ? BT.devices.filter(d => d.paired || d.name) : []

                    delegate: Rectangle {
                        id: dev
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        implicitHeight: 56
                        radius: Theme.r.md
                        color: modelData.connected ? Theme.alpha(Theme.accent(6), 0.2) : Theme.alpha(Theme.fg, 0.04)
                        border.width: modelData.connected ? 1 : 0
                        border.color: Theme.alpha(Theme.accent(6), 0.6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            Icon {
                                icon: BT.deviceIcon(dev.modelData)
                                size: 20
                                color: dev.modelData.connected ? Theme.accent(6) : Theme.fg
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Txt {
                                    Layout.fillWidth: true
                                    text: dev.modelData.name || dev.modelData.address
                                    font.weight: Font.DemiBold
                                }
                                Txt {
                                    text: (dev.modelData.connected ? "Connected" : dev.modelData.pairing ? "Pairing…" : dev.modelData.paired ? "Paired" : "Available") + (dev.modelData.batteryAvailable ? "  ·  " + Math.round(dev.modelData.battery * 100) + "% battery" : "")
                                    font.pixelSize: 10
                                    color: Theme.fgDim
                                }
                            }
                            IconBtn {
                                visible: dev.modelData.paired
                                icon: "trash_can_outline"
                                size: 28
                                iconSize: 14
                                iconColor: Theme.error
                                tooltip: "Forget"
                                onClicked: dev.modelData.forget()
                            }
                            Btn {
                                text: dev.modelData.connected ? "Disconnect" : dev.modelData.paired ? "Connect" : "Pair"
                                filled: !dev.modelData.connected
                                accent: Theme.accent(6)
                                implicitHeight: 28
                                fontSize: 11
                                onClicked: BT.act(dev.modelData)
                            }
                        }
                    }
                }

                Txt {
                    visible: !BT.available
                    text: "No Bluetooth adapter"
                    color: Theme.fgDim
                }
            }
        }
    }
}
