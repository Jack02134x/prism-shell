import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.widgets

// The screenshot overlay: the focused monitor is frozen (ScreencopyView, no
// grim), four threads run from the screen corners to the cursor, and to the
// corners of the selection once you drag. Click a window to take just that
// window; Enter takes the whole screen. The frame goes to Shot.save().
PanelWindow {
    id: win

    screen: Shot.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-shot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property real scale: monitor?.scale ?? 1
    readonly property real w: width
    readonly property real h: height

    // aim (nothing picked yet) -> drag -> done | cancelled
    property string phase: "aim"
    readonly property bool windowMode: Shot.mode === "window"

    // cursor
    property real cx: width / 2
    property real cy: height / 2
    property bool hasCursor: false

    // the box: drag selection, the hovered window, or the final pick
    property real bx: cx
    property real by: cy
    property real bw: 0
    property real bh: 0
    property bool glide: true // ease the box (window snapping); off while dragging
    Behavior on bx { enabled: win.glide; NumAnim { duration: Motion.fast } }
    Behavior on by { enabled: win.glide; NumAnim { duration: Motion.fast } }
    Behavior on bw { enabled: win.glide; NumAnim { duration: Motion.fast } }
    Behavior on bh { enabled: win.glide; NumAnim { duration: Motion.fast } }

    // the threads leave the cursor for the box corners once there's a box to hold
    readonly property bool cornered: phase !== "aim" || (windowMode && hovered !== null)
    property real retract: 0 // 0..1: threads spring back to their corners
    property real fall: 0 // px: threads drop (cancel)

    // ---------------------------------------------------------- windows ---
    // windows on this monitor (the special workspace on top), front first
    readonly property var windows: {
        const m = monitor;
        if (!m)
            return [];
        const sp = m.lastIpcObject?.specialWorkspace?.id ?? 0;
        const ids = [m.activeWorkspace?.id ?? -1];
        if (sp)
            ids.push(sp);
        const out = [];
        for (const t of Hypr.realToplevels) {
            const o = t.lastIpcObject;
            if (!ids.includes(o.workspace?.id) || !o.at || !o.size)
                continue;
            out.push({
                x: o.at[0] - m.x,
                y: o.at[1] - m.y,
                w: o.size[0],
                h: o.size[1],
                rank: (o.workspace.id === sp ? 8 : 0) + (o.fullscreen ? 4 : 0) + (o.floating ? 2 : 0),
                order: o.focusHistoryID ?? 99
            });
        }
        out.sort((a, b) => (b.rank - a.rank) || (a.order - b.order));
        return out;
    }
    readonly property var hovered: hasCursor && phase === "aim" ? windows.find(r => cx >= r.x && cx < r.x + r.w && cy >= r.y && cy < r.y + r.h) ?? null : null

    onHoveredChanged: if (phase === "aim") {
        if (hovered) {
            bx = hovered.x;
            by = hovered.y;
            bw = hovered.w;
            bh = hovered.h;
        } else {
            bx = cx;
            by = cy;
            bw = 0;
            bh = 0;
        }
    }

    // --------------------------------------------------------- actions ---
    function commit(x, y, ww, hh) {
        if (phase !== "aim" && phase !== "drag")
            return;
        // clamp to the screen
        const x0 = Math.max(0, x), y0 = Math.max(0, y);
        const x1 = Math.min(w, x + ww), y1 = Math.min(h, y + hh);
        if (x1 - x0 < 2 || y1 - y0 < 2)
            return;
        glide = false;
        bx = x0;
        by = y0;
        bw = x1 - x0;
        bh = y1 - y0;
        phase = "done";
        for (let i = 0; i < threads.count; i++)
            threads.itemAt(i).pluck(0.05 * (i % 2 ? -1 : 1));
        flash.restart();

        const s = scale;
        const whole = x0 === 0 && y0 === 0 && x1 === w && y1 === h;
        const crop = whole ? "" : Math.round((x1 - x0) * s) + "x" + Math.round((y1 - y0) * s) + "+" + Math.round(x0 * s) + "+" + Math.round(y0 * s);
        const frame = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/prism-shot-" + Date.now() + ".png";
        frozen.grabToImage(r => {
            if (r.saveToFile(frame))
                Shot.save(frame, crop);
            else
                Notifs.local("Screenshot failed", "Couldn't read the screen", "monitor_screenshot", 2, "", []);
        }, Qt.size(Math.round(w * s), Math.round(h * s)));
        outro.start();
    }

    function cancel() {
        if (phase === "done" || phase === "cancelled")
            return;
        phase = "cancelled";
        drop.start();
    }

    Connections {
        target: Shot
        function onCancelRequested() {
            win.cancel();
        }
    }

    SequentialAnimation {
        id: outro
        PauseAnimation { duration: 280 } // let the threads ring
        ParallelAnimation {
            NumberAnimation { target: win; property: "retract"; to: 1; duration: 420; easing.type: Easing.InBack; easing.overshoot: 1.4 }
            NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InQuad }
        }
        ScriptAction { script: Shot.finish() }
    }
    SequentialAnimation {
        id: drop
        ParallelAnimation {
            NumberAnimation { target: win; property: "fall"; to: win.h * 0.7; duration: 480; easing.type: Easing.InQuad }
            NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 480; easing.type: Easing.InQuad }
        }
        ScriptAction { script: Shot.finish() }
    }

    // ------------------------------------------------------------ stage ---
    Item {
        id: stage
        anchors.fill: parent
        // nothing shows until the frame is in: until then the screen itself is visible
        visible: frozen.hasContent

        ScreencopyView {
            id: frozen
            anchors.fill: parent
            captureSource: win.screen
            live: false
            onHasContentChanged: if (hasContent && Shot.mode === "full")
                win.commit(0, 0, win.w, win.h)
        }

        // dim everything but the box
        Item {
            id: scrim
            anchors.fill: parent
            visible: Shot.mode !== "full"
            property color tint: Theme.alpha("#000000", win.phase === "aim" && !win.hovered ? 0.22 : 0.45)
            Behavior on tint { ColAnim {} }
            Rectangle { x: 0; y: 0; width: win.w; height: Math.max(0, win.by); color: scrim.tint }
            Rectangle { x: 0; y: win.by + win.bh; width: win.w; height: Math.max(0, win.h - win.by - win.bh); color: scrim.tint }
            Rectangle { x: 0; y: win.by; width: Math.max(0, win.bx); height: win.bh; color: scrim.tint }
            Rectangle { x: win.bx + win.bw; y: win.by; width: Math.max(0, win.w - win.bx - win.bw); height: win.bh; color: scrim.tint }
        }

        // the box outline
        Rectangle {
            x: win.bx - 1
            y: win.by - 1
            width: win.bw + 2
            height: win.bh + 2
            visible: win.bw > 0 && Shot.mode !== "full"
            color: "transparent"
            border.width: 1.5
            border.color: Theme.alpha(Theme.grad1, win.cornered ? 0.95 : 0.5)
        }

        // the white flash on capture
        Rectangle {
            id: flashRect
            x: win.bx
            y: win.by
            width: win.bw
            height: win.bh
            color: "white"
            opacity: 0
            NumberAnimation on opacity {
                id: flash
                running: false
                from: 0.55
                to: 0
                duration: 380
                easing.type: Easing.OutCubic
            }
        }

        // ---- threads: one per screen corner, tied to the same box corner ----
        Repeater {
            id: threads
            model: [[0, 0], [1, 0], [0, 1], [1, 1]]
            Thread {
                required property var modelData
                required property int index
                anchors.fill: parent
                visible: Shot.mode !== "full"
                readonly property real ax: modelData[0] * win.w
                readonly property real ay: modelData[1] * win.h
                readonly property real tx: win.cornered ? win.bx + modelData[0] * win.bw : win.cx
                readonly property real ty: win.cornered ? win.by + modelData[1] * win.bh : win.cy
                from: Qt.point(ax, ay)
                to: Qt.point(tx + (ax - tx) * win.retract, ty + (ay - ty) * win.retract + win.fall)
                color: Qt.rgba(Theme.grad1.r + (Theme.grad2.r - Theme.grad1.r) * index / 3, Theme.grad1.g + (Theme.grad2.g - Theme.grad1.g) * index / 3, Theme.grad1.b + (Theme.grad2.b - Theme.grad1.b) * index / 3, 1)
                thickness: 2
                slack: win.cornered ? 0.035 : 0.06
            }
        }

        // knots: one at the cursor while aiming, then one on each box corner
        Repeater {
            model: 4
            Knot {
                required property int index
                readonly property var t: threads.itemAt(index)
                x: (t ? t.to.x : 0) - width / 2
                y: (t ? t.to.y : 0) - height / 2
                color: t ? t.color : Theme.grad1
                shown: win.cornered && win.retract < 0.9 && Shot.mode !== "full"
            }
        }
        Knot {
            x: win.cx - width / 2
            y: win.cy - height / 2 + win.fall
            color: Theme.grad1
            size: 16
            shown: !win.cornered && win.hasCursor && Shot.mode !== "full"
        }

        // size, in real pixels
        Rectangle {
            id: sizePill
            visible: win.bw > 0 && win.retract === 0 && Shot.mode !== "full" && (win.cornered || win.hovered)
            readonly property real px: Math.min(win.w - width - 8, win.bx + win.bw - width)
            readonly property real belowY: win.by + win.bh + 10
            x: Math.max(8, px)
            y: belowY + height + 8 > win.h ? win.by + win.bh - height - 10 : belowY
            width: sizeTxt.implicitWidth + 20
            height: 26
            radius: height / 2
            color: Theme.alpha(Theme.surface, 0.9)
            border.width: 1
            border.color: Theme.alpha(Theme.grad1, 0.5)
            Txt {
                id: sizeTxt
                anchors.centerIn: parent
                text: Math.round(win.bw * win.scale) + " × " + Math.round(win.bh * win.scale)
                font.family: Theme.mono
                font.pixelSize: 12
            }
        }

        // what you can do
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28
            visible: win.phase === "aim" && Shot.mode !== "full"
            width: hint.implicitWidth + 32
            height: 34
            radius: height / 2
            color: Theme.alpha(Theme.surface, 0.88)
            border.width: 1
            border.color: Theme.alpha(Theme.grad1, 0.35)
            Txt {
                id: hint
                anchors.centerIn: parent
                text: (win.windowMode ? "Click a window" : "Drag to select  ·  click a window") + "  ·  Enter whole screen  ·  C colour  ·  Tab " + (win.windowMode ? "region" : "window") + " mode  ·  Esc cancel"
                font.pixelSize: 12
                color: Theme.fgDim
            }
        }
    }

    // ------------------------------------------------------------ input ---
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        enabled: win.phase === "aim" || win.phase === "drag"

        property real sx: 0
        property real sy: 0

        onPositionChanged: m => {
            win.cx = m.x;
            win.cy = m.y;
            win.hasCursor = true;
            if (!pressed || win.windowMode)
                return;
            if (win.phase === "aim" && Math.hypot(m.x - sx, m.y - sy) > 4) {
                win.glide = false;
                win.phase = "drag";
            }
            if (win.phase === "drag") {
                win.bx = Math.min(sx, m.x);
                win.by = Math.min(sy, m.y);
                win.bw = Math.abs(m.x - sx);
                win.bh = Math.abs(m.y - sy);
            }
        }
        onPressed: m => {
            if (m.button === Qt.RightButton) {
                win.cancel();
                return;
            }
            sx = m.x;
            sy = m.y;
        }
        onReleased: m => {
            if (m.button !== Qt.LeftButton)
                return;
            if (win.phase === "drag")
                win.commit(win.bx, win.by, win.bw, win.bh);
            else if (win.hovered)
                win.commit(win.hovered.x, win.hovered.y, win.hovered.w, win.hovered.h);
            else if (!win.windowMode)
                win.commit(0, 0, win.w, win.h);
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape)
                win.cancel();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                win.commit(0, 0, win.w, win.h);
            else if (e.key === Qt.Key_C && win.phase === "aim") {
                win.cancel();
                Shot.pickColor();
            } else if (e.key === Qt.Key_Tab && win.phase === "aim")
                Shot.mode = win.windowMode ? "region" : "window";
            else
                return;
            e.accepted = true;
        }
    }
}
