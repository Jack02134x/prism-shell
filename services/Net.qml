pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wiredUp: wired?.connected ?? false

    readonly property var networks: {
        if (!wifi)
            return [];
        const seen = {};
        const out = [];
        for (const n of wifi.networks.values) {
            if (!n.name || seen[n.name])
                continue;
            seen[n.name] = true;
            out.push(n);
        }
        return out.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }
    readonly property var active: networks.find(n => n.connected) ?? null
    readonly property bool connected: wiredUp || active !== null
    // Quickshell reports 0..1 (older builds 0..100)
    readonly property real strength: strengthOf(active)
    readonly property string name: wiredUp ? "Ethernet" : (active?.name ?? (wifiEnabled ? "Not connected" : "Wi-Fi off"))

    readonly property string icon: {
        if (wiredUp)
            return "ethernet";
        if (!wifiEnabled)
            return "wifi_off";
        if (!active)
            return "wifi_strength_outline";
        if (strength > 0.75)
            return "wifi_strength_4";
        if (strength > 0.5)
            return "wifi_strength_3";
        if (strength > 0.25)
            return "wifi_strength_2";
        return "wifi_strength_1";
    }

    function strengthOf(n) {
        // networks can disappear mid-scan; never let a stale object yield NaN
        const s = Number(n?.signalStrength ?? 0);
        if (!isFinite(s))
            return 0;
        return s > 1 ? s / 100 : s;
    }
    function iconOf(n) {
        const s = strengthOf(n);
        return s > 0.75 ? "wifi_strength_4" : s > 0.5 ? "wifi_strength_3" : s > 0.25 ? "wifi_strength_2" : "wifi_strength_1";
    }
    function secured(n) {
        return n?.security !== undefined && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown;
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
        Osd.show("toggle", Networking.wifiEnabled ? "wifi" : "wifi_off", Networking.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off", -1);
    }
    function scan(on) {
        if (wifi)
            wifi.scannerEnabled = on;
    }
    function connectTo(n, psk) {
        if (psk && psk.length > 0)
            n.connectWithPsk(psk);
        else
            n.connect();
    }
}
