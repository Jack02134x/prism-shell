import QtQuick
import qs.common

// Nerd Font glyph by name ("wifi" -> md-wifi). Bounces whenever the glyph changes.
Text {
    id: root

    property string icon: ""
    property real size: 18
    property bool bounce: true

    text: Icons.get(icon)
    font.family: Theme.iconFont
    font.pixelSize: size
    color: Theme.fg
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    onIconChanged: if (bounce && visible) pop.restart()

    SequentialAnimation {
        id: pop
        NumberAnimation { target: root; property: "scale"; to: 0.55; duration: 70; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }
}
