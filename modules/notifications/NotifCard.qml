pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// One notification. Used by the popup stack and the notification center.
// Drag sideways to dismiss; hover pauses the timeout.
Item {
    id: root

    required property var entry
    property bool popup: false
    property bool compact: false
    readonly property color accent: entry?.accent ?? Theme.primary
    property bool leaving: false

    implicitWidth: 400
    implicitHeight: card.implicitHeight

    function leave(dismiss) {
        if (leaving)
            return;
        leaving = true;
        exitAnim.dismiss = dismiss;
        exitAnim.start();
    }

    // ---- timeout (popups only) ----
    property real remaining: 1
    NumberAnimation on remaining {
        id: countdown
        running: root.popup && root.entry && root.entry.timeout > 0 && !hover.hovered && !drag.active
        from: root.remaining
        to: 0
        duration: Math.max(1, (root.entry?.timeout ?? 1) * root.remaining)
        onFinished: if (root.remaining <= 0.001) root.leave(false)
    }

    SequentialAnimation {
        id: exitAnim
        property bool dismiss: false
        ParallelAnimation {
            NumberAnimation { target: card; property: "x"; to: card.x >= 0 ? root.width + 40 : -root.width - 40; duration: Motion.normal; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: Motion.normal }
        }
        ScriptAction {
            script: {
                if (exitAnim.dismiss)
                    root.entry.dismiss();
                else
                    root.entry.expireNow();
            }
        }
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: col.implicitHeight + 24
        radius: Theme.r.lg
        color: Theme.alpha(Theme.surfaceContainer, root.popup ? 0.96 : 0.85)
        border.width: 1
        border.color: Theme.alpha(root.accent, root.entry?.critical ? 0.9 : 0.35)
        opacity: 1 - Math.min(1, Math.abs(x) / (root.width * 0.8))

        // entrance
        transform: Translate { id: enterT; x: root.popup ? 420 : 0 }
        Component.onCompleted: if (root.popup) enterAnim.start()
        NumberAnimation {
            id: enterAnim
            target: enterT
            property: "x"
            to: 0
            duration: Motion.slower
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatial
        }

        // accent stripe
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 10
            width: 4
            radius: 2
            gradient: Gradient {
                GradientStop { position: 0; color: root.accent }
                GradientStop { position: 1; color: Theme.accent(Math.abs(root.entry?.appName?.length ?? 0) + 4) }
            }
        }

        // critical glow
        GlowBorder {
            visible: root.entry?.critical ?? false
            radius: card.radius
            pad: 10
            glow: 0.8
            speed: 6
            c1: Theme.error
            c2: "#ff9f43"
            c3: Theme.error
            c4: "#ff5ea8"
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 24
            anchors.rightMargin: 14
            anchors.topMargin: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // icon / image
                Item {
                    Layout.preferredWidth: root.compact ? 36 : 46
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignTop

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Theme.alpha(root.accent, 0.18)

                        Image {
                            id: img
                            anchors.fill: parent
                            source: root.entry ? Notifs.iconFor(root.entry) : ""
                            fillMode: (root.entry?.image ?? "") !== "" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                            anchors.margins: (root.entry?.image ?? "") !== "" ? 0 : 7
                            asynchronous: true
                            sourceSize.width: 128
                            sourceSize.height: 128
                            visible: status === Image.Ready
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !img.visible
                            icon: root.entry?.glyph || "bell_ring"
                            size: parent.width * 0.5
                            color: root.accent
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Txt {
                            text: root.entry?.appName ?? ""
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.accent
                            Layout.maximumWidth: 180
                        }
                        Txt {
                            text: "· " + (root.entry ? Utils.timeAgo(root.entry.time) : "")
                            font.pixelSize: 11
                            color: Theme.fgDim
                            Layout.fillWidth: true
                        }
                        IconBtn {
                            icon: "close"
                            size: 24
                            iconSize: 13
                            idleColor: Theme.alpha(Theme.fg, 0.06)
                            onClicked: root.leave(true)
                        }
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: root.entry?.summary ?? ""
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                    Txt {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.entry?.body ?? ""
                        textFormat: Text.StyledText
                        linkColor: Theme.accent(2)
                        font.pixelSize: 12
                        color: Theme.fgDim
                        wrapMode: Text.Wrap
                        maximumLineCount: root.compact ? 2 : 5
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }

            // actions
            Flow {
                Layout.fillWidth: true
                visible: (root.entry?.actions?.length ?? 0) > 0
                spacing: 6
                Repeater {
                    model: root.entry?.actions ?? []
                    Btn {
                        required property var modelData
                        required property int index
                        text: modelData.text || "Open"
                        accent: Theme.accent(index * 3 + 1)
                        filled: index === 0
                        implicitHeight: 30
                        fontSize: 12
                        onClicked: root.entry.invoke(modelData)
                    }
                }
            }

            // timeout bar
            Rectangle {
                visible: root.popup && (root.entry?.timeout ?? 0) > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: 2
                color: Theme.alpha(Theme.fg, 0.08)
                Rectangle {
                    width: parent.width * root.remaining
                    height: parent.height
                    radius: 2
                    color: root.accent
                }
            }
        }

        HoverHandler {
            id: hover
        }

        DragHandler {
            id: drag
            yAxis.enabled: false
            onActiveChanged: {
                if (!active) {
                    if (Math.abs(card.x) > root.width * 0.35)
                        root.leave(true);
                    else
                        snapBack.start();
                }
            }
        }
        NumberAnimation {
            id: snapBack
            target: card
            property: "x"
            to: 0
            duration: Motion.normal
            easing.type: Easing.OutBack
        }

        TapHandler {
            acceptedButtons: Qt.MiddleButton
            onTapped: root.leave(true)
        }
    }
}
