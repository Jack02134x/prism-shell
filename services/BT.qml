pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property var devices: (adapter?.devices.values ?? []).slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || String(a.name).localeCompare(String(b.name)))
    readonly property var connected: devices.filter(d => d.connected)
    readonly property string icon: !enabled ? "bluetooth_off" : connected.length > 0 ? "bluetooth_connect" : "bluetooth"
    readonly property string summary: !enabled ? "Off" : connected.length === 1 ? connected[0].name : connected.length > 1 ? connected.length + " devices" : "On"

    function toggle() {
        if (!adapter)
            return;
        adapter.enabled = !adapter.enabled;
        Osd.show("toggle", adapter.enabled ? "bluetooth" : "bluetooth_off", adapter.enabled ? "Bluetooth on" : "Bluetooth off", -1);
    }
    function scan(on) {
        if (adapter && adapter.enabled)
            adapter.discovering = on;
    }
    function deviceIcon(d) {
        const i = String(d?.icon ?? "");
        if (i.includes("headset") || i.includes("headphone"))
            return "headphones";
        if (i.includes("audio") || i.includes("speaker"))
            return "speaker";
        if (i.includes("phone"))
            return "cellphone";
        if (i.includes("mouse"))
            return "mouse";
        if (i.includes("keyboard"))
            return "keyboard";
        if (i.includes("gaming") || i.includes("joystick"))
            return "google_controller";
        if (i.includes("computer"))
            return "laptop";
        return "bluetooth";
    }
    function act(d) {
        if (d.connected)
            d.disconnect();
        else if (d.paired)
            d.connect();
        else
            d.pair();
    }
}
