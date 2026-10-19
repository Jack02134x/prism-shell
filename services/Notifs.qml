pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.common

// Notification daemon + history. Also carries "local" notifications the shell
// raises itself (battery, screenshots ...) so those work even under swaync.
Singleton {
    id: root

    property bool dnd: false
    property var list: []          // newest first
    readonly property var popups: list.filter(e => e.popup)
    readonly property int count: list.length
    property bool foreignDaemon: false
    property int unread: 0

    component Entry: QtObject {
        id: entry

        property var notif: null
        property string appName: notif?.appName ?? "Prism"
        property string appIcon: notif?.appIcon ?? ""
        property string summary: notif?.summary ?? ""
        property string body: notif?.body ?? ""
        property string image: notif?.image ?? ""
        property int urgency: notif ? notif.urgency : 1
        property real expire: notif?.expireTimeout ?? -1
        property string glyph: ""
        property var actions: notif ? notif.actions.map(a => ({ id: a.identifier, text: a.text, ref: a })) : []
        property var localActions: []
        property date time: new Date()
        property bool popup: true
        readonly property bool critical: urgency === NotificationUrgency.Critical || urgency === 2
        readonly property int timeout: critical ? 0 : (expire > 0 ? expire : Config.notifications.timeout)
        readonly property color accent: critical ? Theme.error : Theme.accentFor(appName)

        readonly property Connections conn: Connections {
            target: entry.notif
            function onClosed() {
                root.drop(entry);
            }
            function onSummaryChanged() {
                entry.time = new Date();
                if (!root.dnd)
                    entry.popup = true;
            }
        }

        function invoke(a) {
            if (a.ref)
                a.ref.invoke();
            else if (a.run)
                a.run();
            if (!notif?.resident)
                dismiss();
        }
        function dismiss() {
            if (notif)
                notif.dismiss();
            else
                root.drop(entry);
        }
        function expireNow() {
            popup = false;
            if (notif?.transient)
                notif.expire();
        }
    }

    Component {
        id: entryComp
        Entry {}
    }

    // which notifications already popped up; survives shell reloads (the server
    // keeps notifications across reloads, and they must not pop up a second time)
    // stored as a string: object values don't reliably survive a reload
    PersistentProperties {
        id: memory
        reloadableId: "prism-notifications"
        property string popped: ""
    }
    function poppedIds() {
        return (memory.popped || "").split(",").filter(x => x !== "");
    }

    function add(entry) {
        const n = entry.notif;
        if (n) {
            // the same notification handed over twice after a reload: keep one
            if (list.some(e => e.notif === n)) {
                entry.destroy();
                return;
            }
            const ids = poppedIds();
            if (ids.includes(String(n.id)))
                entry.popup = false;
            else if (entry.popup)
                memory.popped = ids.concat([String(n.id)]).slice(-200).join(",");
        }
        const l = list.slice();
        l.unshift(entry);
        while (l.length > 60) {
            const old = l.pop();
            old.destroy();
        }
        list = l;
        if (dnd && !entry.critical)
            entry.popup = false;
        unread++;
    }

    function drop(entry) {
        const i = list.indexOf(entry);
        if (i < 0)
            return;
        const l = list.slice();
        l.splice(i, 1);
        list = l;
        entry.destroy(1000);
    }

    function clear() {
        for (const e of list.slice())
            e.dismiss();
    }

    function hidePopups() {
        for (const e of list)
            e.popup = false;
    }

    // urgency: 0 low, 1 normal, 2 critical. actions: [{ text, run }]
    function local(summary, body, glyph, urgency, image, actions) {
        add(entryComp.createObject(root, {
            appName: "Prism",
            summary: summary,
            body: body ?? "",
            glyph: glyph ?? "creation",
            urgency: urgency ?? 1,
            image: image ?? "",
            actions: actions ?? []
        }));
    }

    function iconFor(e) {
        if (e.image !== "")
            return e.image;
        // Prism's own notifications use their glyph
        if (!e.notif)
            return "";
        const icon = e.appIcon;
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.startsWith("file://") || icon.startsWith("image://"))
            return icon;
        if (icon !== "") {
            const p = Quickshell.iconPath(icon, true);
            if (p !== "")
                return p;
        }
        const entry = DesktopEntries.heuristicLookup(e.appName);
        if (entry?.icon)
            return Quickshell.iconPath(entry.icon, true);
        return "";
    }

    LazyLoader {
        active: Config.notifications.server
        NotificationServer {
            id: server
            keepOnReload: true
            persistenceSupported: true
            bodySupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            bodyImagesSupported: true
            actionsSupported: true
            actionIconsSupported: true
            imageSupported: true
            inlineReplySupported: false

            onNotification: n => {
                n.tracked = true;
                root.add(entryComp.createObject(root, { notif: n }));
            }

            Component.onCompleted: {
                for (const n of trackedNotifications.values)
                    root.add(entryComp.createObject(root, { notif: n, popup: false }));
                root.unread = 0;
            }
        }
    }

    Process {
        running: true
        command: ["pgrep", "-x", "swaync"]
        onExited: code => root.foreignDaemon = code === 0
    }
}
