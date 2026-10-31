import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// The tones: Prism's built-in ones and the system's sounds. ▶ plays a few seconds.
ColumnLayout {
    id: root

    property string current: ""
    property bool allowDefault: false // "Default" = the group's or the settings' tone
    signal picked(string id)

    spacing: 2
    Component.onCompleted: Chrono.loadTones()

    Repeater {
        model: (root.allowDefault ? [""] : []).concat(Chrono.builtinTones.map(t => t.id)).concat(Chrono.systemTones)
        Rectangle {
            id: tone
            required property string modelData
            readonly property bool on: modelData === root.current
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Theme.r.md
            color: on ? Theme.alpha(Theme.primary, 0.16) : "transparent"
            Interactive {
                radius: parent.radius
                onClicked: root.picked(tone.modelData)
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 4
                Icon {
                    icon: tone.on ? "radiobox_marked" : "radiobox_blank"
                    size: 18
                    color: tone.on ? Theme.primary : Theme.fgDim
                }
                Txt {
                    Layout.fillWidth: true
                    text: Chrono.toneName(tone.modelData)
                    font.pixelSize: 13
                }
                IconBtn {
                    visible: tone.modelData !== ""
                    icon: "play"
                    size: 30
                    tooltip: "Listen"
                    onClicked: Chrono.preview(tone.modelData)
                }
            }
        }
    }
}
