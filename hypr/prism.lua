-- Prism autostart for Hyprland (Lua config, 0.55+).
-- install.sh loads this from the end of ~/.config/hypr/hyprland.lua with
--   dofile("<home>/.config/quickshell/hypr/prism.lua")
-- Each daemon is only started if it isn't already running, so it's safe next to
-- your own autostart.

local shell = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/quickshell"

hl.on("hyprland.start", function()
    -- wallpaper daemon; show the last wallpaper (Prism keeps a copy in .state/)
    hl.exec_cmd("pidof awww-daemon >/dev/null || awww-daemon")
    hl.exec_cmd("sleep 1; awww restore 2>/dev/null || awww img '" .. shell .. "/.state/wallpaper' --transition-type fade")
    hl.exec_cmd("pidof quickshell >/dev/null || quickshell")
    hl.exec_cmd("pgrep -f 'wl-paste --type text --watch' >/dev/null || wl-paste --type text --watch cliphist store")
    hl.exec_cmd("pgrep -f 'wl-paste --type image --watch' >/dev/null || wl-paste --type image --watch cliphist store")
    hl.exec_cmd("pidof hypridle >/dev/null || hypridle")
end)
