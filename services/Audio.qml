pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.common

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink?.ready ?? false

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var sinks: (Pipewire.nodes?.values ?? []).filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: (Pipewire.nodes?.values ?? []).filter(n => n.audio && !n.isSink && !n.isStream && !(n.name ?? "").includes(".monitor"))
    // apps playing audio: playback streams are both "stream" and "sink" to Quickshell
    // (media.class isn't available until a node is tracked, so don't filter on it)
    readonly property var streams: (Pipewire.nodes?.values ?? []).filter(n => n.audio && n.isStream && n.isSink)

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks ?? []).concat(root.sources ?? []).concat(root.streams ?? []).filter(o => !!o)
    }

    readonly property string icon: muted ? "volume_off" : volume > 0.66 ? "volume_high" : volume > 0.33 ? "volume_medium" : volume > 0 ? "volume_low" : "volume_mute"
    readonly property string micIcon: micMuted ? "microphone_off" : "microphone"

    function setVolume(v) {
        if (!sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Utils.clamp(v, 0, 1.5);
    }
    function nudge(d) {
        setVolume(Math.round((volume + d) * 100) / 100);
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function setMic(v) {
        if (!source?.audio)
            return;
        source.audio.muted = false;
        source.audio.volume = Utils.clamp(v, 0, 1.5);
    }
    function toggleMic() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
    function nodeName(n) {
        return n?.description || n?.nickname || n?.name || "Unknown";
    }
    function streamName(n) {
        const p = n?.properties ?? {};
        return p["application.name"] || n?.nickname || n?.name || n?.description || "App";
    }
    function streamIcon(n) {
        const p = n?.properties ?? {};
        return p["application.icon-name"] || p["application.process.binary"] || "audio-x-generic";
    }

    // OSD on any volume change, whoever made it
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() {
            Osd.show("volume", root.icon, "Volume", root.volume);
        }
        function onMutedChanged() {
            Osd.show("volume", root.icon, root.muted ? "Muted" : "Volume", root.muted ? 0 : root.volume);
        }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() {
            Osd.show("mic", root.micIcon, root.micMuted ? "Microphone muted" : "Microphone on", -1);
        }
    }
}
