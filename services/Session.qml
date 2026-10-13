pragma Singleton

import QtQuick
import Quickshell
import qs.common

Singleton {
    id: root

    // true while the Quickshell lock screen is engaged
    property bool locked: false
    // render the lock UI in a normal overlay without locking (for previewing)
    property bool preview: false

    function lock() {
        if (Config.lock.enabled)
            locked = true;
        else
            Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"]);
    }
    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }
    function hibernate() {
        Quickshell.execDetached(["systemctl", "hibernate"]);
    }
    function logout() {
        Hypr.dispatch("hl.dsp.exit()");
    }
    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function shutdown() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }
    function firmware() {
        Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
    }
}
