pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import qs.common
import qs.services
import qs.widgets

// Optional polkit agent (config.json "polkit.enabled"; stop hyprpolkitagent first).
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow

    Overlay {
        id: win
        name: "polkit"
        open: agent.isActive && root.flow !== null
        scrimOpacity: 0.6
        closeOnScrim: false
        onDismiss: root.flow?.cancelAuthenticationRequest()
        onOpened: pw.focusInput()

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 460
            height: col.implicitHeight + 44
            radius: Theme.r.xl
            gradient: TintGradient { alpha: 0.97; amount: 0.14 }
            opacity: win.progress
            scale: 0.9 + 0.1 * win.progress

            GlowBorder {
                z: -1
                radius: card.radius
                pad: 16
                glow: 0.6
                speed: 5
                c1: Theme.accent(0)
                c2: Theme.accent(6)
            }

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                RowLayout {
                    spacing: 14
                    Rectangle {
                        implicitWidth: 52
                        implicitHeight: 52
                        radius: 16
                        color: Theme.alpha(Theme.accent(0), 0.2)
                        Icon {
                            anchors.centerIn: parent
                            icon: "shield_lock"
                            size: 28
                            color: Theme.accent(0)
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Txt {
                            text: "Authentication required"
                            font.pixelSize: 17
                            font.weight: Font.Black
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: root.flow?.actionId ?? ""
                            font.pixelSize: 10
                            font.family: Theme.mono
                            color: Theme.fgDim
                        }
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    font.pixelSize: 13
                }

                InputField {
                    id: pw
                    Layout.fillWidth: true
                    password: !(root.flow?.responseVisible ?? false)
                    icon: "key"
                    placeholder: root.flow?.inputPrompt || "Password"
                    accent: root.flow?.supplementaryIsError ? Theme.error : Theme.accent(0)
                    onAccepted: {
                        root.flow?.submit(pw.text);
                        pw.text = "";
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.error : Theme.fgDim
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    Btn {
                        text: "Cancel"
                        filled: false
                        onClicked: root.flow?.cancelAuthenticationRequest()
                    }
                    Btn {
                        icon: "check"
                        text: "Authenticate"
                        accent: Theme.accent(0)
                        onClicked: {
                            root.flow?.submit(pw.text);
                            pw.text = "";
                        }
                    }
                }
            }
        }
    }
}
