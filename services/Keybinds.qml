pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Parses the Hyprland Lua bind files (Config.paths.binds + extraBinds, read-only)
// into a cheatsheet.
Singleton {
    id: root

    property var sections: []   // [{ name, binds: [{ keys: [..], desc }] }]

    function titleCase(s) {
        return s.toLowerCase().replace(/(^|[\s\/])(\w)/g, (m, a, b) => a + b.toUpperCase()).trim();
    }

    function keysOf(expr, vars, loop) {
        let out = "";
        for (let tok of expr.split("..")) {
            tok = tok.trim();
            const q = tok.match(/^"(.*)"$/);
            if (q)
                out += q[1];
            else if (loop && tok === loop.v)
                out += loop.a + "–" + loop.b;
            else if (vars[tok] !== undefined)
                out += vars[tok];
            else
                out += tok;
        }
        return out.split("+").map(k => k.trim()).filter(k => k !== "").map(k => k.replace("mouse:272", "LMB").replace("mouse:273", "RMB").replace("mouse_down", "Wheel ↓").replace("mouse_up", "Wheel ↑").replace(/^XF86Audio/, "Media ").replace(/^XF86MonBrightness/, "Brightness ").replace("RaiseVolume", "Vol +").replace("LowerVolume", "Vol −"));
    }

    // plain-language names for common commands / dispatchers (first match wins)
    readonly property var friendly: [
        [/qs ipc call launcher toggle/, "Prism · app launcher"],
        [/qs ipc call emoji/, "Prism · emoji picker"],
        [/qs ipc call clipboard/, "Prism · clipboard history"],
        [/qs ipc call sidebar/, "Prism · notification center"],
        [/qs ipc call controls/, "Prism · control drawer"],
        [/qs ipc call cheatsheet/, "Prism · this cheatsheet"],
        [/qs ipc call wallpaper random/, "Prism · random wallpaper"],
        [/qs ipc call wallpaper/, "Prism · wallpaper picker"],
        [/qs ipc call power/, "Prism · power menu"],
        [/qs ipc call dashboard/, "Prism · dashboard"],
        [/qs ipc call overview/, "Prism · workspace overview"],
        [/qs ipc call screenshot region/, "Prism · screenshot a region"],
        [/qs ipc call screenshot window/, "Prism · screenshot a window"],
        [/qs ipc call screenshot full/, "Prism · screenshot the screen"],
        [/qs ipc call screenshot/, "Prism · screenshot"],
        [/qs ipc call record stop/, "Prism · stop recording"],
        [/qs ipc call record/, "Prism · screen recording"],
        [/qs ipc call lock/, "Prism · lock screen"],
        [/qs ipc call edit/, "Prism · quick edit folders"],
        [/qs ipc call switcher/, "Prism · window switcher"],
        [/qs ipc call focus/, "Prism · focus timer"],
        [/qs ipc call clock/, "Prism · clock, timer, alarms"],
        [/qs ipc call theme/, "Prism · light / dark theme"],
        [/qs ipc call toggle dnd/, "Prism · do not disturb"],
        [/qs ipc call toggle caffeine/, "Prism · caffeine (stay awake)"],
        [/qs ipc call toggle gamemode/, "Prism · game mode"],
        [/qs ipc call toggle easyeffects/, "Prism · EasyEffects on / off"],
        [/qs ipc call notify clear/, "Prism · clear notifications"],
        [/qs ipc call osd volumeUp|set-sink-volume.*\+|volume\.sh up/, "Volume up"],
        [/qs ipc call osd volumeDown|set-sink-volume.*-\d|volume\.sh down/, "Volume down"],
        [/qs ipc call osd micMute|DEFAULT_AUDIO_SOURCE@ toggle/, "Mute microphone"],
        [/qs ipc call osd mute|set-sink-mute|volume\.sh mute/, "Mute"],
        [/brightness\.sh up|brightnessUp/, "Brightness up"],
        [/brightness\.sh down|brightnessDown/, "Brightness down"],
        [/playerctl next|media next/, "Next track"],
        [/playerctl previous|media previous/, "Previous track"],
        [/playerctl play-pause|playPause/, "Play / pause"],
        [/go_through\.sh/, "Walk to workspace n"],
        [/moving_all_windows\.sh/, "Move all windows to workspace n"],
        [/screenshot\.sh/, "Screenshot (wofi script)"],
        [/Colorpicker\.sh|hyprpicker/, "Colour picker"],
        [/waybar-switcher\/Menu\.sh/, "Waybar theme menu"],
        [/waybar-switcher\/current\.sh/, "Restart waybar"],
        [/wallpaperchanger/, "Wallpaper changer"],
        [/play_entire_playlist/, "Play YouTube playlist (mpv)"],
        [/pkill python; pkill mpv\s*$/, "Stop music"],
        [/pkill glava\s*$/, "Stop GLava"],
        [/glava/, "GLava visualizer"],
        [/ani-cli -d/, "Download anime (ani-cli)"],
        [/ani-cli/, "Watch anime (ani-cli)"],
        [/mouse_invert/, "Build + run mouse invert"],
        [/^thunar$/, "Thunar file manager"],
        [/yazi/, "Yazi file manager"],
        [/hyprlock/, "Lock screen (hyprlock)"],
        [/wlogout/, "Logout menu"],
        [/swaync/, "Notifications (swaync)"],
        [/cliphist/, "Clipboard (wofi)"]
    ]
    function friendlyDispatch(name, args) {
        const a = args;
        if (name === "window close")
            return a.includes("force") ? "Force-close window" : "Close window";
        if (name === "window drag")
            return "Drag window";
        if (name === "window resize")
            return "Resize window";
        if (name === "window fullscreen")
            return "Fullscreen";
        if (name === "window float")
            return "Toggle floating";
        if (name === "window center")
            return "Center window";
        if (name === "group toggle")
            return "Toggle window group";
        if (name === "group next")
            return "Next window in group";
        if (name === "layout")
            return "Toggle split direction";
        let m;
        if (name === "focus" && (m = a.match(/direction (\w+)/)))
            return "Focus " + m[1];
        if (name === "focus" && a.includes("e-1"))
            return "Previous workspace";
        if (name === "focus" && a.includes("e+1"))
            return "Next workspace";
        if (name === "focus" && (m = a.match(/workspace (\S+)/)))
            return "Go to workspace " + m[1];
        if (name === "window move" && (m = a.match(/direction (\w)/)))
            return "Move window " + ({ l: "left", r: "right", u: "up", d: "down" })[m[1]];
        if (name === "window move" && a.includes("special:minimize"))
            return "Minimize window";
        if (name === "window move" && a.includes("special:magic"))
            return "Send window to scratchpad";
        if (name === "window move" && (m = a.match(/special:(\w+)/)))
            return "Send window to " + m[1].replace("_", " ");
        if (name === "window move" && (m = a.match(/workspace (\S+)/)))
            return "Move window to workspace " + m[1];
        if (name === "window cycle next")
            return "Focus next window";
        if (name === "window pseudo")
            return "Pseudo-tile window";
        if (name === "workspace toggle special" && a.includes("magic"))
            return "Show scratchpad";
        if (name === "workspace toggle special")
            return a.includes("minimize") ? "Show minimized windows" : "Show " + a.replace(/_/g, " ") + " workspace";
        return "";
    }

    function describe(action, vars, loop) {
        // match against the command itself, not the surrounding hl.dsp.exec_cmd(...)
        const lit = action.match(/exec_cmd\("((?:[^"\\]|\\.)*)"\)/);
        const ref = action.match(/exec_cmd\((\w+)\)/);
        const cmd = lit ? lit[1] : (ref && vars[ref[1]] !== undefined ? vars[ref[1]] : action);
        for (const [re, label] of friendly)
            if (re.test(cmd))
                return label;
        let m;
        if ((m = action.match(/exec_cmd\((\w+)\)/)) && vars[m[1]] !== undefined)
            return "Run " + vars[m[1]];
        if ((m = action.match(/exec_cmd\("((?:[^"\\]|\\.)*)"/))) {
            let c = m[1].replace(/\\"/g, "\"");
            const ipc = c.match(/qs ipc call (\w+) (\w+)/);
            if (ipc)
                return "Prism · " + ipc[1] + " " + ipc[2];
            c = c.replace(/pkill \w+;\s*/g, "").replace(/^~\//, "");
            return c.length > 60 ? c.slice(0, 57) + "…" : c;
        }
        if (action.includes("function"))
            return action.includes("cycle_next") ? "Cycle windows" : "Lua function";
        if ((m = action.match(/hl\.dsp\.([\w.]+)\(/))) {
            // take the dispatcher's own (balanced) argument list only
            let depth = 1, i = m.index + m[0].length, args = "";
            for (; i < action.length && depth > 0; i++) {
                const ch = action[i];
                if (ch === "(")
                    depth++;
                else if (ch === ")")
                    depth--;
                if (depth > 0)
                    args += ch;
            }
            const name = m[1].replace(/\./g, " ").replace(/_/g, " ");
            args = args.replace(/[{}]/g, "").replace(/\s*=\s*/g, " ").replace(/"/g, "").replace(/,/g, " ").replace(/\s+/g, " ").trim();
            if (loop)
                args = args.replace(new RegExp("\\b" + loop.v + "\\b", "g"), "n");
            return friendlyDispatch(name, args) || Utils.capitalize((name + " " + args).trim());
        }
        return action.slice(0, 50);
    }

    function parse(text) {
        const vars = { mainMod: "SUPER" };
        const out = [];
        let cur = { name: "General", binds: [] };
        let loop = null;
        let inFunc = false;
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            let m;
            if ((m = line.match(/^local\s+(\w+)\s*=\s*"([^"]*)"/))) {
                vars[m[1]] = m[2];
                continue;
            }
            if ((m = line.match(/^-{2,}\s*([A-Za-z][A-Za-z0-9 \/&\-]*?)\s*-{2,}\s*$/)) || (m = line.match(/^--\s+([A-Z][A-Za-z \/&]+)$/))) {
                if (cur.binds.length > 0)
                    out.push(cur);
                cur = { name: titleCase(m[1]), binds: [] };
                continue;
            }
            if (line.startsWith("--") || line === "")
                continue;
            if ((m = line.match(/^for\s+(\w+)\s*=\s*(\d+)\s*,\s*(\d+)\s+do/))) {
                loop = { v: m[1], a: m[2], b: m[3] };
                continue;
            }
            if (inFunc) {
                if (line.startsWith("end)"))
                    inFunc = false;
                continue;
            }
            if (line === "end") {
                loop = null;
                continue;
            }
            // hl.bind(...) or a local bind(...) helper; osd("ipc", fallback) is Prism's media-key helper
            if (!/^(hl\.)?bind\(/.test(line))
                continue;
            const bm = line.match(/^(?:hl\.)?bind\((.+?),\s*(hl\.dsp\..*|function.*|osd\(.*)$/);
            if (!bm)
                continue;
            if (bm[2].startsWith("function") && !bm[2].includes("end)"))
                inFunc = true;
            if (/exec_cmd\(""\)/.test(bm[2]))
                continue;
            const om = bm[2].match(/^osd\("([^"]+)"/);
            if (om)
                bm[2] = 'hl.dsp.exec_cmd("qs ipc call ' + om[1] + '")';
            const action = bm[2].startsWith("function") ? "function " + (text.slice(text.indexOf(raw)).split("end)")[0]) : bm[2];
            cur.binds.push({ keys: keysOf(bm[1], vars, loop), desc: describe(action, vars, loop) });
        }
        if (cur.binds.length > 0)
            out.push(cur);
        sections = out;
        boundIpc = (text.match(/qs ipc call \w+ \w+/g) ?? []).map(x => x.replace("qs ipc call ", ""));
    }

    FileView {
        id: mainBinds
        path: Config.loaded ? Config.paths.binds : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.reparse()
    }
    FileView {
        id: extraBinds
        path: Config.loaded ? Config.paths.extraBinds : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.reparse()
    }
    function reparse() {
        parse((mainBinds.loaded ? mainBinds.text() : "") + "\n" + (extraBinds.loaded && Config.paths.extraBinds !== "" ? extraBinds.text() : ""));
    }

    property var boundIpc: []
    // Prism actions you haven't bound to a key yet
    readonly property var unbound: prism.filter(p => !boundIpc.includes(p.ipc))
    readonly property var prism: [
        { ipc: "launcher toggle", desc: "App launcher" },
        { ipc: "dashboard toggle", desc: "Dashboard" },
        { ipc: "sidebar toggle", desc: "Notification center" },
        { ipc: "controls toggle", desc: "Control drawer" },
        { ipc: "overview toggle", desc: "Workspace overview (specials on the right)" },
        { ipc: "wallpaper toggle", desc: "Wallpaper picker" },
        { ipc: "wallpaper random", desc: "Random wallpaper" },
        { ipc: "power toggle", desc: "Power menu" },
        { ipc: "screenshot menu", desc: "Screenshot (drag a region, click a window)" },
        { ipc: "screenshot region", desc: "Screenshot a region" },
        { ipc: "record menu", desc: "Screen recording menu" },
        { ipc: "clipboard toggle", desc: "Clipboard history" },
        { ipc: "emoji toggle", desc: "Emoji picker" },
        { ipc: "edit toggle", desc: "Quick edit folders in your editor" },
        { ipc: "switcher toggle", desc: "Window switcher (live previews)" },
        { ipc: "focus toggle", desc: "Focus timer (Pomodoro)" },
        { ipc: "clock toggle", desc: "Floating clock (timer, stopwatch, alarms)" },
        { ipc: "theme toggle", desc: "Light / dark theme" },
        { ipc: "lock lock", desc: "Lock screen" },
        { ipc: "toggle caffeine", desc: "Caffeine (stay awake)" },
        { ipc: "toggle dnd", desc: "Do not disturb" },
        { ipc: "cheatsheet toggle", desc: "This cheatsheet" }
    ]
}
