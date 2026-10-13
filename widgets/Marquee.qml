import QtQuick
import qs.common

// Text that scrolls when it doesn't fit. Scrolling forces redraws at the
// panel's refresh rate, so by default it scrolls one lap, rests, and repeats;
// with hoverOnly it only scrolls while `hovered` is true (and elides otherwise).
Item {
    id: root

    property string text: ""
    property color color: Theme.fg
    property real pixelSize: 13
    property int weight: Font.Normal
    property string family: Theme.font
    property real speed: 36 // px per second
    property real gap: 48
    property bool running: true
    property bool hoverOnly: false
    property bool hovered: false
    property int rest: 3500
    readonly property bool overflow: probe.implicitWidth > width + 1
    readonly property bool scrolling: overflow && running && visible && (!hoverOnly || hovered)

    implicitHeight: probe.implicitHeight
    implicitWidth: probe.implicitWidth
    clip: true

    Txt {
        id: probe
        visible: false
        text: root.text
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.family: root.family
        elide: Text.ElideNone
    }

    // static, elided text when not scrolling
    Txt {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.scrolling
        text: root.text
        color: root.color
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.family: root.family
    }

    Row {
        id: strip
        visible: root.scrolling
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap
        x: 0

        Repeater {
            model: 2
            Txt {
                required property int index
                text: root.text
                color: root.color
                font.pixelSize: root.pixelSize
                font.weight: root.weight
                font.family: root.family
                elide: Text.ElideNone
            }
        }
    }

    onTextChanged: {
        strip.x = 0;
        restLeft = hoverOnly ? 250 : rest;
    }

    // steps on the shared Motion clock instead of a free-running animation
    property real restLeft: rest
    property bool ticking: false
    onScrollingChanged: {
        if (scrolling && !ticking) {
            Motion.tickUsers++;
            ticking = true;
            restLeft = hoverOnly ? 250 : rest;
        } else if (!scrolling && ticking) {
            Motion.tickUsers--;
            ticking = false;
            strip.x = 0;
        }
    }
    Component.onDestruction: if (ticking) Motion.tickUsers--
    Connections {
        target: Motion
        enabled: root.ticking
        function onTick(dt) {
            if (root.restLeft > 0) {
                root.restLeft -= dt;
                return;
            }
            const lap = probe.implicitWidth + root.gap;
            strip.x -= root.speed * dt / 1000;
            if (strip.x <= -lap) {
                strip.x = 0;
                root.restLeft = root.hoverOnly ? 0 : root.rest;
            }
        }
    }
}
