import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Find a city (any time zone) for the world clock.
ColumnLayout {
    id: root

    property var win
    property string q: ""
    readonly property var results: {
        const s = q.trim().toLowerCase().replace(/ /g, "_");
        const all = Chrono.allZones.filter(z => Chrono.d.cities.indexOf(z) < 0);
        return (s === "" ? all : all.filter(z => z.toLowerCase().indexOf(s) >= 0)).slice(0, 40);
    }

    spacing: 10
    Component.onCompleted: Chrono.loadZones()

    Txt {
        text: "Add a city"
        font.pixelSize: 18
        font.weight: Font.Bold
    }
    InputField {
        id: search
        Layout.fillWidth: true
        placeholder: "Search: Tokyo, London, New York …"
        fontSize: 14
        onTextChanged: root.q = text
        onAccepted: if (root.results.length) pick(root.results[0])
        Component.onCompleted: focusInput()
        function pick(z) {
            Chrono.addCity(z);
            root.win.closeSheet();
        }
    }
    Repeater {
        model: root.results
        Rectangle {
            required property string modelData
            Layout.fillWidth: true
            implicitHeight: 42
            radius: Theme.r.md
            color: "transparent"
            Interactive {
                radius: parent.radius
                onClicked: search.pick(parent.modelData)
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                Txt {
                    Layout.fillWidth: true
                    text: Chrono.cityName(parent.parent.modelData)
                    font.pixelSize: 14
                }
                Txt {
                    text: parent.parent.modelData.split("/").slice(0, -1).join(" / ").replace(/_/g, " ")
                    font.pixelSize: 12
                    color: Theme.fgDim
                }
            }
        }
    }
}
