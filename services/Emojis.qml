pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    property var all: []   // [{ ch, name, cat }]
    property var recent: []

    function search(q) {
        q = String(q ?? "").trim().toLowerCase();
        if (q === "")
            return recent.map(c => all.find(e => e.ch === c)).filter(e => e).concat(all.filter(e => !recent.includes(e.ch))).slice(0, 400);
        const words = q.split(/\s+/);
        return all.filter(e => words.every(w => e.name.includes(w) || e.cat.toLowerCase().includes(w))).slice(0, 400);
    }

    function pick(e) {
        Quickshell.execDetached(["wl-copy", e.ch]);
        const r = [e.ch].concat(recent.filter(c => c !== e.ch)).slice(0, 24);
        recent = r;
        store.setText(JSON.stringify(r));
    }

    FileView {
        path: Config.shellDir + "/scripts/emoji.tsv"
        onLoaded: root.all = text().split("\n").filter(l => l.length > 0).map(l => {
            const p = l.split("\t");
            return { ch: p[0], name: p[1], cat: p[2] };
        })
    }

    FileView {
        id: store
        path: Config.stateDir + "/emoji-recent.json"
        onLoaded: {
            try {
                root.recent = JSON.parse(text());
            } catch (e) {}
        }
    }
}
