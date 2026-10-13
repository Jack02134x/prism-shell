import QtQuick
import qs.common

// Smooth area chart for a series of 0..1 samples (newest last).
Canvas {
    id: root

    property var values: []
    property color color: Theme.primary
    property real lineWidth: 2
    property int capacity: 60
    property real maxValue: 1
    property bool fillArea: true

    implicitWidth: 200
    implicitHeight: 60
    renderStrategy: Canvas.Cooperative

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values || [];
        if (v.length < 2)
            return;
        const w = width, h = height;
        const n = Math.max(capacity, v.length);
        const dx = w / (n - 1);
        const off = (n - v.length) * dx;
        const pad = lineWidth;
        const yOf = x => h - pad - Utils.clamp(x / maxValue, 0, 1) * (h - pad * 2);

        ctx.beginPath();
        ctx.moveTo(off, yOf(v[0]));
        for (let i = 1; i < v.length; i++) {
            const x0 = off + (i - 1) * dx, x1 = off + i * dx;
            const xm = (x0 + x1) / 2;
            ctx.bezierCurveTo(xm, yOf(v[i - 1]), xm, yOf(v[i]), x1, yOf(v[i]));
        }
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.stroke();

        if (fillArea) {
            ctx.lineTo(w, h);
            ctx.lineTo(off, h);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, h);
            g.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.45));
            g.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0.0));
            ctx.fillStyle = g;
            ctx.fill();
        }

        // glowing head dot
        const hx = off + (v.length - 1) * dx, hy = yOf(v[v.length - 1]);
        ctx.beginPath();
        ctx.arc(hx - 2, hy, 3.5, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.fill();
    }
}
