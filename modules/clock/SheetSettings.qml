import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

ColumnLayout {
    id: root

    property var win
    readonly property var s: Chrono.d.settings
    property bool tones: false

    function set(k, v) {
        Chrono.d.settings[k] = v;
        Chrono.touch();
    }

    spacing: 14

    Txt {
        text: "Settings"
        font.pixelSize: 18
        font.weight: Font.Bold
    }

    Txt {
        text: "CLOCK"
        font.pixelSize: 11
        font.weight: Font.Black
        font.letterSpacing: 1.5
        color: Theme.primary
    }
    SettingRow {
        Layout.fillWidth: true
        label: "24-hour time"
        StyledSwitch {
            checked: root.s.h24
            onToggled: v => root.set("h24", v)
        }
    }
    SettingRow {
        Layout.fillWidth: true
        label: "Show seconds"
        StyledSwitch {
            checked: root.s.secs
            onToggled: v => root.set("secs", v)
        }
    }
    SettingRow {
        Layout.fillWidth: true
        label: "Fast mode"
        hint: "The Clock tab runs ahead by a secret amount, so you can't subtract it in your head. It reshuffles every day. Hold the time to see the real time. Alarms always ring at the real time."
        StyledSwitch {
            checked: root.s.fast
            onToggled: v => {
                root.set("fast", v);
                if (v)
                    Chrono.reroll();
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.s.fast
        spacing: 8
        SettingRow {
            Layout.fillWidth: true
            label: "At least ahead by"
            Stepper {
                text: root.s.fastMin + " min"
                onStep: delta => {
                    const v = Utils.clamp(root.s.fastMin + delta, 1, 30);
                    Chrono.d.settings.fastMin = v;
                    Chrono.d.settings.fastMax = Math.max(v, root.s.fastMax);
                    Chrono.touch();
                }
            }
        }
        SettingRow {
            Layout.fillWidth: true
            label: "At most ahead by"
            Stepper {
                text: root.s.fastMax + " min"
                onStep: delta => {
                    const v = Utils.clamp(root.s.fastMax + delta, 1, 30);
                    Chrono.d.settings.fastMax = v;
                    Chrono.d.settings.fastMin = Math.min(v, root.s.fastMin);
                    Chrono.touch();
                }
            }
        }
        Btn {
            icon: "shuffle_variant"
            text: "Shuffle the secret now"
            filled: false
            onClicked: {
                Chrono.reroll();
                root.win.toast("Shuffled");
            }
        }
    }

    Txt {
        Layout.topMargin: 6
        text: "ALARMS"
        font.pixelSize: 11
        font.weight: Font.Black
        font.letterSpacing: 1.5
        color: Theme.primary
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Txt {
            text: "Remind me before"
            font.pixelSize: 14
        }
        Txt {
            Layout.fillWidth: true
            text: "A notification this long before an alarm, with a button to skip just that one."
            font.pixelSize: 11
            color: Theme.fgDim
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Segmented {
            Layout.fillWidth: true
            options: [{ id: "0", label: "Off" }, { id: "10", label: "10 min" }, { id: "30", label: "30 min" }, { id: "60", label: "1 hour" }]
            current: String(root.s.remind)
            onPicked: id => root.set("remind", parseInt(id))
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Txt {
            text: "Snooze for"
            font.pixelSize: 14
        }
        Segmented {
            Layout.fillWidth: true
            options: [3, 5, 10, 15, 30].map(n => ({ id: String(n), label: n + "m" }))
            current: String(root.s.snooze)
            onPicked: id => root.set("snooze", parseInt(id))
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Txt {
            text: "Stop ringing after"
            font.pixelSize: 14
        }
        Segmented {
            Layout.fillWidth: true
            options: [1, 5, 10, 15, 30].map(n => ({ id: String(n), label: n + "m" }))
            current: String(root.s.silence)
            onPicked: id => root.set("silence", parseInt(id))
        }
    }
    SettingRow {
        Layout.fillWidth: true
        label: "Volume"
        Stepper {
            text: root.s.volume + "%"
            textWidth: 56
            onStep: delta => root.set("volume", Utils.clamp(root.s.volume + delta * 10, 10, 100))
        }
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
                text: "Ringtone"
                font.pixelSize: 14
            }
            Txt {
                text: Chrono.toneName(root.s.tone)
                font.pixelSize: 13
                color: Theme.fgDim
            }
        }
    }
    TonePicker {
        Layout.fillWidth: true
        visible: root.tones
        current: root.s.tone
        onPicked: id => root.set("tone", id)
    }
    Btn {
        Layout.alignment: Qt.AlignRight
        Layout.topMargin: 4
        text: "Done"
        implicitHeight: 40
        onClicked: root.win.closeSheet()
    }
}
