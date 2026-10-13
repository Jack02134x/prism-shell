-- ~/.config/hypr/hyprland.lua — Prism starter config (Hyprland 0.55+, Lua)
-- Installed by ~/.config/quickshell/install.sh. It's yours now: edit anything.
-- Wiki: https://wiki.hypr.land/Configuring/Start/
--
-- Prism's own keybinds (launcher, dashboard, screenshots, …) and autostart live in
-- ~/.config/quickshell/hypr/prism-binds.lua and prism.lua, loaded at the end of this file.
-- Press SUPER + / for a cheatsheet of every bind.

------------------
---- PROGRAMS ----
------------------

local mainMod  = "SUPER"
local terminal = "kitty"
local files    = "thunar"
local browser  = "firefox"

--------------------
---- COLOURS -------
--------------------

-- Matugen writes Prism's palette here whenever the wallpaper changes (and runs
-- `hyprctl reload`), so window borders follow the wallpaper too.
local palette = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/quickshell/.state/colors.lua"
local ok, c = pcall(dofile, palette)
if not ok or type(c) ~= "table" then
    c = {
        primary = "rgba(82d5caff)", tertiary = "rgba(aecae6ff)", outline = "rgba(899390ff)",
        surface = "rgba(0e1513ff)", shadow = "rgba(000000ff)",
    }
end

------------------
---- MONITORS ----
------------------

-- Every monitor at its preferred resolution. For a specific layout, see
-- https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

---------------------
---- ENVIRONMENT ----
---------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "__KB_LAYOUT__",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = false,
            tap_to_click         = true,
            disable_while_typing = true,
        },
    },
})

---------------------
---- LOOK & FEEL ----
---------------------

hl.config({
    general = {
        gaps_in          = 6,
        gaps_out         = 12,
        border_size      = 2,
        resize_on_border = true,
        layout           = "dwindle",

        col = {
            active_border   = { colors = { c.primary, c.tertiary }, angle = 45 },
            inactive_border = { colors = { c.surface, c.outline }, angle = 45 },
        },
    },

    decoration = {
        rounding         = 14,
        active_opacity   = 1.0,
        inactive_opacity = 0.92,

        blur = {
            enabled  = true,
            size     = 6,
            passes   = 3,
            vibrancy = 0.2,
        },

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = c.shadow,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        focus_on_activate        = true,
        -- any key or mouse movement wakes screens that were switched off
        key_press_enables_dpms   = true,
        mouse_move_enables_dpms  = true,
    },

    binds = {
        allow_workspace_cycles = true,
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

-- Curves and animations (Material 3 easing, a little overshoot on workspaces)
hl.curve("md3_standard", { type = "bezier", points = { {0.2, 0},    {0, 1}   } })
hl.curve("md3_decel",    { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("overshot",     { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.1} } })

hl.animation({ leaf = "windows",          enabled = true, speed = 3,   bezier = "md3_standard", style = "popin 60%" })
hl.animation({ leaf = "border",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "fade",             enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3.5, bezier = "overshot",  style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3,   bezier = "md3_decel", style = "slidevert" })

------------------
---- GESTURES ----
------------------

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

----------------------
---- WINDOW RULES ----
----------------------

hl.window_rule({
    name  = "float-dialogs",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk|hyprland-share-picker)$" },
    float = true,
})

hl.window_rule({
    name    = "picture-in-picture",
    match   = { title = "^(Picture-in-Picture)$" },
    float   = true,
    pin     = true,
    opacity = "1.0 override",
})

------------------
---- KEYBINDS ----
------------------

---- APPS ----
hl.bind(mainMod .. " + Q",      hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(files))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))

---- WINDOWS ----
hl.bind(mainMod .. " + D",         hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.window.close({ force = true }))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ state = 2 }))
hl.bind(mainMod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.center())
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + G",         hl.dsp.group.toggle())
hl.bind(mainMod .. " + TAB",       hl.dsp.window.cycle_next())

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

---- WORKSPACES ----
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + 0",         hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))

-- scratchpad (shows up in Prism's bar as "Scratchpad")
hl.bind(mainMod .. " + Z",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:magic" }))

-- Prism adds its binds and autostart below (install.sh manages that block).
