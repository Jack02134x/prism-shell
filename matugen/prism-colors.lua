-- Prism colour palette — written by matugen, read live by Quickshell (common/Theme.qml).
-- Template: ~/.config/quickshell/matugen/prism-colors.lua
-- Do not edit the generated copy; pick a new wallpaper instead.

local M = {}

M.image = "{{image}}"

<* for name, value in colors *>
M.{{name}} = "rgba({{value.default.hex_stripped}}ff)"
<* endfor *>

return M
