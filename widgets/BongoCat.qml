import QtQuick
import QtQuick.Shapes
import qs.common
import qs.services

// A bongo cat (original drawing) playing two bongos to the music. A paw slaps a
// drum whenever the bass rises quickly (an onset, from cava), alternating
// left / right; the drum squashes and a note floats up. The head bobs with the
// loudness. Paused: it dozes off. Drawn in a 320 × 300 box and scaled to fit.
// It only listens to Cava; whatever shows it (the Media tab's visualizer) keeps cava running.
Item {
    id: root

    property bool playing: Media.playing
    readonly property bool live: visible && playing

    implicitWidth: 320
    implicitHeight: 300

    readonly property color fur: "#fbf8f4"
    readonly property color ink: "#26222b"
    readonly property color pink: "#ffaabd"

    // ---- beat → paws ----
    property bool leftDown: false
    property bool rightDown: false
    property bool nextLeft: true
    property real low: 0 // recent low of the bass; a hit is a quick rise above it
    property real lastTap: 0
    property int noteSeq: 0

    function tap() {
        if (nextLeft)
            leftDown = true;
        else
            rightDown = true;
        notes.itemAt(noteSeq % 4)?.fly(nextLeft);
        noteSeq++;
        nextLeft = !nextLeft;
        lastTap = Date.now();
        release.restart();
    }
    Connections {
        target: Cava
        enabled: root.live
        // onset detection: cava's bass is smooth, so watch for rises, not levels
        function onBassChanged() {
            const b = Cava.bass;
            root.low = Math.min(root.low + 0.004, b);
            if (b - root.low > 0.07 && b > 0.08 && Date.now() - root.lastTap > 150) {
                root.tap();
                root.low = b; // the next hit needs a fresh rise
            }
        }
    }
    // no cava data (very quiet track): keep a gentle tempo
    Timer {
        interval: 480
        repeat: true
        running: root.live
        onTriggered: if (Date.now() - root.lastTap > 1300) root.tap()
    }
    Timer {
        id: release
        interval: 140
        onTriggered: root.leftDown = root.rightDown = false
    }
    onPlayingChanged: if (!playing) leftDown = rightDown = false

    Item {
        id: art
        width: 320
        height: 300
        anchors.centerIn: parent
        scale: Math.min(root.width / 320, root.height / 300)

        // ---- the cat (bobs with the music) ----
        Item {
            id: cat
            width: 320
            height: 300
            y: root.playing ? -Math.min(1, Cava.level * 2.2) * 7 : 4
            Behavior on y { NumberAnimation { duration: 90 } }

            // ears (behind the head)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.fur; strokeColor: root.ink; strokeWidth: 5; joinStyle: ShapePath.RoundJoin
                    startX: 82; startY: 112
                    PathLine { x: 98; y: 34 }
                    PathLine { x: 150; y: 84 }
                }
                ShapePath {
                    fillColor: root.fur; strokeColor: root.ink; strokeWidth: 5; joinStyle: ShapePath.RoundJoin
                    startX: 238; startY: 112
                    PathLine { x: 222; y: 34 }
                    PathLine { x: 170; y: 84 }
                }
                ShapePath {
                    fillColor: root.pink; strokeColor: "transparent"
                    startX: 96; startY: 98
                    PathLine { x: 104; y: 56 }
                    PathLine { x: 134; y: 86 }
                }
                ShapePath {
                    fillColor: root.pink; strokeColor: "transparent"
                    startX: 224; startY: 98
                    PathLine { x: 216; y: 56 }
                    PathLine { x: 186; y: 86 }
                }
            }

            // head + body
            Rectangle {
                x: 58
                y: 66
                width: 204
                height: 196
                radius: 96
                color: root.fur
                border.color: root.ink
                border.width: 5
            }

            // eyes: shiny while playing, closed while dozing
            Repeater {
                model: [126, 194]
                Item {
                    required property int modelData
                    x: modelData - 13
                    y: 136
                    width: 26
                    height: 32
                    Rectangle {
                        visible: root.playing
                        anchors.fill: parent
                        radius: 13
                        color: root.ink
                        Rectangle { x: 6; y: 6; width: 9; height: 9; radius: 4.5; color: "white" }
                        Rectangle { x: 15; y: 19; width: 4; height: 4; radius: 2; color: "white"; opacity: 0.8 }
                    }
                    Shape {
                        visible: !root.playing
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "transparent"; strokeColor: root.ink; strokeWidth: 5; capStyle: ShapePath.RoundCap
                            startX: 0; startY: 16
                            PathQuad { x: 26; y: 16; controlX: 13; controlY: 28 }
                        }
                    }
                }
            }
            // blush
            Rectangle { x: 88; y: 178; width: 30; height: 16; radius: 8; color: root.pink; opacity: 0.75 }
            Rectangle { x: 202; y: 178; width: 30; height: 16; radius: 8; color: root.pink; opacity: 0.75 }
            // mouth "ω" (open when a paw comes down)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeColor: root.ink; strokeWidth: 4.5; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                    startX: 144; startY: 176
                    PathQuad { x: 160; y: 178; controlX: 151; controlY: 190 }
                    PathQuad { x: 176; y: 176; controlX: 169; controlY: 190 }
                }
            }
            Rectangle {
                visible: root.leftDown || root.rightDown
                x: 152; y: 184; width: 16; height: 10; radius: 5
                color: "#e25d7a"
                border.color: root.ink
                border.width: 2.5
            }
        }

        // ---- bongos (left, right) ----
        Repeater {
            model: 2
            Item {
                id: drum
                required property int index
                readonly property bool hit: index ? root.rightDown : root.leftDown
                x: index ? 166 : 34
                y: 212
                width: 120
                height: 84
                transform: Scale {
                    origin.x: 60
                    origin.y: 84
                    yScale: drum.hit ? 0.9 : 1
                    xScale: drum.hit ? 1.04 : 1
                    Behavior on yScale { NumberAnimation { duration: 70 } }
                    Behavior on xScale { NumberAnimation { duration: 70 } }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: drum.index ? Theme.grad2 : Theme.grad1
                        strokeColor: root.ink; strokeWidth: 5; joinStyle: ShapePath.RoundJoin
                        startX: 4; startY: 18
                        PathLine { x: 18; y: 80 }
                        PathLine { x: 102; y: 80 }
                        PathLine { x: 116; y: 18 }
                    }
                    // a band round the middle
                    ShapePath {
                        fillColor: "transparent"; strokeColor: Qt.rgba(0, 0, 0, 0.25); strokeWidth: 6
                        startX: 11; startY: 50
                        PathLine { x: 109; y: 50 }
                    }
                }
                // drum head
                Rectangle {
                    x: 0; y: 6; width: 120; height: 26; radius: 13
                    color: "#f3e3c3"
                    border.color: root.ink
                    border.width: 5
                }
            }
        }

        // ---- paws (in front, above / on the drums) ----
        Repeater {
            model: 2
            Item {
                id: paw
                required property int index
                readonly property bool down: index ? root.rightDown : root.leftDown
                // raised: up and out beside the head; down: on the drum head
                x: down ? (index ? 195 : 63) : (index ? 222 : 36)
                y: down ? 186 : 118
                rotation: down ? 0 : (index ? 28 : -28)
                width: 62
                height: 52
                Behavior on x { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                Behavior on y { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                Behavior on rotation { NumberAnimation { duration: 60 } }
                Rectangle {
                    anchors.fill: parent
                    radius: 26
                    color: root.fur
                    border.color: root.ink
                    border.width: 5
                }
                // toe beans
                Rectangle { x: 22; y: 24; width: 18; height: 14; radius: 7; color: root.pink }
                Rectangle { x: 12; y: 12; width: 8; height: 8; radius: 4; color: root.pink }
                Rectangle { x: 27; y: 8; width: 8; height: 8; radius: 4; color: root.pink }
                Rectangle { x: 42; y: 12; width: 8; height: 8; radius: 4; color: root.pink }
            }
        }

        // ---- notes that float up on a hit ----
        Repeater {
            id: notes
            model: 4
            Text {
                id: note
                required property int index
                text: index % 2 ? "♪" : "♫"
                font.pixelSize: 34
                font.bold: true
                color: index % 2 ? Theme.grad1 : Theme.grad2
                opacity: 0
                function fly(left) {
                    x = left ? 30 + Math.random() * 30 : 250 + Math.random() * 30;
                    y = 150;
                    flight.restart();
                }
                ParallelAnimation {
                    id: flight
                    NumberAnimation { target: note; property: "y"; to: 40; duration: 1100; easing.type: Easing.OutQuad }
                    SequentialAnimation {
                        NumberAnimation { target: note; property: "opacity"; to: 1; duration: 120 }
                        NumberAnimation { target: note; property: "opacity"; to: 0; duration: 980 }
                    }
                }
            }
        }

        // ---- dozing ----
        Text {
            visible: !root.playing
            x: 236
            y: 40
            text: "z"
            font.pixelSize: 40
            font.bold: true
            color: Theme.fgDim
            SequentialAnimation on y {
                running: !root.playing && root.visible
                loops: Animation.Infinite
                NumberAnimation { from: 60; to: 20; duration: 1600; easing.type: Easing.InOutSine }
                NumberAnimation { from: 20; to: 60; duration: 0 }
            }
            SequentialAnimation on opacity {
                running: !root.playing && root.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: 400 }
                NumberAnimation { from: 1; to: 0; duration: 1200 }
            }
        }
    }
}
