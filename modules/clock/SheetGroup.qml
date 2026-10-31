import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// A group: its name and ringtone (for alarms in it that don't pick their own).
ColumnLayout {
    id: root

    property var win
    readonly property var g: win ? win.draft : null
    property bool tones: false
    property bool deleting: false

    spacing: 12
    visible: g !== null

    Txt {
        text: root.g?.id ? "Group" : "New group"
        font.pixelSize: 18
        font.weight: Font.Bold
    }
    InputField {
        id: name
        Layout.fillWidth: true
        icon: "folder_clock_outline"
        placeholder: "Name (Weekdays, Gym, Exams …)"
        text: root.g?.name ?? ""
        fontSize: 14
        onTextChanged: if (root.g && text !== root.g.name) root.win.setDraft("name", text)
        Component.onCompleted: focusInput()
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.r.md
        color: Theme.alpha(Theme.surfaceHighest, 0.5)
        Interactive {
            radius: parent.radius
            onClicked: root.tones = !root.tones
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            Icon {
                icon: "music_note"
                size: 18
                color: Theme.primary
            }
            Txt {
                Layout.fillWidth: true
                text: "Ringtone for the group"
                font.pixelSize: 14
            }
            Txt {
                text: root.g?.tone ? Chrono.toneName(root.g.tone) : "Default"
                font.pixelSize: 13
                color: Theme.fgDim
            }
        }
    }
    TonePicker {
        Layout.fillWidth: true
        visible: root.tones
        allowDefault: true
        current: root.g?.tone ?? ""
        onPicked: id => root.win.setDraft("tone", id)
    }

    // deleting: with or without its alarms
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.deleting
        spacing: 6
        Btn {
            Layout.fillWidth: true
            icon: "delete_outline"
            text: "Delete the group and its alarms"
            accent: Theme.error
            onClicked: {
                Chrono.deleteGroup(root.g.id, true);
                root.win.closeSheet();
            }
        }
        Btn {
            Layout.fillWidth: true
            text: "Delete the group, keep the alarms"
            filled: false
            onClicked: {
                Chrono.deleteGroup(root.g.id, false);
                root.win.closeSheet();
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
        Btn {
            visible: (root.g?.id ?? 0) !== 0 && !root.deleting
            icon: "delete_outline"
            text: "Delete"
            filled: false
            accent: Theme.error
            implicitHeight: 42
            onClicked: root.deleting = true
        }
        Item {
            Layout.fillWidth: true
        }
        Btn {
            text: "Cancel"
            filled: false
            implicitHeight: 42
            onClicked: root.win.closeSheet()
        }
        Btn {
            icon: "check"
            text: "Save"
            implicitHeight: 42
            onClicked: {
                const id = Chrono.saveGroup(root.g);
                root.win.closeSheet();
                if (!root.g.id) {
                    Chrono.setGroupOpen(id, true);
                    root.win.toast("Now add alarms to " + (root.g.name || "Group"));
                }
            }
        }
    }
}
