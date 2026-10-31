import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Interval timer: named steps (Work 0:40, Rest 0:20 …) repeated N times.
// It beeps on every change and counts down the last three seconds.
Item {
    id: root

    property var win
    readonly property bool idle: Chrono.d.iv.status === "idle"
    readonly property var flat: Chrono.ivFlat(Chrono.d.iv.steps, Chrono.d.iv.loops)
    readonly property var st: idle ? null : Chrono.ivState()

    function secsText(s) {
        return Math.floor(s / 60) + ":" + Chrono.pad(s % 60);
    }
    function parseSecs(str) {
        str = String(str).trim();
        if (str.indexOf(":") >= 0) {
            const p = str.split(":");
            return Math.max(0, (parseInt(p[0]) || 0) * 60 + (parseInt(p[1]) || 0));
        }
        return Math.max(0, parseInt(str) || 0);
    }
    function setStep(i, k, v) {
        Chrono.d.iv.steps[i][k] = v;
        Chrono.touch();
    }

    // ---- setting up ----
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 16
        visible: root.idle
        spacing: 8

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: steps.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: steps
                width: parent.width
                spacing: 6
                Repeater {
                    model: Chrono.d.iv.steps
                    Rectangle {
                        id: stepRow
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: Theme.r.md
                        color: Theme.alpha(Theme.surfaceHighest, 0.5)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 6
                            spacing: 8
                            Rectangle {
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: Theme.accent(stepRow.index * 3)
                            }
                            TextInput {
                                Layout.fillWidth: true
                                text: stepRow.modelData.name
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                selectByMouse: true
                                clip: true
                                onEditingFinished: if (text !== stepRow.modelData.name) root.setStep(stepRow.index, "name", text)
                            }
                            Rectangle {
                                implicitWidth: 70
                                implicitHeight: 32
                                radius: 8
                                color: Theme.alpha(Theme.fg, 0.06)
                                TextInput {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: root.secsText(stepRow.modelData.secs)
                                    color: Theme.fg
                                    font.family: Theme.mono
                                    font.pixelSize: 14
                                    selectByMouse: true
                                    onEditingFinished: {
                                        const v = root.parseSecs(text);
                                        if (v !== stepRow.modelData.secs)
                                            root.setStep(stepRow.index, "secs", v);
                                        else
                                            text = root.secsText(v);
                                    }
                                }
                            }
                            IconBtn {
                                icon: "close"
                                size: 28
                                visible: Chrono.d.iv.steps.length > 1
                                onClicked: {
                                    Chrono.d.iv.steps.splice(stepRow.index, 1);
                                    Chrono.touch();
                                }
                            }
                        }
                    }
                }
                Btn {
                    Layout.fillWidth: true
                    icon: "plus"
                    text: "Add a step"
                    filled: false
                    onClicked: {
                        Chrono.d.iv.steps.push({ name: "Step " + (Chrono.d.iv.steps.length + 1), secs: 30 });
                        Chrono.touch();
                    }
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            label: "Rounds"
            hint: root.flat.length + " steps · " + Utils.hms(Chrono.ivTotal(root.flat)) + " in all"
            Stepper {
                text: Chrono.d.iv.loops + "×"
                textWidth: 40
                onStep: delta => {
                    Chrono.d.iv.loops = Utils.clamp(Chrono.d.iv.loops + delta, 1, 99);
                    Chrono.touch();
                }
            }
        }

        // saved sets: click to load, right-click to delete
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: Chrono.d.iv.presets.length > 0
            Repeater {
                model: Chrono.d.iv.presets
                Btn {
                    required property var modelData
                    required property int index
                    text: modelData.name
                    icon: "bookmark_outline"
                    filled: false
                    implicitHeight: 30
                    fontSize: 12
                    onClicked: m => m.button === Qt.RightButton ? Chrono.ivDeletePreset(index) : Chrono.ivLoadPreset(index)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Btn {
                icon: "bookmark_plus_outline"
                text: "Save set"
                filled: false
                implicitHeight: 44
                onClicked: {
                    const name = Chrono.d.iv.steps.map(s => s.name).join(" / ") + " ×" + Chrono.d.iv.loops;
                    Chrono.ivSavePreset(name);
                    root.win.toast("Saved · right-click a set to delete it");
                }
            }
            Btn {
                Layout.fillWidth: true
                implicitHeight: 44
                icon: "play"
                text: "Start"
                fontSize: 15
                opacity: root.flat.length ? 1 : 0.4
                onClicked: Chrono.ivStart()
            }
        }
    }

    // ---- running ----
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 20
        visible: !root.idle && root.st !== null
        spacing: 6

        Item {
            Layout.fillHeight: true
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: root.st?.step ? "Round " + root.st.step.loop + " of " + Chrono.d.iv.loops : ""
            font.pixelSize: 12
            font.weight: Font.Black
            font.letterSpacing: 1.5
            color: Theme.fgDim
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: root.st?.step?.name ?? ""
            font.pixelSize: 30
            font.weight: Font.Bold
            color: Theme.accent(Math.max(0, Chrono.d.iv.steps.findIndex(s => s.name === root.st?.step?.name)) * 3)
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: Utils.hms(Math.ceil(root.st?.left ?? 0))
            font.family: Theme.display
            font.pixelSize: 76
            font.weight: Font.Light
            font.features: { "tnum": 1 }
            color: Chrono.ivPaused ? Theme.fgDim : Theme.fg
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: Chrono.ivPaused ? "Paused" : root.st?.next ? "Next: " + root.st.next.name + " · " + root.secsText(root.st.next.secs) : "Last step"
            font.pixelSize: 13
            color: Theme.fgDim
        }
        Item {
            Layout.fillHeight: true
        }
        // the whole run
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 8
            radius: 4
            color: Theme.alpha(Theme.fg, 0.08)
            Rectangle {
                width: parent.width * (root.st && root.st.total > 0 ? Math.min(1, root.st.done / root.st.total) : 0)
                height: parent.height
                radius: 4
                color: Theme.primary
            }
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 10
            text: root.st ? Utils.hms(Math.ceil(root.st.total - root.st.done)) + " left in all" : ""
            font.pixelSize: 11
            color: Theme.fgDim
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Btn {
                icon: "restart"
                text: "Reset"
                filled: false
                implicitHeight: 44
                onClicked: Chrono.ivReset()
            }
            Btn {
                icon: Chrono.ivRunning ? "pause" : "play"
                text: Chrono.ivRunning ? "Pause" : "Resume"
                implicitHeight: 44
                pad: 22
                onClicked: Chrono.ivPause()
            }
            Btn {
                icon: "skip_next"
                text: "Skip"
                filled: false
                implicitHeight: 44
                onClicked: Chrono.ivSkip()
            }
        }
    }
}
