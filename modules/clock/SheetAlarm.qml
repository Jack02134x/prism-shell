import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Edit or add an alarm: time, label, how it repeats (days of the week, every
// N days, or one date), its group and ringtone, and "skip next".
ColumnLayout {
    id: root

    property var win
    readonly property var a: win ? win.draft : null
    readonly property string mode: a?.rep?.k ?? "weekly"
    readonly property bool repeating: a ? Chrono.repeats(a) : false
    property bool tones: false

    function set(k, v) {
        win.setDraft(k, v);
    }
    function dateOf(s) {
        const p = Chrono.parseYmd(s);
        return p ? new Date(p.y, p.mo - 1, p.d) : new Date();
    }
    // a sensible date for "on a date": today if the time is still ahead, else tomorrow
    function firstDate() {
        const t = new Date();
        if (a.h * 60 + a.m <= t.getHours() * 60 + t.getMinutes())
            t.setDate(t.getDate() + 1);
        return Chrono.ymd(t);
    }

    spacing: 12
    visible: a !== null

    Txt {
        text: root.a?.id ? "Edit alarm" : "New alarm"
        font.pixelSize: 18
        font.weight: Font.Bold
    }

    // ---- time ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 160
        radius: Theme.r.lg
        color: Theme.alpha(Theme.surfaceHighest, 0.5)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 24
            height: 44
            radius: Theme.r.md
            color: Theme.alpha(Theme.primary, 0.14)
        }
        Row {
            anchors.centerIn: parent
            spacing: 4
            Wheel {
                id: hw
                height: 160
                width: Chrono.d.settings.h24 ? 80 : 120
                itemH: 32
                count: 24
                label: h => Chrono.d.settings.h24 ? Chrono.pad(h) : (h % 12 || 12) + (h < 12 ? " AM" : " PM")
                onMoved: i => {
                    if (root.a && i !== root.a.h)
                        root.set("h", i);
                }
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                font.family: Theme.display
                font.pixelSize: 28
            }
            Wheel {
                id: mw
                height: 160
                width: 80
                itemH: 32
                count: 60
                onMoved: i => {
                    if (root.a && i !== root.a.m)
                        root.set("m", i);
                }
            }
        }
    }
    Component.onCompleted: {
        hw.currentIndex = a?.h ?? 7;
        mw.currentIndex = a?.m ?? 0;
    }

    InputField {
        Layout.fillWidth: true
        icon: "label_outline"
        placeholder: "Label"
        text: root.a?.label ?? ""
        fontSize: 14
        onTextChanged: if (root.a && text !== root.a.label) root.set("label", text)
    }

    // ---- repeat ----
    Segmented {
        Layout.fillWidth: true
        options: [{ id: "weekly", label: "Weekly" }, { id: "interval", label: "Every N days" }, { id: "date", label: "On a date" }]
        current: root.mode
        onPicked: id => root.set("rep", id === "weekly" ? null : id === "interval" ? { k: "interval", n: 2, start: Chrono.ymd(new Date()) } : { k: "date", date: root.firstDate() })
    }
    // days of the week (none = once)
    RowLayout {
        Layout.fillWidth: true
        visible: root.mode === "weekly"
        spacing: 4
        Repeater {
            model: [1, 2, 3, 4, 5, 6, 0]
            Rectangle {
                id: day
                required property int modelData
                readonly property bool on: ((root.a?.days ?? 0) & (1 << modelData)) !== 0
                Layout.fillWidth: true
                implicitHeight: 38
                radius: on ? Theme.r.md : height / 2
                color: on ? Theme.primary : Theme.alpha(Theme.fg, 0.06)
                Behavior on radius { NumAnim {} }
                Behavior on color { ColAnim {} }
                Txt {
                    anchors.centerIn: parent
                    text: Chrono.dayShort[day.modelData].charAt(0)
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: day.on ? Theme.on(Theme.primary) : Theme.fgDim
                }
                Interactive {
                    radius: parent.radius
                    onClicked: root.set("days", (root.a.days ?? 0) ^ (1 << day.modelData))
                }
            }
        }
    }
    Txt {
        visible: root.mode === "weekly"
        text: (root.a?.days ?? 0) ? Chrono.repeatText(root.a) : "Once (pick days to repeat)"
        font.pixelSize: 12
        color: Theme.fgDim
    }
    SettingRow {
        Layout.fillWidth: true
        visible: root.mode === "interval"
        label: "Every"
        hint: root.a?.rep?.start ? "counting from " + Qt.formatDate(root.dateOf(root.a.rep.start), "ddd d MMM") : ""
        Stepper {
            text: (root.a?.rep?.n ?? 1) + ((root.a?.rep?.n ?? 1) === 1 ? " day" : " days")
            textWidth: 70
            onStep: delta => root.set("rep", Object.assign({}, root.a.rep, { n: Utils.clamp((root.a.rep.n || 1) + delta, 1, 365) }))
        }
    }
    SettingRow {
        Layout.fillWidth: true
        visible: root.mode === "date"
        label: "Date"
        Stepper {
            text: root.mode === "date" ? Qt.formatDate(root.dateOf(root.a.rep.date), "ddd d MMM") : ""
            textWidth: 100
            onStep: delta => {
                const t = root.dateOf(root.a.rep.date);
                t.setDate(t.getDate() + delta);
                if (t >= new Date(new Date().setHours(0, 0, 0, 0)))
                    root.set("rep", { k: "date", date: Chrono.ymd(t) });
            }
        }
    }

    // ---- group ----
    Flow {
        Layout.fillWidth: true
        visible: Chrono.d.groups.length > 0
        spacing: 6
        Txt {
            height: 30
            text: "Group"
            font.pixelSize: 13
            color: Theme.fgDim
            rightPadding: 6
        }
        Repeater {
            model: [{ id: 0, name: "None" }].concat(Chrono.d.groups)
            Btn {
                required property var modelData
                text: modelData.name
                implicitHeight: 30
                fontSize: 12
                filled: (root.a?.group ?? 0) === modelData.id
                onClicked: root.set("group", modelData.id)
            }
        }
    }

    // ---- ringtone ----
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
                text: root.a?.tone ? Chrono.toneName(root.a.tone) : "Default"
                font.pixelSize: 13
                color: Theme.fgDim
            }
            Icon {
                icon: "chevron_down"
                size: 18
                color: Theme.fgDim
                rotation: root.tones ? 180 : 0
            }
        }
    }
    TonePicker {
        Layout.fillWidth: true
        visible: root.tones
        allowDefault: true
        current: root.a?.tone ?? ""
        onPicked: id => root.set("tone", id)
    }

    // ---- skip next ----
    Btn {
        Layout.fillWidth: true
        visible: (root.a?.id ?? 0) !== 0 && root.repeating
        readonly property bool skipping: (root.a?.skip ?? 0) > Chrono.now
        icon: skipping ? "debug_step_over" : "skip_next"
        text: skipping ? "Skipping " + Chrono.fmtWhen(root.a.skip) + " (click to undo)" : "Skip the next one (" + (root.a ? Chrono.fmtWhen(Chrono.scheduled(root.a, Chrono.now)) : "") + ")"
        filled: false
        onClicked: root.set("skip", skipping ? 0 : Chrono.scheduled(root.a, Date.now()))
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
        Btn {
            visible: (root.a?.id ?? 0) !== 0
            icon: "delete_outline"
            text: "Delete"
            filled: false
            accent: Theme.error
            implicitHeight: 42
            onClicked: {
                Chrono.deleteAlarm(root.a.id);
                root.win.closeSheet();
                root.win.toast("Alarm deleted");
            }
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
                const due = Chrono.saveAlarm(root.a);
                root.win.closeSheet();
                root.win.toast(due ? "Rings in " + Chrono.untilText(due - Date.now()) : "Saved · that time has passed");
            }
        }
    }
}
