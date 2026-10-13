import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services
import qs.widgets

// Session lock (opt-in via config.json "lock.enabled") + a preview overlay
// that renders the same UI without locking anything.
Scope {
    WlSessionLock {
        id: lock
        locked: Session.locked

        WlSessionLockSurface {
            color: "black"
            LockContent {
                anchors.fill: parent
                onUnlocked: Session.locked = false
            }
        }
    }

    Overlay {
        name: "lock-preview"
        open: Session.preview
        scrimOpacity: 0
        closeOnScrim: false
        onDismiss: Session.preview = false

        Loader {
            anchors.fill: parent
            active: Session.preview
            sourceComponent: LockContent {
                preview: true
                onCancelled: Session.preview = false
                onUnlocked: Session.preview = false
            }
        }
    }
}
