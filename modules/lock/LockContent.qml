pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pam
import qs.common
import qs.services
import qs.widgets

// Lock screen UI, shared by the real session lock and the preview overlay.
Item {
    id: root

    property bool preview: false
    signal unlocked
    signal cancelled

    property bool busy: false
    property string error: ""
    property real reveal: 0
    Component.onCompleted: revealAnim.start()
    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.OutCubic
    }

    function submit() {
        if (busy || pw.text.length === 0)
            return;
        busy = true;
        error = "";
        pam.start();
    }

    PamContext {
        id: pam
        config: Config.lock.pamConfig
        onPamMessage: {
            if (responseRequired)
                respond(pw.text);
        }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                pw.text = "";
                root.unlocked();
            } else {
                root.error = "Wrong password";
                pw.text = "";
                shake.restart();
            }
        }
        onError: err => {
            root.busy = false;
            root.error = "Authentication error";
            shake.restart();
        }
    }

    // ---- backdrop ----
    Rectangle {
        anchors.fill: parent
        color: "black"
    }
    Image {
        id: wall
        anchors.fill: parent
        source: Theme.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1280
        asynchronous: true
        cache: false // same path every time (the copy is overwritten): never show a stale one
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: root.reveal
        blurMax: 64
        brightness: -0.35 * root.reveal
        scale: 1 + 0.06 * root.reveal
    }
    Aurora {
        anchors.fill: parent
        intensity: 1
        opacity: 0.4 * root.reveal
        bg: Qt.rgba(0, 0, 0, 0)
    }

    // ---- clock ----
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12 - 30 + (1 - root.reveal) * -60
        opacity: root.reveal
        spacing: -40

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: t.implicitWidth
            implicitHeight: t.implicitHeight
            Text {
                id: t
                text: Qt.formatTime(clock.date, "HH:mm")
                font.family: Theme.display
                font.pixelSize: 210
                font.weight: Font.Black
                color: "white"
                visible: false
                layer.enabled: true
                // room for the glyphs' overhang and the shadow, which the mask would clip
                topPadding: 60
                bottomPadding: 30
                leftPadding: 50
                rightPadding: 50
            }
            Rectangle {
                id: g
                anchors.fill: t
                visible: false
                layer.enabled: true
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accent(0) }
                    GradientStop { position: 0.5; color: Theme.accent(4) }
                    GradientStop { position: 1; color: Theme.accent(7) }
                }
            }
            MultiEffect {
                anchors.fill: t
                source: g
                maskEnabled: true
                maskSource: t
                maskThresholdMin: 0.3
                maskSpreadAtMin: 0.3
                shadowEnabled: true
                shadowBlur: 1
                shadowColor: Qt.rgba(0, 0, 0, 0.7)
            }
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(clock.date, "dddd, d MMMM").toUpperCase()
            font.pixelSize: 20
            font.weight: Font.Bold
            font.letterSpacing: 6
            color: "white"
        }

        // the day at a glance
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 58
            spacing: 10
            LockChip {
                visible: Weather.ready
                icon: Weather.icon
                tint: Weather.tint
                text: Weather.tempText + "  " + Weather.desc
            }
            LockChip {
                icon: Power.icon
                tint: Theme.accent(3)
                text: Power.percent + "%"
            }
            LockChip {
                visible: Chrono.nextAlarm !== null
                icon: "alarm"
                tint: Theme.accent(5)
                text: Chrono.nextAlarm ? Chrono.fmtWhen(Chrono.nextAlarm.at) + "  " + Chrono.nextAlarm.label : ""
            }
            LockChip {
                visible: ScreenTime.available && ScreenTime.today > 0
                icon: "monitor"
                tint: Theme.accent(6)
                text: Utils.human(ScreenTime.today) + " today"
            }
            LockChip {
                // a count only: what they say stays private until unlocked
                visible: Notifs.count > 0
                icon: "bell"
                tint: Theme.accent(1)
                text: Notifs.count + (Notifs.count === 1 ? " notification" : " notifications")
            }
        }
    }

    // ---- login card ----
    ColumnLayout {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.14 - (1 - root.reveal) * 60
        opacity: root.reveal
        spacing: 16

        Avatar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 110
            Layout.preferredHeight: 110
            ring: 4
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: Config.user.name
            font.pixelSize: 22
            font.weight: Font.Black
            color: "white"
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 360
            implicitHeight: 52
            transform: Translate { id: shakeT }

            InputField {
                id: pw
                anchors.fill: parent
                password: true
                icon: root.busy ? "loading" : "lock"
                placeholder: root.preview && !Session.previewClean ? "Preview — Esc to close" : "Password"
                accent: root.error !== "" ? Theme.error : Theme.accent(0)
                radius: 26
                color: Qt.rgba(0, 0, 0, 0.45)
                fontSize: 16
                onAccepted: root.submit()
                onEscaped: if (root.preview) root.cancelled()
                Component.onCompleted: focusInput()
            }

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: shakeT; property: "x"; to: -14; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; to: 14; duration: 90 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 50 }
            }
        }

        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: root.error !== "" ? root.error : (root.busy ? "Checking…" : "Enter to unlock")
            color: root.error !== "" ? Theme.error : Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: 12
        }
    }

    // ---- music: cava along the bottom edge, the now-playing card (and the cat) ----
    Visualizer {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 120
        count: 64
        spacing: 4
        gain: 1.1
        radius: 3
        hifi: true
        visible: Media.hasPlayer
        opacity: root.reveal * (Media.playing ? 0.55 : 0.15)
        Behavior on opacity { NumAnim { duration: Motion.slow } }
    }
    LockMedia {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 36
        visible: Media.hasPlayer && Media.title !== ""
        opacity: root.reveal
        transform: Translate { x: (1 - root.reveal) * 80 }
    }

    Txt {
        visible: root.preview && !Session.previewClean
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        text: "PREVIEW · Esc or click here to close"
        font.weight: Font.Black
        color: Theme.accent(2)
        TapHandler {
            onTapped: root.cancelled()
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
