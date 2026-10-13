# Prism action commands

Every Prism panel and action can be triggered from a terminal, a script or a Hyprland keybind.
`install.sh` already binds the common ones (see `hypr/prism-binds.lua`). To add or change binds, put
lines like this in your Hyprland config:

```lua
hl.bind("SUPER + N", hl.dsp.exec_cmd("qs ipc call sidebar toggle"))
```

If a key already runs something else (an old launcher or notification daemon), replace that line
rather than adding a second bind for the same key, or both commands will run.

## Panels

| What | Command |
|---|---|
| Launcher | `qs ipc call launcher toggle` |
| Notification center (right drawer) | `qs ipc call sidebar toggle` |
| Controls (left drawer) | `qs ipc call controls toggle` |
| Dashboard | `qs ipc call dashboard toggle` |
| Clipboard | `qs ipc call clipboard toggle` |
| Emoji | `qs ipc call emoji toggle` |
| Workspace overview | `qs ipc call overview toggle` |
| Wallpaper picker | `qs ipc call wallpaper toggle` |
| Random wallpaper | `qs ipc call wallpaper random` |
| Power menu | `qs ipc call power toggle` |
| Screenshot menu | `qs ipc call screenshot menu` |
| Screen recording menu | `qs ipc call record menu` |
| Quick edit (open favourite folders in your editor) | `qs ipc call edit toggle` |
| Keybind cheatsheet | `qs ipc call cheatsheet toggle` |
| Window switcher (live previews, alt-tab style) | `qs ipc call switcher toggle` |

## Direct actions

| What | Command |
|---|---|
| Screenshot region | `qs ipc call screenshot region` |
| Screenshot window | `qs ipc call screenshot window` |
| Screenshot screen | `qs ipc call screenshot full` |
| Start/stop screen recording | `qs ipc call record toggle` |
| Record region / window / screen | `qs ipc call record region`, `window` or `full` |
| Stop recording | `qs ipc call record stop` |
| Volume up | `qs ipc call osd volumeUp` |
| Volume down | `qs ipc call osd volumeDown` |
| Mute | `qs ipc call osd mute` |
| Mic mute | `qs ipc call osd micMute` |
| Brightness up | `qs ipc call osd brightnessUp` |
| Brightness down | `qs ipc call osd brightnessDown` |
| Play / pause | `qs ipc call media playPause` |
| Next track | `qs ipc call media next` |
| Previous track | `qs ipc call media previous` |
| Focus timer start/stop (Pomodoro) | `qs ipc call focus toggle` |
| Focus pause/resume | `qs ipc call focus pause` |
| Skip to next focus/break phase | `qs ipc call focus skip` |
| Light / dark theme toggle | `qs ipc call theme toggle` (or `theme light` / `theme dark`) |
| Do not disturb | `qs ipc call toggle dnd` |
| Caffeine (stay awake) | `qs ipc call toggle caffeine` |
| Study noise | `qs ipc call toggle noise` |
| EasyEffects on / off (off = killed) | `qs ipc call toggle easyeffects` |
| Game mode | `qs ipc call toggle gamemode` |
| Power profile | `qs ipc call toggle profile` |
| Clear notifications | `qs ipc call notify clear` |
| Lock screen | `qs ipc call lock lock` |
| Preview the Prism lock screen (doesn't lock) | `qs ipc call lock preview` |

`lock lock` uses Prism's lock screen when "Prism lock screen" is on in Dashboard → Settings, and
hyprlock otherwise. Try Prism's with `lock preview` first.

The volume and brightness popup in the island also appears when the volume or brightness changes
some other way (for example `wpctl` or `brightnessctl` on the media keys).

## Getting notifications into Prism

Prism is the notification daemon unless another one (swaync, mako, dunst) is already running.
Remove that one from your autostart, run `pkill swaync` (or mako / dunst) once, and Prism takes
over.
