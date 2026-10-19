pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// The dynamic island: morphs between clock, now-playing, OSD, notification
// peek and recording states. Hover it while music plays to expand controls.
Item {
    id: root

    property real barHeight: 42
    property bool hovered: hoverHandler.hovered || holdOpen.running
    // the island is the only notification popup: it shows queued notifications
    // one at a time (oldest first); each is still kept in the notification drawer
    readonly property var peek: Notifs.popups.length > 0 && !Panels.sidebar ? Notifs.popups[Notifs.popups.length - 1] : null
    onPeekChanged: {
        peekTimer.stop();
        if (peek && peek.timeout > 0) {
            peekTimer.interval = Math.min(peek.timeout, 7000);
            if (!hoverHandler.hovered)
                peekTimer.start();
        }
    }

    readonly property string mode: {
        if (Osd.visible)
            return "osd";
        if (peek)
            return "notif";
        if (trackPeek && !hovered)
            return "track";
        if (hovered && Media.hasPlayer)
            return "mediaFull";
        if (Media.playing)
            return "media";
        return "idle";
    }

    // showing something transient (the fullscreen copy of the island only appears then)
    readonly property bool alerting: mode === "osd" || mode === "notif" || mode === "track"

    readonly property real targetW: {
        switch (mode) {
        case "osd":
            return Osd.kind === "workspace" ? 230 : 380;
        case "notif":
            return 460;
        case "track":
            return 420;
        case "mediaFull":
            return 540;
        case "media":
            return 330;
        default:
            return idle.implicitWidth + 36;
        }
    }
    readonly property real targetH: {
        switch (mode) {
        case "osd":
            return Osd.value >= 0 ? 66 : barHeight + 6;
        case "notif":
            return (peek?.actions?.length ?? 0) > 0 ? 124 : 92;
        case "track":
            return 80;
        case "mediaFull":
            return 176;
        default:
            return barHeight;
        }
    }

    implicitWidth: shape.width
    implicitHeight: shape.height
    readonly property Item hitbox: shape

    // song changed: show it for a moment
    property bool trackPeek: false
    property string lastTrack: ""
    Connections {
        target: Media
        function onTitleChanged() {
            const t = Media.title + "|" + Media.artist;
            if (Media.title !== "" && t !== root.lastTrack && root.lastTrack !== "") {
                root.trackPeek = true;
                trackTimer.restart();
            }
            root.lastTrack = t;
        }
    }
    Timer {
        id: trackTimer
        interval: 3500
        onTriggered: root.trackPeek = false
    }

    Timer {
        id: peekTimer
        interval: 6000
        onTriggered: root.peek?.expireNow()
    }
    Timer {
        id: holdOpen
        interval: 450
    }

    Rectangle {
        id: shape
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: root.targetW
        height: root.targetH
        radius: Math.min(height / 2, 28)
        gradient: TintGradient { base: Theme.surfaceLowest; alpha: 0.94; amount: 0.2; from: Theme.grad2; to: Theme.grad1 }
        scale: tap.pressed ? 0.97 : 1

        Behavior on width { NumAnim { duration: Motion.slow; easing.bezierCurve: Motion.spatial } }
        Behavior on height { NumAnim { duration: Motion.slow; easing.bezierCurve: Motion.spatial } }
        Behavior on radius { NumAnim { duration: Motion.slow } }
        Behavior on scale { NumAnim { duration: Motion.fast } }

        GlowBorder {
            z: -1
            radius: shape.radius
            pad: 12
            thickness: 1.6
            speed: 3
            glow: Media.playing ? Math.min(1, 0.35 + Cava.bass * 0.9) : 0.3
        }

        // album-art wash behind the expanded player
        ClippingRectangle {
            anchors.fill: parent
            radius: shape.radius
            color: "transparent"
            opacity: root.mode === "mediaFull" ? 0.28 : 0
            visible: opacity > 0
            Behavior on opacity { NumAnim {} }
            Image {
                anchors.fill: parent
                source: parent.visible ? Media.art : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 256
                sourceSize.height: 256
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.alpha(Theme.surfaceLowest, 0.2) }
                    GradientStop { position: 1; color: Theme.alpha(Theme.surfaceLowest, 0.95) }
                }
            }
        }

        // ---------------- idle: clock + weather ----------------
        Layer {
            id: idleLayer
            shown: root.mode === "idle"
            RowLayout {
                id: idle
                anchors.centerIn: parent
                spacing: 10
                Txt {
                    text: Qt.formatTime(clock.date, "HH:mm")
                    font.pixelSize: 16
                    font.weight: Font.Black
                    font.family: Theme.display
                    color: Theme.fg
                }
                Rectangle {
                    implicitWidth: 4
                    implicitHeight: 4
                    radius: 2
                    color: Theme.accent(2)
                }
                Txt {
                    text: Qt.formatDate(clock.date, "ddd d MMM")
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.fgDim
                }
                Icon {
                    visible: Weather.ready
                    icon: Weather.icon
                    size: 15
                    color: Weather.tint
                }
                Txt {
                    visible: Weather.ready
                    text: Weather.tempText
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Theme.fg
                }
            }
        }

        // ---------------- compact media ----------------
        Layer {
            id: mediaLayer
            shown: root.mode === "media"
            // built only while this mode is on screen
            Loader {
                anchors.fill: parent
                active: mediaLayer.visible
                sourceComponent: Item {
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 14
                        spacing: 10

                        Disc {
                            Layout.preferredWidth: root.barHeight - 10
                            Layout.preferredHeight: root.barHeight - 10
                        }
                        Marquee {
                            Layout.fillWidth: true
                            text: Media.title + (Media.artist !== "" ? "  ·  " + Media.artist : "")
                            pixelSize: 12
                            weight: Font.DemiBold
                            color: Theme.fg
                        }
                        Visualizer {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 18
                            count: 8
                            spacing: 2
                            gain: 1.2
                        }
                    }
                }
            }
        }

        // ---------------- expanded media ----------------
        Layer {
            id: fullLayer
            shown: root.mode === "mediaFull"
            // built only while this mode is on screen
            Loader {
                anchors.fill: parent
                active: fullLayer.visible
                sourceComponent: Item {
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        ClippingRectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 140
                            radius: 18
                            color: Theme.surfaceHigh
                            Image {
                                anchors.fill: parent
                                source: Media.art
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 280
                                sourceSize.height: 280
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: Media.art === ""
                                icon: "music"
                                size: 54
                                color: Theme.primary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                Icon {
                                    icon: Media.sourceIcon
                                    size: 13
                                    color: Theme.accent(5)
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: Media.identity
                                    font.pixelSize: 11
                                    color: Theme.fgDim
                                }
                                Visualizer {
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 14
                                    count: 10
                                }
                            }
                            Marquee {
                                Layout.fillWidth: true
                                text: Media.title || "Nothing playing"
                                pixelSize: 17
                                weight: Font.Bold
                                color: Theme.fg
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: Media.artist
                                font.pixelSize: 13
                                color: Theme.accent(1)
                            }
                            Item { Layout.fillHeight: true }
                            WavyProgress {
                                Layout.fillWidth: true
                                value: Media.progress
                                playing: Media.playing
                                color: Theme.accent(0)
                                onSeek: frac => Media.seek(frac)
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Txt {
                                    text: Utils.mmss(Media.position)
                                    font.pixelSize: 10
                                    font.family: Theme.mono
                                    color: Theme.fgDim
                                }
                                Item { Layout.fillWidth: true }
                                IconBtn {
                                    icon: "skip_previous"
                                    size: 32
                                    onClicked: Media.previous()
                                }
                                IconBtn {
                                    icon: Media.playing ? "pause" : "play"
                                    size: 40
                                    active: true
                                    accent: Theme.accent(0)
                                    onClicked: Media.toggle()
                                }
                                IconBtn {
                                    icon: "skip_next"
                                    size: 32
                                    onClicked: Media.next()
                                }
                                Item { Layout.fillWidth: true }
                                Txt {
                                    text: Utils.mmss(Media.length)
                                    font.pixelSize: 10
                                    font.family: Theme.mono
                                    color: Theme.fgDim
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------- OSD ----------------
        Layer {
            id: osdLayer
            shown: root.mode === "osd"
            readonly property color tint: Osd.kind === "volume" ? Theme.accent(0) : Osd.kind === "brightness" ? Theme.accent(1) : Osd.kind === "mic" ? Theme.accent(7) : Osd.kind === "workspace" ? Theme.accent(Hypr.activeId - 1) : Theme.accent(4)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 18
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: Osd.value >= 0 ? 44 : root.barHeight - 4
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: osdLayer.tint
                    Icon {
                        anchors.centerIn: parent
                        icon: Osd.icon
                        size: parent.width * 0.5
                        color: Theme.on(parent.color)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Txt {
                        Layout.fillWidth: true
                        text: Osd.label
                        font.pixelSize: Osd.kind === "workspace" ? 15 : 13
                        font.weight: Font.Bold
                        color: Theme.fg
                    }
                    Rectangle {
                        visible: Osd.value >= 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4
                        color: Theme.alpha(Theme.fg, 0.12)
                        Rectangle {
                            height: parent.height
                            radius: 4
                            width: parent.width * Utils.clamp(Osd.value, 0, 1)
                            Behavior on width { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.accent(0) }
                                GradientStop { position: 1; color: Theme.accent(3) }
                            }
                        }
                    }
                }

                Txt {
                    visible: Osd.value >= 0
                    text: Math.round(Osd.value * 100)
                    font.pixelSize: 20
                    font.weight: Font.Black
                    font.family: Theme.display
                    color: osdLayer.tint
                }
            }
        }

        // ---------------- track change ----------------
        Layer {
            id: trackLayer
            shown: root.mode === "track"
            // built only while this mode is on screen
            Loader {
                anchors.fill: parent
                active: trackLayer.visible
                sourceComponent: Item {
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 18
                        spacing: 12
                        ClippingRectangle {
                            Layout.preferredWidth: 58
                            Layout.preferredHeight: 58
                            radius: 14
                            color: Theme.surfaceHigh
                            Image {
                                anchors.fill: parent
                                source: Media.art
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 116
                                sourceSize.height: 116
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: Media.art === ""
                                icon: "music"
                                size: 26
                                color: Theme.accent(0)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Txt {
                                text: "NOW PLAYING"
                                font.pixelSize: 9
                                font.weight: Font.Black
                                font.letterSpacing: 2
                                color: Theme.accent(5)
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: Media.title
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: Media.artist
                                font.pixelSize: 12
                                color: Theme.accent(1)
                            }
                        }
                        Visualizer {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 26
                            count: 6
                            gain: 1.2
                        }
                    }
                }
            }
        }

        // ---------------- notification ----------------
        Layer {
            id: notifLayer
            shown: root.mode === "notif"
            // built only while this mode is on screen
            Loader {
                anchors.fill: parent
                active: notifLayer.visible
                sourceComponent: Item {
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                Layout.alignment: Qt.AlignTop
                                radius: 16
                                color: Theme.alpha(root.peek?.accent ?? Theme.primary, 0.2)
                                readonly property string iconUrl: root.peek ? Notifs.iconFor(root.peek) : ""
                                IconImage {
                                    id: peekImg
                                    anchors.centerIn: parent
                                    implicitSize: 34
                                    source: parent.iconUrl
                                    visible: parent.iconUrl !== ""
                                }
                                Icon {
                                    anchors.centerIn: parent
                                    visible: !peekImg.visible
                                    icon: root.peek?.glyph || "bell_ring"
                                    size: 24
                                    color: root.peek?.accent ?? Theme.primary
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                RowLayout {
                                    Layout.fillWidth: true
                                    Txt {
                                        Layout.fillWidth: true
                                        text: (root.peek?.appName ?? "") + (Notifs.popups.length > 1 ? "  ·  +" + (Notifs.popups.length - 1) + " more" : "")
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.peek?.accent ?? Theme.primary
                                    }
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: root.peek?.summary ?? ""
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: (root.peek?.body ?? "").replace(/<[^>]*>/g, "")
                                    font.pixelSize: 12
                                    color: Theme.fgDim
                                    wrapMode: Text.Wrap
                                    maximumLineCount: (root.peek?.actions?.length ?? 0) > 0 ? 1 : 2
                                }
                            }
                            IconBtn {
                                Layout.alignment: Qt.AlignTop
                                icon: "close"
                                size: 26
                                iconSize: 13
                                idleColor: Theme.alpha(Theme.fg, 0.08)
                                tooltip: "Dismiss"
                                onClicked: root.peek?.dismiss()
                            }
                        }

                        // actions
                        RowLayout {
                            visible: (root.peek?.actions?.length ?? 0) > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 62
                            spacing: 6
                            Repeater {
                                model: root.peek?.actions?.slice(0, 3) ?? []
                                Btn {
                                    required property var modelData
                                    required property int index
                                    text: modelData.text || "Open"
                                    accent: root.peek?.accent ?? Theme.primary
                                    filled: index === 0
                                    implicitHeight: 28
                                    fontSize: 11
                                    pad: 12
                                    onClicked: root.peek?.invoke(modelData)
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }

        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (!hovered)
                    holdOpen.restart();
                // hovering keeps a notification on screen
                if (root.peek && root.peek.timeout > 0) {
                    if (hovered)
                        peekTimer.stop();
                    else
                        peekTimer.restart();
                }
            }
        }
        TapHandler {
            id: tap
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onTapped: (point, button) => {
                if (button === Qt.MiddleButton)
                    Media.toggle();
                else if (button === Qt.RightButton)
                    Panels.toggle("sidebar");
                else if (root.mode === "notif")
                    Panels.show("sidebar");
                else if (Panels.dashboard)
                    Panels.dashboard = false;
                else
                    Panels.openDashboard(0);
            }
        }
        WheelHandler {
            onWheel: event => Audio.nudge(event.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // cross-fading content layer
    component Layer: Item {
        property bool shown: false
        anchors.fill: parent
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.92
        visible: opacity > 0.01
        Behavior on opacity { NumAnim { duration: Motion.normal } }
        Behavior on scale { NumAnim { duration: Motion.slow; easing.bezierCurve: Motion.spatial } }
    }

    // spinning album-art disc
    component Disc: Item {
        ClippingRectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.surfaceHigh
            rotation: discSpin.angle
            Image {
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 96
                sourceSize.height: 96
            }
            Icon {
                anchors.centerIn: parent
                visible: Media.art === ""
                icon: "music_note"
                size: 16
                color: Theme.primary
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            radius: 3
            color: Theme.surfaceLowest
        }
    }

    // the disc turns on the shared Motion clock so it never adds redraws of its own
    QtObject {
        id: discSpin
        property real angle: 0
        readonly property bool spinning: root.mode === "media" && Media.playing
        onSpinningChanged: Motion.tickUsers += spinning ? 1 : -1
    }
    Connections {
        target: Motion
        enabled: discSpin.spinning
        function onTick(dt) {
            discSpin.angle = (discSpin.angle + dt * 0.04) % 360;
        }
    }
}
