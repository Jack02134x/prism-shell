pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Static wallpapers (awww + matugen, exactly like the old launcher did) and
// live video wallpapers (mpvpaper). Thumbnails are cached in .cache/thumbs.
Singleton {
    id: root

    property var images: []
    property var videos: []
    property bool loaded: false
    property bool thumbing: false

    readonly property string thumbDir: Config.cacheDir + "/thumbs"
    readonly property string videoThumbDir: Config.cacheDir + "/vthumbs"
    readonly property string current: Theme.wallpaper

    function thumb(path) {
        return "file://" + thumbDir + "/" + Utils.fileName(path) + ".jpg";
    }
    function videoThumb(path) {
        return "file://" + videoThumbDir + "/" + Utils.fileName(path) + ".jpg";
    }
    function isVideo(path) {
        return /\.(mp4|webm|mkv|mov)$/i.test(path);
    }

    function load() {
        if (!listProc.running)
            listProc.running = true;
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \\) | sort; echo '::VIDEOS::'; find \"$2\" -maxdepth 1 -type f \\( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.gif' \\) | sort", "ls", Config.wallpaper.dir, Config.wallpaper.videoDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const [a, b] = text.split("::VIDEOS::");
                root.images = (a ?? "").split("\n").filter(p => p.length > 0);
                root.videos = (b ?? "").split("\n").filter(p => p.length > 0);
                root.loaded = true;
                root.makeThumbs();
            }
        }
    }

    // background thumbnailer (idle priority, skips existing thumbs)
    Process {
        id: thumbProc
        command: ["bash", Config.shellDir + "/scripts/thumbs.sh", Config.wallpaper.dir, root.thumbDir, Config.wallpaper.videoDir, root.videoThumbDir]
        onRunningChanged: root.thumbing = running
        onExited: root.thumbsVersion++
    }
    property int thumbsVersion: 0
    function makeThumbs() {
        if (!thumbProc.running)
            thumbProc.running = true;
    }

    function apply(path, x, y) {
        if (isVideo(path))
            return applyVideo(path);
        const pos = x !== undefined ? ["--transition-type", "grow", "--transition-pos", Math.round(x) + "," + Math.round(y), "--invert-y"] : ["--transition-type", Config.wallpaper.transition];
        Utils.sh("pkill -x mpvpaper; awww img \"$1\" " + pos.map(p => "'" + p + "'").join(" ") + " --transition-fps 144; matugen image \"$1\" -m \"$6\" " + schemeArg + "--source-color-index \"$5\"; [ -n \"$3\" ] && echo \"$2\" > \"$3\"; [ -n \"$4\" ] && mkdir -p \"$(dirname \"$4\")\" && cp -- \"$1\" \"$4\"", path, Utils.stem(path), Config.wallpaper.nameFile, Config.wallpaper.copyTo, Config.wallpaper.matugenIndex, Config.wallpaper.mode);
    }

    function applyVideo(path) {
        if (/\.gif$/i.test(path))
            return Utils.sh("pkill -x mpvpaper; awww img \"$1\" --transition-type random; f=\"$2/live-frame.png\"; magick \"$1[0]\" \"$f\" && matugen image \"$f\" -m \"$4\" " + schemeArg + "--source-color-index \"$3\"", path, Config.cacheDir, Config.wallpaper.matugenIndex, Config.wallpaper.mode);
        Utils.sh("pkill -x mpvpaper; (setsid -f \"$5\" \"$1\" \"$6\" >/dev/null 2>&1); f=\"$2/live-frame.png\"; ffmpegthumbnailer -i \"$1\" -o \"$f\" -s 0 -t 15% && matugen image \"$f\" -m \"$4\" " + schemeArg + "--source-color-index \"$3\"", path, Config.cacheDir, Config.wallpaper.matugenIndex, Config.wallpaper.mode, Config.shellDir + "/scripts/live-wallpaper.py", Config.wallpaper.liveGpu);
        Notifs.local("Live wallpaper", Utils.stem(path), "filmstrip");
    }

    // extra matugen flag for a punchier scheme (Settings → Colour scheme)
    readonly property string schemeArg: Config.wallpaper.scheme !== "" ? "-t " + Config.wallpaper.scheme + " " : ""

    // ---- dark / light ----
    readonly property bool light: Config.wallpaper.mode === "light"
    function setMode(mode) {
        Config.wallpaper.mode = mode;
        // re-run matugen on the current wallpaper (or the live-wallpaper frame)
        const src = Theme.wallpaper !== "" ? Theme.wallpaper : Config.wallpaper.copyTo;
        Utils.sh("matugen image \"$1\" -m \"$2\" " + schemeArg + "--source-color-index \"$3\"", src, mode, Config.wallpaper.matugenIndex);
        Osd.show("toggle", mode === "light" ? "weather_sunny" : "weather_night", mode === "light" ? "Light theme" : "Dark theme", -1);
    }
    function toggleMode() {
        setMode(light ? "dark" : "light");
    }

    function stopLive() {
        Quickshell.execDetached(["pkill", "-x", "mpvpaper"]);
    }

    function random() {
        if (!loaded) {
            load();
            randomTimer.start();
            return;
        }
        if (images.length > 0)
            apply(images[Math.floor(Math.random() * images.length)]);
    }
    Timer {
        id: randomTimer
        interval: 600
        onTriggered: if (root.images.length > 0) root.random()
    }
}
