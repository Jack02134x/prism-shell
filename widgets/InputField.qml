import QtQuick
import qs.common

// Rounded text input with an icon and an animated focus outline.
Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: "magnify"
    property color accent: Theme.primary
    property bool password: false
    property real fontSize: 15

    // let Left/Right move the selection (grids)
    property bool horizontalNav: false

    signal accepted
    signal submitted(int modifiers)
    signal escaped
    signal navigate(int delta, bool vertical)
    signal deleteRequested

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitHeight: 46
    radius: Theme.r.md
    color: Theme.alpha(Theme.surfaceHighest, 0.7)
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? accent : Theme.alpha(Theme.outline, 0.4)
    Behavior on border.color { ColAnim {} }

    Icon {
        id: ico
        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        size: 18
        color: input.activeFocus ? root.accent : Theme.fgDim
    }

    TextInput {
        id: input
        anchors.left: ico.visible ? ico.right : parent.left
        anchors.leftMargin: ico.visible ? 10 : 16
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: root.fontSize
        selectionColor: Theme.alpha(root.accent, 0.4)
        selectedTextColor: Theme.fg
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "●"
        clip: true
        Keys.onEscapePressed: event => {
            root.escaped();
            event.accepted = false;
        }
        Keys.onPressed: event => {
            const k = event.key;
            const shift = event.modifiers & Qt.ShiftModifier;
            if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                root.submitted(event.modifiers);
                root.accepted();
            } else if (k === Qt.Key_Down || (k === Qt.Key_J && event.modifiers & Qt.ControlModifier)) {
                root.navigate(1, true);
            } else if (k === Qt.Key_Up || (k === Qt.Key_K && event.modifiers & Qt.ControlModifier)) {
                root.navigate(-1, true);
            } else if (k === Qt.Key_Tab && !shift) {
                root.navigate(1, false);
            } else if (k === Qt.Key_Backtab) {
                root.navigate(-1, false);
            } else if (k === Qt.Key_PageDown) {
                root.navigate(5, true);
            } else if (k === Qt.Key_PageUp) {
                root.navigate(-5, true);
            } else if (k === Qt.Key_Delete && shift) {
                root.deleteRequested();
            } else if ((k === Qt.Key_Left || k === Qt.Key_Right) && root.horizontalNav) {
                root.navigate(k === Qt.Key_Right ? 1 : -1, false);
            } else {
                return;
            }
            event.accepted = true;
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Theme.alpha(Theme.fgDim, 0.7)
            font.pixelSize: root.fontSize
            visible: input.text.length === 0
        }
    }
}
