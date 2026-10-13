pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Material You palette read live from the Lua module matugen already writes for
// Hyprland. Every colour cross-fades when the wallpaper (and so the palette) changes.
Singleton {
    id: root

    // palette cross-fade: colours blend from `palFrom` to `palTo` as `blend` goes 0 -> 1
    property var palFrom: ({})
    property var palTo: ({})
    property real blend: 1
    property string wallpaper: ""
    readonly property string wallpaperUrl: wallpaper !== "" ? "file://" + wallpaper : Config.loaded ? "file://" + Config.wallpaper.copyTo : ""

    function rgb(hex) {
        const v = parseInt(String(hex).replace("#", "").slice(0, 6), 16);
        return { r: ((v >> 16) & 255) / 255, g: ((v >> 8) & 255) / 255, b: (v & 255) / 255 };
    }

    function col(name, fallback) {
        const b = palTo[name] ?? rgb(fallback);
        if (blend >= 1)
            return Qt.rgba(b.r, b.g, b.b, 1);
        const a = palFrom[name] ?? b;
        const t = blend;
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    NumberAnimation {
        id: fade
        target: root
        property: "blend"
        from: 0
        to: 1
        duration: root.fadeMs
        easing.type: Easing.InOutCubic
    }

    readonly property int fadeMs: 1400

    property color background: col("background", "#0e1513")
    property color surface: col("surface", "#0e1513")
    property color surfaceDim: col("surface_dim", "#0e1513")
    property color surfaceBright: col("surface_bright", "#343a39")
    property color surfaceLowest: col("surface_container_lowest", "#090f0e")
    property color surfaceLow: col("surface_container_low", "#161d1c")
    property color surfaceContainer: col("surface_container", "#1a2120")
    property color surfaceHigh: col("surface_container_high", "#252b2a")
    property color surfaceHighest: col("surface_container_highest", "#303635")
    property color surfaceVariant: col("surface_variant", "#3f4947")
    property color fg: col("on_surface", "#dde4e1")
    property color fgDim: col("on_surface_variant", "#bec9c6")
    property color outline: col("outline", "#899390")
    property color outlineVariant: col("outline_variant", "#3f4947")
    property color primary: col("primary", "#82d5ca")
    property color fgPrimary: col("on_primary", "#003732")
    property color primaryContainer: col("primary_container", "#005049")
    property color fgPrimaryContainer: col("on_primary_container", "#9ef2e6")
    property color primaryFixed: col("primary_fixed", "#9ef2e6")
    property color primaryFixedDim: col("primary_fixed_dim", "#82d5ca")
    property color secondary: col("secondary", "#b1ccc7")
    property color fgSecondary: col("on_secondary", "#1c3531")
    property color secondaryContainer: col("secondary_container", "#324b48")
    property color fgSecondaryContainer: col("on_secondary_container", "#cce8e3")
    property color tertiary: col("tertiary", "#aecae6")
    property color fgTertiary: col("on_tertiary", "#163349")
    property color tertiaryContainer: col("tertiary_container", "#2e4961")
    property color fgTertiaryContainer: col("on_tertiary_container", "#cde5ff")
    property color error: col("error", "#ffb4ab")
    property color fgError: col("on_error", "#690005")
    property color errorContainer: col("error_container", "#93000a")
    property color fgErrorContainer: col("on_error_container", "#ffdad6")
    property color inversePrimary: col("inverse_primary", "#006a61")
    property color inverseSurface: col("inverse_surface", "#dde4e1")
    property color shadow: col("shadow", "#000000")
    property color sourceColor: col("source_color", "#47706a")


    // ---- accents ------------------------------------------------------------
    // light scheme? (matugen -m light) — accents get darker so they stay readable
    readonly property bool isLight: (0.2126 * surface.r + 0.7152 * surface.g + 0.0722 * surface.b) > 0.5
    // ---- wallpaper palette --------------------------------------------------
    // The 8 dominant colours of the actual wallpaper image, made vivid enough to
    // read on the shell's surfaces. Everything "accent" and every gradient is
    // built from these plus matugen's primary/secondary/tertiary — no rainbow.
    ColorQuantizer {
        id: quant
        source: root.wallpaperUrl
        depth: 3
        rescaleSize: 96
    }

    function vivid(c) {
        const h = c.hslHue < 0 ? primary.hslHue : c.hslHue;
        const sat = Math.min(1, Math.max(c.hslSaturation * 1.35, 0.5));
        return Qt.hsla(h, sat, isLight ? 0.42 : 0.7, 1);
    }

    // quantized colours, most colourful first (greys dropped when possible)
    readonly property var wallColors: {
        const cs = Array.from(quant.colors ?? []);
        const scored = cs.map(c => ({ c, s: c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.4) }));
        const colourful = scored.filter(x => x.c.hslSaturation > 0.18);
        return (colourful.length >= 2 ? colourful : scored).sort((a, b) => b.s - a.s).map(x => vivid(x.c));
    }

    // gradient stops used across the shell
    readonly property color grad1: wallColors[0] ?? primary
    readonly property color grad2: wallColors[1] ?? tertiary
    readonly property color grad3: wallColors[2] ?? secondary

    readonly property int spectrumSize: 10
    readonly property var spectrum: {
        const base = [primary, grad1, tertiary, grad2, secondary, grad3];
        for (const c of wallColors.slice(3))
            base.push(c);
        base.push(primaryFixedDim);
        const out = [];
        for (let i = 0; i < spectrumSize; i++)
            out.push(base[i % base.length]);
        return out;
    }
    readonly property var spectrumDeep: {
        const out = [];
        for (let i = 0; i < spectrumSize; i++) {
            const c = spectrum[i];
            out.push(Qt.hsla(c.hslHue < 0 ? 0 : c.hslHue, Math.min(1, c.hslSaturation * 0.8), isLight ? 0.8 : 0.32, 1));
        }
        return out;
    }

    // a surface colour tinted toward a wallpaper colour (for gradients)
    function tint(base, c, amount) {
        return mix(base, c, amount);
    }

    function accent(i) {
        const n = spectrum.length;
        return spectrum[((i % n) + n) % n];
    }
    function accentDeep(i) {
        const n = spectrumDeep.length;
        return spectrumDeep[((i % n) + n) % n];
    }
    // stable accent for a string (app names etc.)
    function accentFor(str) {
        let h = 0;
        const s = String(str ?? "");
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) | 0;
        return accent(Math.abs(h));
    }
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    // readable text colour for a background
    function on(c) {
        const l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return l > 0.55 ? "#101418" : "#f4f7f6";
    }

    // ---- type & shape --------------------------------------------------------
    readonly property string font: "Adwaita Sans"
    readonly property string mono: "Adwaita Mono"
    readonly property string display: "Roboto"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property string pixel: "Monocraft"

    readonly property QtObject r: QtObject {
        readonly property int xs: 6
        readonly property int sm: 10
        readonly property int md: 14
        readonly property int lg: 20
        readonly property int xl: 28
        readonly property int full: 9999
    }

    readonly property color glass: alpha(surface, Config.bar.opacity)
    readonly property color glassHigh: alpha(surfaceContainer, 0.92)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.5)

    // ---- matugen reader ------------------------------------------------------
    FileView {
        id: colorFile
        // wait for config.json so the default path is never read by mistake
        path: Config.loaded ? Config.paths.matugenColors : ""
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onLoaded: root.parse(text())
    }

    // matugen writes the file in several steps; wait for it to settle.
    Timer {
        id: reloadTimer
        interval: 250
        onTriggered: colorFile.reload()
    }

    function parse(text) {
        const out = {};
        const re = /M\.(\w+)\s*=\s*"rgba\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})\)"/g;
        let m;
        while ((m = re.exec(text)) !== null)
            out[m[1]] = rgb(m[2]);
        if (Object.keys(out).length < 20)
            return;
        const img = text.match(/M\.image\s*=\s*"([^"]*)"/);
        if (img)
            wallpaper = img[1];
        const first = Object.keys(palTo).length === 0;
        palFrom = palTo;
        palTo = out;
        if (first) {
            blend = 1;
        } else {
            fade.restart();
        }
    }
}
