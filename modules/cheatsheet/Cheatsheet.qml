pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Keybind cheatsheet parsed live from your binds.lua, plus Prism's IPC calls.
Overlay {
    id: win

    name: "cheatsheet"
    open: Panels.cheatsheet
    scrimOpacity: 0.6
    onDismiss: Panels.cheatsheet = false
    onOpened: filter.focusInput()

    readonly property string q: filter.text.trim().toLowerCase()
    readonly property var sections: {
        const extra = Keybinds.unbound.length > 0 ? [{ name: "Prism — not bound yet", binds: Keybinds.unbound.map(p => ({ keys: ["qs ipc call " + p.ipc], desc: p.desc })) }] : [];
        const all = Keybinds.sections.concat(extra);
        if (q === "")
            return all;
        return all.map(s => ({ name: s.name, binds: s.binds.filter(b => (b.keys.join(" ") + " " + b.desc).toLowerCase().includes(q)) })).filter(s => s.binds.length > 0);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 60
        anchors.topMargin: Config.bar.height + 40
        spacing: 18
        opacity: win.progress
        scale: 0.96 + 0.04 * win.progress

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Icon {
                icon: "keyboard"
                size: 34
                color: Theme.accent(0)
            }
            ColumnLayout {
                spacing: 0
                Txt {
                    text: "Keybinds"
                    font.pixelSize: 28
                    font.weight: Font.Black
                    font.family: Theme.display
                }
                Txt {
                    text: "read live from " + Config.paths.binds.replace(Config.home, "~")
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
            }
            Item { Layout.fillWidth: true }
            InputField {
                id: filter
                Layout.preferredWidth: 360
                placeholder: "Filter binds…"
                accent: Theme.accent(0)
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: flow.implicitHeight
            clip: true

            Flow {
                id: flow
                width: parent.width
                spacing: 16

                Repeater {
                    model: win.sections
                    Rectangle {
                        id: sec
                        required property var modelData
                        required property int index
                        readonly property color accent: Theme.accent(index * 2)
                        width: (flow.width - 32) / 3
                        height: secCol.implicitHeight + 28
                        radius: Theme.r.lg
                        gradient: TintGradient { base: Theme.surfaceContainer; alpha: 0.92; amount: 0.12; orientation: Gradient.Vertical }
                        border.width: 1
                        border.color: Theme.alpha(accent, 0.35)

                        opacity: 0
                        Component.onCompleted: secIn.start()
                        SequentialAnimation {
                            id: secIn
                            PauseAnimation { duration: sec.index * 40 }
                            NumberAnimation { target: sec; property: "opacity"; to: 1; duration: Motion.slow }
                        }

                        ColumnLayout {
                            id: secCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 8
                            Txt {
                                text: sec.modelData.name
                                font.pixelSize: 14
                                font.weight: Font.Black
                                color: sec.accent
                            }
                            Repeater {
                                model: sec.modelData.binds
                                RowLayout {
                                    id: bind
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Repeater {
                                        model: bind.modelData.keys
                                        Keycap {
                                            required property string modelData
                                            text: modelData
                                            accent: sec.accent
                                        }
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 8
                                        text: bind.modelData.desc
                                        font.pixelSize: 12
                                        color: Theme.fgDim
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
