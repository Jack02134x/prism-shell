pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common

// Hyprland helpers. Hyprland here runs the Lua config, so dispatches are Lua
// expressions such as hl.dsp.focus({ workspace = 3 }).
Singleton {
    id: root

    readonly property var workspaces: Hyprland.workspaces.values
    readonly property var toplevels: Hyprland.toplevels.values
    // Only windows Hyprland itself reports (`hyprctl clients`); the merged
    // foreign-toplevel list also contains Steam/Wine helper surfaces.
    readonly property var realToplevels: toplevels.filter(t => {
        const o = t.lastIpcObject ?? {};
        return o.address !== undefined && o.mapped !== false && o.hidden !== true;
    })
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property int activeId: focusedWorkspace?.id ?? 1
    // Hyprland only learns the active window from its first focus event, so
    // fall back to the Wayland foreign-toplevel state until then.
    readonly property var activeWindow: Hyprland.activeToplevel ?? Hyprland.toplevels.values.find(t => t.activated) ?? null
    readonly property var activeWayland: ToplevelManager.activeToplevel
    readonly property string activeTitle: String(activeWindow?.title || activeWayland?.title || "")
    readonly property string activeClass: String(classOf(activeWindow) || activeWayland?.appId || "")

    function dispatch(lua) {
        Hyprland.dispatch(lua);
    }
    // several dispatches in one go
    function evalLua(lua) {
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    function quote(s) {
        return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"";
    }

    function focusWorkspace(id) {
        dispatch("hl.dsp.focus({ workspace = " + (typeof id === "number" ? id : quote(id)) + " })");
    }
    function toggleSpecial(name) {
        dispatch("hl.dsp.workspace.toggle_special(" + quote(name) + ")");
    }
    function focusWindow(address) {
        dispatch("hl.dsp.focus({ window = " + quote("address:" + address) + " })");
    }
    // Move a window by address without focusing it first, so nothing jumps
    // workspaces and no special workspace pops open.
    function moveWindow(address, ws) {
        const target = typeof ws === "number" ? ws : quote(ws);
        dispatch("hl.dsp.window.move({ workspace = " + target + ", window = " + quote("address:" + address) + ", follow = false })");
    }
    // switch workspace once overlays have released the keyboard
    function focusWorkspaceSoon(id) {
        pendingWs.target = id;
        pendingWs.restart();
    }
    function toggleSpecialSoon(name) {
        pendingWs.target = "special:" + name;
        pendingWs.restart();
    }
    Timer {
        id: pendingWs
        property var target: null
        interval: 140
        onTriggered: {
            const t = target;
            if (t !== null && typeof t === "object") {
                if (t.window !== "")
                    root.focusWindow(t.window);
                else if (t.wl)
                    t.wl.activate();
            } else if (typeof t === "string" && t.startsWith("special:"))
                root.toggleSpecial(t.slice(8));
            else if (t !== null)
                root.focusWorkspace(t);
        }
    }
    // "0x..." address of a HyprlandToplevel
    function addr(t) {
        const a = String(t?.lastIpcObject?.address ?? t?.address ?? "");
        return a === "" || a.startsWith("0x") ? a : "0x" + a;
    }
    function closeWindow(toplevel) {
        if (addr(toplevel) !== "")
            dispatch("hl.dsp.window.close({ window = " + quote("address:" + addr(toplevel)) + " })");
        else if (toplevel?.wayland)
            toplevel.wayland.close();
    }
    // focus a window (slightly delayed so a closing overlay doesn't keep focus)
    function activate(toplevel) {
        pendingWs.target = { window: addr(toplevel), wl: toplevel?.wayland ?? null };
        pendingWs.restart();
    }

    function workspace(id) {
        return workspaces.find(w => w.id === id) ?? null;
    }
    function windowsOn(id) {
        const w = workspace(id);
        return w ? w.toplevels.values : [];
    }
    function classOf(t) {
        if (!t)
            return "";
        return t.wayland?.appId || t.lastIpcObject?.class || "";
    }

    // window class -> icon url ("" when nothing matches). Re-evaluates once the
    // desktop entry scan finishes; only successful lookups are cached.
    property var iconCache: ({})
    readonly property int entryCount: DesktopEntries.applications.values.length
    readonly property var overrides: ({
            "chrome-web.whatsapp.com__-Default": "whatsapp",
            "org.pwmt.zathura": "org.pwmt.zathura"
        })
    function lookupEntry(cls) {
        return DesktopEntries.byId(cls) ?? DesktopEntries.byId(cls.toLowerCase()) ?? DesktopEntries.heuristicLookup(cls);
    }
    function iconFor(cls) {
        if (!cls || entryCount < 0)
            return "";
        if (iconCache[cls] !== undefined)
            return iconCache[cls];
        const names = [];
        if (overrides[cls])
            names.push(overrides[cls]);
        const e = lookupEntry(cls);
        if (e?.icon)
            names.push(e.icon);
        names.push(cls, cls.toLowerCase());
        for (const n of names) {
            if (n.startsWith("/"))
                return iconCache[cls] = "file://" + n;
            if (Quickshell.hasThemeIcon(n)) {
                const p = Quickshell.iconPath(n);
                if (e)
                    iconCache[cls] = p;
                return p;
            }
        }
        return "";
    }
    function appName(cls) {
        const e = cls ? lookupEntry(cls) : null;
        return e?.name ?? cls;
    }

    function refresh() {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
    }

    // ---- special workspaces ----
    // name of the special workspace open on the focused monitor ("" if none)
    property string activeSpecial: String(Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name ?? "").replace("special:", "")
    readonly property var specialNames: {
        const out = [];
        for (const n of Config.bar.specials)
            out.push(n);
        for (const w of workspaces) {
            const n = String(w.name);
            if (w.id < 0 && n.startsWith("special:") && w.toplevels.values.length > 0 && !out.includes(n.slice(8)))
                out.push(n.slice(8));
        }
        return out;
    }
    function special(name) {
        return workspaces.find(w => w.name === "special:" + name) ?? null;
    }
    function specialLabel(name) {
        return ({ minimize: "Minimized", network_social: "Social", magic: "Scratchpad" })[name] ?? Utils.capitalize(String(name).replace(/_/g, " "));
    }
    function specialIcon(name) {
        return ({ minimize: "window_minimize", network_social: "forum", magic: "creation" })[name] ?? "star_four_points";
    }
    // bring a window back from a special workspace to the current one
    function restore(t) {
        moveWindow(addr(t), activeId > 0 ? activeId : 1);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activespecial")
                return;
            const name = String(event.data).split(",")[0].replace("special:", "");
            root.activeSpecial = name;
            if (name !== "")
                Osd.show("toggle", root.specialIcon(name), root.specialLabel(name) + " · " + (root.special(name)?.toplevels.values.length ?? 0) + " windows", -1);
        }
    }

    // workspace switch flash in the island
    property int lastWs: -1
    onActiveIdChanged: {
        if (lastWs !== -1 && activeId > 0 && activeId !== lastWs)
            Osd.show("workspace", "view_grid", "Workspace " + activeId, -1);
        lastWs = activeId;
    }
}
