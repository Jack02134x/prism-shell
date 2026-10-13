pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

// 20-20-20 eye-break reminder: after N minutes of actual use (idle time and
// fullscreen-free breaks don't count), nudge to look 20 ft away for 20 s.
Singleton {
    id: root

    property real activeSeconds: 0
    readonly property real dueSeconds: Config.breaks.everyMinutes * 60
    readonly property bool enabled: Config.breaks.eyeReminder

    // two minutes without input counts as a real break
    IdleMonitor {
        id: idle
        enabled: root.enabled
        timeout: 120
        respectInhibitors: false
        onIsIdleChanged: if (isIdle) root.activeSeconds = 0
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.enabled
        onTriggered: {
            if (idle.isIdle || Focus.phase === "break" || Focus.phase === "longbreak")
                return;
            root.activeSeconds += interval / 1000;
            if (root.activeSeconds >= root.dueSeconds) {
                root.activeSeconds = 0;
                Osd.show("toggle", "eye_outline", "Eye break · look far away for 20 s", -1);
                Notifs.local("Eye break 👀", "You've been staring for " + Config.breaks.everyMinutes + " minutes. Look at something ~6 m away for 20 seconds.", "eye_outline", 0, "", [{ text: "Snooze 10 min", run: () => root.activeSeconds = root.dueSeconds - 600 }]);
            }
        }
    }
}
