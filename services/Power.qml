pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.common

Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev?.isLaptopBattery ?? false
    // UPower reports 0..1 in Quickshell 0.2+, 0..100 before; normalise.
    readonly property real level: {
        const p = dev?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }
    readonly property int percent: Math.round(level * 100)
    readonly property int state: dev?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged || (!UPower.onBattery && percent >= 95)
    readonly property bool onBattery: UPower.onBattery
    readonly property bool low: onBattery && percent <= Config.battery.warn
    readonly property bool critical: onBattery && percent <= Config.battery.critical
    readonly property real timeLeft: charging ? (dev?.timeToFull ?? 0) : (dev?.timeToEmpty ?? 0)
    readonly property real rate: Math.abs(dev?.changeRate ?? 0)

    readonly property string icon: {
        if (charging)
            return "battery_charging";
        if (!onBattery && full)
            return "battery_charging_100";
        if (percent >= 95)
            return "battery";
        if (percent < 8)
            return "battery_alert";
        return "battery_" + Math.max(10, Math.floor(percent / 10) * 10);
    }

    readonly property string statusText: {
        if (charging)
            return timeLeft > 0 ? Utils.human(timeLeft) + " until full" : "Charging";
        if (!onBattery)
            return full ? "Fully charged" : "Plugged in";
        return timeLeft > 0 ? Utils.human(timeLeft) + " remaining" : "On battery";
    }

    // other UPower devices with batteries (controllers, headsets, mice ...)
    readonly property var peripherals: UPower.devices.values.filter(d => !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.type !== UPowerDeviceType.Battery && d.isPresent && d.percentage > 0)

    // ---- power profiles ----
    readonly property int profile: PowerProfiles.profile
    readonly property string profileName: profile === PowerProfile.Performance ? "Performance" : profile === PowerProfile.PowerSaver ? "Power saver" : "Balanced"
    readonly property string profileIcon: profile === PowerProfile.Performance ? "rocket_launch" : profile === PowerProfile.PowerSaver ? "leaf" : "scale_balance"

    function cycleProfile() {
        const order = PowerProfiles.hasPerformanceProfile ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced];
        const i = order.indexOf(PowerProfiles.profile);
        setProfile(order[(i + 1) % order.length]);
    }
    function setProfile(p) {
        PowerProfiles.profile = p;
        Osd.show("toggle", root.profileIconFor(p), root.profileNameFor(p), -1);
    }
    function profileNameFor(p) {
        return p === PowerProfile.Performance ? "Performance" : p === PowerProfile.PowerSaver ? "Power saver" : "Balanced";
    }
    function profileIconFor(p) {
        return p === PowerProfile.Performance ? "rocket_launch" : p === PowerProfile.PowerSaver ? "leaf" : "scale_balance";
    }

    // ---- warnings ----
    property int lastWarned: 101
    onPercentChanged: {
        if (!onBattery) {
            lastWarned = 101;
            return;
        }
        if (percent <= Config.battery.critical && lastWarned > Config.battery.critical) {
            lastWarned = percent;
            Notifs.local("Battery critical", percent + "% left — plug in now", "battery_alert", 2);
        } else if (percent <= Config.battery.warn && lastWarned > Config.battery.warn) {
            lastWarned = percent;
            Notifs.local("Battery low", percent + "% left · " + statusText, "battery_20", 1);
        }
    }
    onChargingChanged: if (Osd.armed) Osd.show("toggle", charging ? "battery_charging" : icon, charging ? "Charging · " + percent + "%" : "On battery · " + percent + "%", level)
}
