import QtQuick
import qs.common

// Material 3 expressive "wavy" progress: a travelling sine wave up to the
// current position, a flat track after it. Click/drag to seek.
Item {
    id: root

    property real value: 0
    property bool playing: true
    property color color: Theme.primary
    property color trackColor: Theme.alpha(Theme.fg, 0.18)
    property real amplitude: 3
    property real wavelength: 26
    property real lineWidth: 3
    property real phase: 0
    property bool seekable: true

    signal seek(real frac)

    implicitHeight: 18
    implicitWidth: 200

    Timer {
        interval: 33
        repeat: true
        running: root.playing && root.visible
        onTriggered: {
            root.phase = (root.phase + 0.22) % (Math.PI * 2);
            canvas.requestPaint();
        }
    }

    property real amp: playing ? amplitude : 0
    Behavior on amp { NumAnim { duration: Motion.slow } }
    onAmpChanged: canvas.requestPaint()
    onValueChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, cy = h / 2;
            const px = Math.max(0, Math.min(1, root.value)) * w;
            ctx.lineCap = "round";
            ctx.lineWidth = root.lineWidth;

            // track
            ctx.strokeStyle = root.trackColor;
            ctx.beginPath();
            ctx.moveTo(Math.min(w, px + 6), cy);
            ctx.lineTo(w, cy);
            ctx.stroke();

            // wave
            ctx.strokeStyle = root.color;
            ctx.beginPath();
            const k = Math.PI * 2 / root.wavelength;
            for (let x = 0; x <= px; x += 2) {
                const y = cy + Math.sin(x * k - root.phase) * root.amp;
                if (x === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();

            // thumb
            ctx.fillStyle = root.color;
            ctx.beginPath();
            ctx.roundedRect(px - 2, cy - 7, 4, 14, 2, 2);
            ctx.fill();
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.seekable
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.seek(Math.max(0, Math.min(1, mouse.x / width)))
    }
}
