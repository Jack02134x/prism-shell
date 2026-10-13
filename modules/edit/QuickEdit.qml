pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets

// Quick-edit: open your most-edited folders in your editor (Config.apps.editor).
// Keys: 1–9 open directly, ↑/↓ + Enter, Esc closes. Folders live in
// config.json → apps.editFolders.
Overlay {
    id: win

    name: "edit"
    open: Panels.edit
    scrimOpacity: 0.35
    onDismiss: Panels.edit = false
    onOpened: {
        selected = 0;
        keys.forceActiveFocus();
    }

    property int selected: 0
    readonly property var folders: Config.apps.editFolders

    function label(path) {
        return String(path).replace(Config.home, "~");
    }
    function iconFor(path) {
        const p = String(path);
        if (p.endsWith("/hypr"))
            return "view_grid";
        if (p.endsWith("/quickshell"))
            return "creation";
        if (p.endsWith("/.scripts"))
            return "script_text_outline";
        if (p.endsWith("/Projects"))
            return "folder_star";
        return "code_braces";
    }
    function openAt(i) {
        const p = folders[i];
        if (!p)
            return;
        Panels.edit = false;
        Quickshell.execDetached([Config.apps.editor, p]);
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const n = win.folders.length;
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
                win.openAt(event.key - Qt.Key_1);
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_J)
                win.selected = (win.selected + 1) % n;
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_K)
                win.selected = (win.selected + n - 1) % n;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                win.openAt(win.selected);
            else
                return;
            event.accepted = true;
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.18 - (1 - win.progress) * 30
        width: 540
        height: col.implicitHeight + 36
        radius: Theme.r.xl
        gradient: TintGradient { alpha: 0.96; amount: 0.14 }
        opacity: win.progress
        scale: 0.92 + 0.08 * win.progress

        GlowBorder {
            z: -1
            radius: card.radius
            pad: 16
            glow: 0.45
            speed: 3
        }
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            RowLayout {
                SectionTitle {
                    Layout.fillWidth: true
                    icon: "code_braces"
                    text: "Quick edit"
                    accent: Theme.accent(2)
                }
                Txt {
                    text: "opens in " + Config.apps.editor
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
            }

            Repeater {
                model: win.folders
                Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    readonly property bool sel: win.selected === index
                    readonly property color accent: Theme.accent(index * 2)
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: 16
                    color: sel ? Theme.alpha(accent, 0.2) : "transparent"
                    border.width: sel ? 1 : 0
                    border.color: Theme.alpha(accent, 0.7)
                    Behavior on color { ColAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 11
                            color: Theme.alpha(row.accent, 0.18)
                            Icon {
                                anchors.centerIn: parent
                                icon: win.iconFor(row.modelData)
                                size: 18
                                color: row.accent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Txt {
                                Layout.fillWidth: true
                                text: Utils.fileName(String(row.modelData).replace(/\/$/, ""))
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: win.label(row.modelData)
                                font.pixelSize: 11
                                font.family: Theme.mono
                                color: Theme.fgDim
                            }
                        }
                        Keycap {
                            text: String(row.index + 1)
                            accent: row.accent
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.selected = row.index
                        onClicked: win.openAt(row.index)
                    }
                }
            }
        }
    }
}
