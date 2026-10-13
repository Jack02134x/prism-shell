pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.common

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var last: null
    property var pinned: null

    readonly property var active: {
        const ps = players;
        if (pinned && ps.includes(pinned))
            return pinned;
        const playing = ps.find(p => p.isPlaying);
        if (playing)
            return playing;
        if (last && ps.includes(last))
            return last;
        return ps.length > 0 ? ps[0] : null;
    }
    onActiveChanged: if (active?.isPlaying) last = active

    readonly property bool hasPlayer: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: cleanTitle(active?.trackTitle ?? "")
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string art: active?.trackArtUrl ?? ""
    readonly property real length: active?.length ?? 0
    readonly property real position: active?.position ?? 0
    readonly property real progress: length > 0 ? Utils.clamp(position / length, 0, 1) : 0
    readonly property string identity: active?.identity ?? ""

    readonly property string sourceIcon: {
        const id = (identity + " " + (active?.desktopEntry ?? "")).toLowerCase();
        if (id.includes("spotify"))
            return "spotify";
        if (id.includes("firefox"))
            return "firefox";
        if (id.includes("chrom"))
            return "google_chrome";
        if (id.includes("mpv"))
            return "play_circle";
        if (id.includes("vlc"))
            return "vlc";
        return "music_note";
    }

    function cleanTitle(t) {
        return String(t).replace(/\s*[\(\[](official|lyric|audio|music|video|hd|4k)[^\)\]]*[\)\]]/gi, "").trim();
    }

    function toggle() {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }
    function next() {
        if (active?.canGoNext)
            active.next();
    }
    function previous() {
        if (active?.canGoPrevious)
            active.previous();
    }
    function seek(frac) {
        if (active?.canSeek && length > 0)
            active.position = frac * length;
    }
    function cycle() {
        if (players.length < 2)
            return;
        const i = players.indexOf(active);
        pinned = players[(i + 1) % players.length];
    }

    // Mpris position isn't pushed; poll it while playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: root.active?.positionChanged()
    }
}
