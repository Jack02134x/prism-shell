#!/usr/bin/env bash
# Prism — one-shot installer: bare Arch  ->  Hyprland + the Prism Quickshell desktop.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/CHANGE_ME/prism/main/install.sh)
#   # or
#   git clone https://github.com/CHANGE_ME/prism ~/.config/quickshell && ~/.config/quickshell/install.sh
#
# Made for a fresh Arch install with no desktop yet, but safe on an existing setup
# (anything it changes is backed up, and every edit to your files sits between
# ">>> prism >>>" markers so --uninstall can take it out again).
#
# Steps (it asks before each one unless you pass --yes):
#    1. checks: Arch, not root, internet
#    2. packages: Hyprland, Quickshell, matugen, PipeWire, NetworkManager, kitty, Thunar,
#       fonts, icons … in one pacman transaction; installs yay if you have no AUR helper
#    3. Prism itself -> ~/.config/quickshell (an existing config is backed up)
#    4. config.json with your terminal / editor / browser / name
#    5. matugen: wallpaper colours for Prism, Hyprland borders, kitty and GTK apps
#    6. Hyprland: a full starter config if you don't have one yet; Prism's
#       autostart + keybinds either way (idle — dim, lock, screens off — is
#       built into Prism, so no hypridle)
#    7. kitty + GTK look, Hyprland on login (tty1), 10 wallpapers, first palette
#    8. screen time: the hyprland-screen_time tracker (systemd user service) that
#       feeds the dashboard's Screen time tab, plus its GUI in the app launcher
#
# install.sh --help for options. install.sh --uninstall reverses steps 3–8.

set -uo pipefail

PRISM_REPO="${PRISM_REPO:-https://github.com/CHANGE_ME/prism.git}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$CONFIG_HOME/quickshell"
HYPR_DIR="$CONFIG_HOME/hypr"
HYPR_LUA="$HYPR_DIR/hyprland.lua"
MATUGEN_CONF="$CONFIG_HOME/matugen/config.toml"
KITTY_CONF="$CONFIG_HOME/kitty/kitty.conf"
FISH_LOGIN="$CONFIG_HOME/fish/conf.d/prism-hyprland.fish"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SCREENTIME_REPO="https://github.com/Jack02134x/hyprland-screen_time.git"
SCREENTIME_DIR="$DATA_HOME/hyprland-screen_time"
ST_SERVICE="$CONFIG_HOME/systemd/user/hypr-screentime.service"
ST_DESKTOP="$DATA_HOME/applications/hypr-screentime.desktop"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/prism-install.log"
STAMP="$(date +%Y%m%d-%H%M%S)"

# block markers (one style per comment syntax)
LUA_B="-- >>> prism >>>" LUA_E="-- <<< prism <<<"
SH_B="# >>> prism >>>" SH_E="# <<< prism <<<"
CSS_B="/* >>> prism >>> */" CSS_E="/* <<< prism <<< */"

YES=0 DRY=0 DO_PACKAGES=1 DO_HYPR=1 DO_BINDS=1 DO_START=1 DO_LOGIN=1 DO_APPS=1 DO_ST=1 UNINSTALL=0

# ---------------------------------------------------------------- output ----
if [[ -t 1 ]]; then
    B=$'\e[1m' D=$'\e[2m' R=$'\e[0m' RED=$'\e[31m' GRN=$'\e[32m' YEL=$'\e[33m' MAG=$'\e[35m' CYN=$'\e[36m'
else
    B="" D="" R="" RED="" GRN="" YEL="" MAG="" CYN=""
fi
mkdir -p "$(dirname "$LOG")" 2>/dev/null
exec 3>&1 # dry-run output goes here so redirects can't swallow it
log() { printf '[%s] %s\n' "$(date +%T)" "$*" >>"$LOG" 2>/dev/null; }
step() { printf '\n%s%s◆ %s%s\n' "$B" "$MAG" "$*" "$R"; log "== $*"; }
info() { printf '  %s\n' "$*"; log "$*"; }
ok() { printf '  %s✓%s %s\n' "$GRN" "$R" "$*"; log "ok: $*"; }
warn() { printf '  %s!%s %s\n' "$YEL" "$R" "$*"; log "warn: $*"; }
die() { printf '\n%s✗ %s%s\n' "$RED" "$*" "$R" >&2; log "fatal: $*"; exit 1; }

SUDO_KEEP="" TMP=""
cleanup() {
    [[ -n $SUDO_KEEP ]] && kill "$SUDO_KEEP" 2>/dev/null
    [[ -n $TMP ]] && rm -rf "$TMP"
    SUDO_KEEP="" TMP=""
}
trap cleanup EXIT

# the terminal, even when the script itself arrives on stdin (curl | bash)
TTY=/dev/null
[[ -r /dev/tty && -w /dev/tty ]] && (: </dev/tty) 2>/dev/null && TTY=/dev/tty

# ask "question" [Y|N] -> 0 for yes
ask() {
    local q=$1 def=${2:-Y} hint reply=""
    [[ $def == Y ]] && hint="[Y/n]" || hint="[y/N]"
    if ((YES)) || [[ $TTY == /dev/null ]]; then
        [[ $def == Y ]]
        return
    fi
    printf '  %s?%s %s %s ' "$CYN" "$R" "$q" "$hint" >/dev/tty
    read -r reply </dev/tty || reply=""
    reply=${reply:-$def}
    [[ $reply =~ ^[Yy] ]]
}

# run a command (or print it with --dry-run). run_i: same, attached to the terminal
run() {
    if ((DRY)); then
        printf '  %s$ %s%s\n' "$D" "$*" "$R" >&3
        return 0
    fi
    log "\$ $*"
    "$@"
}
run_i() {
    if ((DRY)); then
        printf '  %s$ %s%s\n' "$D" "$*" "$R" >&3
        return 0
    fi
    log "\$ $*"
    "$@" <"$TTY"
}

have() { command -v "$1" >/dev/null 2>&1; }
tilde() { printf '%s' "${1/#$HOME/\~}"; }
json_str() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '"%s"' "$s"; }

# write stdin to a file (keeps symlinks: writes through them)
write_file() {
    local f=$1
    if ((DRY)); then
        printf '  %s> would write %s%s\n' "$D" "$(tilde "$f")" "$R" >&3
        cat >/dev/null
        return 0
    fi
    mkdir -p "$(dirname "$f")" && cat >"$f"
    log "wrote $f"
}

# one backup per file per run
declare -A BACKED_UP=()
backup() {
    local f=$1
    [[ -f $f && -z ${BACKED_UP[$f]:-} ]] || return 0
    BACKED_UP[$f]=1
    run cp -- "$f" "$f.bak-prism-$STAMP"
}

has_block() { [[ -f $1 ]] && grep -qxF -- "$2" "$1"; }

# remove the lines from $2 to $3 (inclusive) in file $1
strip_block() {
    local f=$1 b=$2 e=$3 tmp
    has_block "$f" "$b" || return 0
    if ((DRY)); then
        printf '  %s> would remove the Prism block from %s%s\n' "$D" "$(tilde "$f")" "$R" >&3
        return 0
    fi
    tmp=$(mktemp)
    awk -v b="$b" -v e="$e" '$0 == b { skip = 1; next } skip && $0 == e { skip = 0; next } !skip' "$f" >"$tmp" &&
        cat "$tmp" >"$f"
    rm -f "$tmp"
    # drop the blank line the block left at the end
    if [[ -f $f && -z $(tail -n1 "$f") && -s $f ]]; then
        tmp=$(mktemp)
        sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$f" >"$tmp" && cat "$tmp" >"$f"
        rm -f "$tmp"
    fi
}

# (re)write a marked block at the end of file $1; body on stdin.
# Only touches (and backs up) the file when the result differs.
put_block() {
    local f=$1 b=$2 e=$3 body new
    body=$(cat)
    new=$(mktemp)
    if [[ -f $f ]]; then
        awk -v b="$b" -v e="$e" '$0 == b { skip = 1; next } skip && $0 == e { skip = 0; next } !skip' "$f" |
            sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >"$new"
    fi
    [[ -s $new ]] && printf '\n' >>"$new"
    printf '%s\n%s\n%s\n' "$b" "$body" "$e" >>"$new"
    if [[ -f $f ]] && cmp -s "$new" "$f"; then
        rm -f "$new"
        return 0
    fi
    if ((DRY)); then
        printf '  %s> would update the Prism block in %s%s\n' "$D" "$(tilde "$f")" "$R" >&3
        rm -f "$new"
        return 0
    fi
    backup "$f"
    mkdir -p "$(dirname "$f")"
    cat "$new" >"$f"
    rm -f "$new"
    log "block -> $f"
}

usage() {
    cat <<EOF
${B}Prism installer${R} — bare Arch -> Hyprland + Prism

Usage: install.sh [options]

  -y, --yes          accept every default, don't ask
  -n, --dry-run      show what would happen, change nothing
      --no-packages  skip installing packages
      --no-hypr      don't touch ~/.config/hypr (no config, autostart, binds)
      --no-binds     autostart only, keep your own keybinds
      --no-apps      don't theme kitty / GTK
      --no-login     don't start Hyprland automatically on tty1
      --no-screentime  skip the screen-time tracker
      --no-start     don't start anything at the end
      --uninstall    take Prism back out (packages stay)
  -h, --help         this help

Log: $(tilde "$LOG")
EOF
}

while (($#)); do
    case $1 in
    -y | --yes) YES=1 ;;
    -n | --dry-run) DRY=1 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --no-hypr) DO_HYPR=0 ;;
    --no-binds) DO_BINDS=0 ;;
    --no-apps) DO_APPS=0 ;;
    --no-login) DO_LOGIN=0 ;;
    --no-screentime) DO_ST=0 ;;
    --no-start) DO_START=0 ;;
    --uninstall) UNINSTALL=1 ;;
    -h | --help) usage; exit 0 ;;
    *) usage; die "unknown option: $1" ;;
    esac
    shift
done

banner() {
    printf '\n'
    printf '%s%s   ___      _               %s\n' "$B" "$MAG" "$R"
    printf '%s%s  / _ \\_ __(_)___ _ __ ___  %s\n' "$B" "$CYN" "$R"
    printf '%s%s / /_)/ '"'"'__| / __| '"'"'_ ` _ \\ %s\n' "$B" "$GRN" "$R"
    printf '%s%s/ ___/| |  | \\__ \\ | | | | |%s\n' "$B" "$YEL" "$R"
    printf '%s%s\\/    |_|  |_|___/_| |_| |_|%s\n' "$B" "$RED" "$R"
    printf '  %sHyprland + Quickshell, coloured by your wallpaper%s\n' "$D" "$R"
    ((DRY)) && printf '  %s(dry run — nothing will be changed)%s\n' "$YEL" "$R"
}

login_files() { printf '%s\n' "$HOME/.bash_profile" "$HOME/.zprofile"; }

# ============================================================== uninstall ===
uninstall() {
    banner
    step "Removing Prism"

    if has_block "$HYPR_LUA" "$LUA_B"; then
        backup "$HYPR_LUA"
        strip_block "$HYPR_LUA" "$LUA_B" "$LUA_E"
        ok "unhooked Prism from hyprland.lua"
    fi
    if grep -q "Prism starter config" "$HYPR_LUA" 2>/dev/null; then
        info "${D}hyprland.lua is Prism's starter config — it stays (it's a normal Hyprland config).${R}"
    fi
    if has_block "$MATUGEN_CONF" "$SH_B"; then
        backup "$MATUGEN_CONF"
        strip_block "$MATUGEN_CONF" "$SH_B" "$SH_E"
        ok "removed Prism's templates from matugen/config.toml"
    fi
    for f in $(login_files); do
        has_block "$f" "$SH_B" && { strip_block "$f" "$SH_B" "$SH_E"; ok "Hyprland no longer starts from $(tilde "$f")"; }
    done
    [[ -f $FISH_LOGIN ]] && run rm -f -- "$FISH_LOGIN" && ok "removed $(tilde "$FISH_LOGIN")"
    has_block "$KITTY_CONF" "$SH_B" && { strip_block "$KITTY_CONF" "$SH_B" "$SH_E"; ok "kitty no longer uses Prism colours"; }
    for g in gtk-3.0 gtk-4.0; do
        has_block "$CONFIG_HOME/$g/gtk.css" "$CSS_B" && strip_block "$CONFIG_HOME/$g/gtk.css" "$CSS_B" "$CSS_E"
    done
    if [[ -f $SCREENTIME_DIR/install.sh ]]; then
        st_un=(--uninstall --yes)
        ((DRY)) && st_un+=(--dry-run)
        run_i env -C "$SCREENTIME_DIR" bash ./install.sh "${st_un[@]}" && ok "screen-time tracker removed (your data stays in $(tilde "$SCREENTIME_DIR"))"
    elif [[ -f $ST_SERVICE ]]; then
        run systemctl --user disable --now hypr-screentime.service >/dev/null 2>&1
        run rm -f -- "$ST_SERVICE" "$ST_DESKTOP"
        run systemctl --user daemon-reload
        ok "stopped the screen-time tracker (your data stays in $(tilde "$SCREENTIME_DIR"))"
    fi

    if pidof quickshell >/dev/null; then
        run pkill -x quickshell
        ok "stopped Quickshell"
    fi
    if [[ -d $DEST ]]; then
        run mv -- "$DEST" "$DEST.removed-$STAMP"
        ok "moved the shell to $(tilde "$DEST.removed-$STAMP")"
    fi
    local last
    last=$(ls -1d "$DEST".bak-* 2>/dev/null | sort | tail -n1)
    if [[ -n $last ]] && ask "Restore your previous Quickshell config ($(basename "$last"))?" Y; then
        run mv -- "$last" "$DEST"
        ok "restored $(basename "$last")"
    fi

    step "Done"
    info "Packages were left installed. Reload Hyprland (hyprctl reload) to drop Prism's binds."
    exit 0
}

((UNINSTALL)) && uninstall

# ============================================================= preflight ===
banner
log "---- install $STAMP (yes=$YES dry=$DRY) ----"
step "Checking your system"

((EUID == 0)) && die "Run this as your normal user, not root. It asks for your password (sudo) when it needs it."

ARCH=0
if have pacman; then
    ARCH=1
    ok "Arch-based system"
else
    warn "No pacman, so packages can't be installed for you — you'll get a list instead."
    DO_PACKAGES=0
fi

if ((DO_PACKAGES)); then
    if curl -fsS --max-time 10 -o /dev/null https://archlinux.org 2>/dev/null; then
        ok "internet works"
    else
        warn "couldn't reach archlinux.org — packages will fail to download without internet"
        ask "Carry on anyway?" N || die "Connect to the internet (nmtui / iwctl) and run this again."
    fi
fi

[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && IN_HYPR=1 || IN_HYPR=0
ON_CONSOLE=0
[[ $IN_HYPR == 0 && -z ${WAYLAND_DISPLAY:-} && -z ${DISPLAY:-} && -z ${SSH_CONNECTION:-} && -n ${XDG_VTNR:-} ]] && ON_CONSOLE=1

# ============================================================== packages ===
DESKTOP=(
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent polkit
    qt5-wayland qt6-wayland xdg-user-dirs xdg-utils
    pipewire wireplumber pipewire-alsa
    networkmanager bluez bluez-utils upower
    kitty thunar gvfs tumbler pavucontrol unzip
)
SHELL_PKGS=(
    quickshell qt6-svg qt6-imageformats
    matugen awww cava
    wl-clipboard cliphist grim slurp wf-recorder hyprpicker
    brightnessctl playerctl imagemagick ffmpeg ffmpegthumbnailer
    hyprlock libnotify curl git
    python pyside6 # apps/prism-clock (the floating clock / timer / alarms)
)
LOOKS=(
    ttf-nerd-fonts-symbols ttf-jetbrains-mono-nerd ttf-roboto adwaita-fonts
    noto-fonts noto-fonts-emoji noto-fonts-cjk
    breeze-icons papirus-icon-theme adw-gtk-theme
)
EXTRA_REPO=(easyeffects kdeconnect zenity)
EXTRA_AUR=(mpvpaper glava ani-cli)
declare -A EXTRA_DESC=(
    [firefox]="web browser"
    [easyeffects]="audio effects (switch in the Audio tab)"
    [kdeconnect]="phone card: battery, ring, send files"
    [zenity]="file picker for sending files to your phone"
    [mpvpaper]="video / live wallpapers"
    [glava]="desktop audio visualizer"
    [ani-cli]="launcher \"a \" mode: watch anime"
)

BROWSERS=(firefox zen-browser librewolf brave chromium google-chrome-stable vivaldi-stable)
first_of() { local c; for c in "$@"; do have "$c" && { echo "$c"; return; }; done; }

if ((ARCH)); then
    # pipewire-pulse replaces pulseaudio; tlp and power-profiles-daemon can't both be installed
    if pacman -Q pulseaudio >/dev/null 2>&1; then
        warn "pulseaudio is installed — keeping it (PipeWire's pulse replacement skipped)"
    else
        DESKTOP+=(pipewire-pulse)
    fi
    pacman -Q tlp >/dev/null 2>&1 || DESKTOP+=(power-profiles-daemon)
fi
[[ -z $(first_of "${BROWSERS[@]}") ]] && EXTRA_REPO=(firefox "${EXTRA_REPO[@]}")

missing() {
    local p
    for p in "$@"; do pacman -Q "$p" >/dev/null 2>&1 || printf '%s\n' "$p"; done
}

AUR=""
pick_aur() { AUR=""; for h in yay paru; do have "$h" && { AUR=$h; return; }; done; }

install_yay() {
    info "building yay from the AUR (takes a minute)…"
    run_i sudo pacman -S --needed --noconfirm base-devel git || return 1
    if ((DRY)); then
        run git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        run makepkg -si --noconfirm
        AUR=yay
        return 0
    fi
    local t
    t=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$t/yay-bin" >>"$LOG" 2>&1 || { rm -rf "$t"; return 1; }
    (cd "$t/yay-bin" && makepkg -si --noconfirm <"$TTY") || { rm -rf "$t"; return 1; }
    rm -rf "$t"
    pick_aur
    [[ -n $AUR ]]
}

WANT_ST=0 ST_ASKED=0
if ((DO_PACKAGES)); then
    step "Packages"
    # keep sudo alive for the whole run
    if ((!DRY)); then
        sudo -v <"$TTY" || die "sudo is needed to install packages."
        (while kill -0 $$ 2>/dev/null; do sudo -n -v 2>/dev/null; sleep 50; done) &
        SUDO_KEEP=$!
    fi

    if ((DO_ST)); then
        info "The dashboard's Screen time tab is fed by a small tracker (hyprland-screen_time)."
        if ask "Track screen time? (python + PySide6, runs as a user service)" Y; then
            WANT_ST=1
            SHELL_PKGS+=(libpulse) # pactl, for counting audio; python + pyside6 are already in
        fi
        ST_ASKED=1
    fi
    mapfile -t NEED < <(missing "${DESKTOP[@]}" "${SHELL_PKGS[@]}" "${LOOKS[@]}")
    if ((${#NEED[@]})); then
        info "${B}${#NEED[@]} packages${R} to install: ${D}${NEED[*]}${R}"
        if ask "Update the system and install them?" Y; then
            flags=(-Syu --needed)
            ((YES)) && flags+=(--noconfirm)
            run_i sudo pacman "${flags[@]}" "${NEED[@]}" || die "pacman failed — scroll up for the reason, fix it, and run this again."
            ok "desktop, shell, fonts and icons installed"
        else
            warn "skipped — Prism won't work properly until these are installed"
        fi
    else
        ok "everything Prism needs is already installed"
    fi

    pick_aur
    if [[ -n $AUR ]]; then
        ok "AUR helper: $AUR"
    elif ask "Install yay so AUR packages (video wallpapers, GLava, ani-cli) work?" Y; then
        install_yay && ok "yay installed" || warn "couldn't build yay — AUR extras skipped (see $(tilde "$LOG"))"
    fi

    mapfile -t NEED_X < <(missing "${EXTRA_REPO[@]}")
    NEED_A=()
    [[ -n $AUR ]] && mapfile -t NEED_A < <(missing "${EXTRA_AUR[@]}")
    if ((${#NEED_X[@]} + ${#NEED_A[@]})); then
        info "Extras:"
        for p in "${NEED_X[@]}" "${NEED_A[@]}"; do
            printf '    %s%-12s%s %s\n' "$B" "$p" "$R" "${EXTRA_DESC[$p]:-}"
        done
        PICK=()
        if ask "Install all of them?" Y; then
            PICK=("${NEED_X[@]}" "${NEED_A[@]}")
        else
            for p in "${NEED_X[@]}" "${NEED_A[@]}"; do
                ask "  $p?" N && PICK+=("$p")
            done
        fi
        REPO_PICK=() AUR_PICK=()
        for p in "${PICK[@]}"; do
            [[ " ${EXTRA_AUR[*]} " == *" $p "* ]] && AUR_PICK+=("$p") || REPO_PICK+=("$p")
        done
        if ((${#REPO_PICK[@]})); then
            run_i sudo pacman -S --needed --noconfirm "${REPO_PICK[@]}" && ok "installed ${REPO_PICK[*]}" || warn "some extras failed"
        fi
        if ((${#AUR_PICK[@]})); then
            if [[ $AUR == yay ]]; then
                aflags=(-S --needed --noconfirm --answerdiff None --answerclean None --removemake)
            else
                aflags=(-S --needed --noconfirm --skipreview)
            fi
            run_i "$AUR" "${aflags[@]}" "${AUR_PICK[@]}" && ok "installed ${AUR_PICK[*]}" || warn "some AUR extras failed"
        fi
    fi

    # services the desktop talks to
    for svc in NetworkManager bluetooth power-profiles-daemon; do
        systemctl list-unit-files "$svc.service" >/dev/null 2>&1 || ((DRY)) || continue
        systemctl is-enabled "$svc" >/dev/null 2>&1 && continue
        if [[ $svc == NetworkManager ]] && systemctl is-active -q iwd systemd-networkd 2>/dev/null; then
            info "${D}leaving your network setup alone (iwd / networkd) — the Wi-Fi tab needs NetworkManager${R}"
            continue
        fi
        ask "Enable $svc?" Y && run_i sudo systemctl enable --now "$svc" >/dev/null 2>&1 && ok "enabled $svc"
    done

    have xdg-user-dirs-update && run xdg-user-dirs-update
    have fc-cache && run fc-cache -f >/dev/null 2>&1
elif ((!ARCH)); then
    step "Packages (install these yourself — Arch names)"
    info "${DESKTOP[*]} ${SHELL_PKGS[*]} ${LOOKS[*]}"
    info "optional: ${EXTRA_REPO[*]} ${EXTRA_AUR[*]}"
    info "screen time: python pyside6 libpulse"
fi

# Hyprland 0.55+ is a must (Prism uses its Lua API)
if have Hyprland || { ((ARCH)) && pacman -Q hyprland >/dev/null 2>&1; }; then
    HV=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    [[ -z $HV ]] && ((ARCH)) && HV=$(pacman -Q hyprland hyprland-git 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    if [[ -n $HV ]]; then
        IFS=. read -r hmaj hmin _ <<<"$HV"
        ((hmaj == 0 && hmin < 55)) && die "Hyprland $HV is too old — Prism needs 0.55+. Update with: sudo pacman -Syu"
        ok "Hyprland $HV"
    fi
elif ((!DRY)); then
    die "Hyprland isn't installed — run without --no-packages, or: sudo pacman -S hyprland"
fi
for cmd in quickshell matugen awww; do
    have "$cmd" || ((DRY)) || warn "$cmd is missing — Prism needs it"
done

# ================================================================= files ===
step "Installing Prism to $(tilde "$DEST")"

SELF=$(readlink -f "${BASH_SOURCE[0]:-}" 2>/dev/null || true)
SRC=""
[[ -n $SELF && -f $(dirname "$SELF")/shell.qml ]] && SRC=$(dirname "$SELF")

if [[ -z $SRC ]]; then
    [[ $PRISM_REPO == *CHANGE_ME* ]] && die "PRISM_REPO isn't set — clone the repo and run ./install.sh from it."
    have git || die "git is needed to download Prism (sudo pacman -S git)"
    TMP=$(mktemp -d)
    info "downloading $PRISM_REPO"
    if ((DRY)); then
        run git clone --depth 1 "$PRISM_REPO" "$TMP/prism"
        SRC=$TMP
    else
        git clone --depth 1 "$PRISM_REPO" "$TMP/prism" >>"$LOG" 2>&1 || die "download failed ($PRISM_REPO)"
        SRC=$TMP/prism
    fi
fi

copy_shell() {
    if ((DRY)); then
        printf '  %s$ copy %s -> %s%s\n' "$D" "$SRC" "$(tilde "$DEST")" "$R" >&3
        return 0
    fi
    # everything except local state (settings, palette, caches)
    (cd "$SRC" && tar --exclude=./.cache --exclude=./.state --exclude=./config.json -cf - .) | (cd "$DEST" && tar -xf -) ||
        die "copying files failed"
}

if [[ -d $DEST && $(readlink -f "$DEST") == "$(readlink -f "$SRC")" ]]; then
    ok "running from $(tilde "$DEST") — files are already in place"
elif [[ -f $DEST/shell.qml ]] && grep -q "Prism" "$DEST/shell.qml"; then
    copy_shell
    ok "updated Prism (your config.json and palette are kept)"
else
    if [[ -e $DEST ]]; then
        run mv -- "$DEST" "$DEST.bak-$STAMP"
        ok "backed up your old config to $(tilde "$DEST.bak-$STAMP")"
    fi
    run mkdir -p "$DEST"
    copy_shell
    ok "copied Prism"
fi
run mkdir -p "$DEST/.state" "$DEST/.cache"
run chmod +x "$DEST/install.sh" "$DEST/scripts/thumbs.sh" "$DEST/apps/prism-clock/prism_clock.py" 2>/dev/null

# ================================================================ config ===
step "Personalising"

NAME=$(getent passwd "$USER" 2>/dev/null | cut -d: -f5 | cut -d, -f1)
NAME=${NAME%% *}
[[ -z $NAME ]] && NAME=${USER^}
TERMINAL=$(first_of kitty foot alacritty wezterm ghostty konsole gnome-terminal)
TERMINAL=${TERMINAL:-kitty}
FILES=$(first_of thunar nautilus dolphin nemo pcmanfm-qt pcmanfm)
FILES=${FILES:-thunar}
EDITOR_APP=$(first_of code codium code-oss zeditor zed subl kate gnome-text-editor mousepad)
EDITOR_APP=${EDITOR_APP:-xdg-open}
BROWSER=$(first_of "${BROWSERS[@]}")
BROWSER=${BROWSER:-firefox}
PICTURES=$(xdg-user-dir PICTURES 2>/dev/null || true)
[[ -z $PICTURES || $PICTURES == "$HOME" ]] && PICTURES=$HOME/Pictures
VIDEOS=$(xdg-user-dir VIDEOS 2>/dev/null || true)
[[ -z $VIDEOS || $VIDEOS == "$HOME" ]] && VIDEOS=$HOME/Videos
WALL_DIR=$PICTURES/Wallpapers
AVATAR=$HOME/.face
[[ -f $AVATAR ]] || AVATAR=""
KB=$(localectl status 2>/dev/null | awk -F': *' '/X11 Layout/ {print $2; exit}')
[[ -z $KB ]] && KB=$(localectl status 2>/dev/null | awk -F': *' '/VC Keymap/ {print $2; exit}' | cut -d- -f1)
[[ -z $KB || $KB == "(unset)" || $KB == n/a ]] && KB=us

LOCK=true
ask "Use Prism's own lock screen? (no = hyprlock)" Y || LOCK=false

# screen time (asked during the package step when packages are installed)
if ((DO_ST && !ST_ASKED)); then
    ask "Set up the screen-time tracker for the dashboard's Screen time tab?" Y && WANT_ST=1
fi

EXTRA_BINDS=""
((DO_HYPR && DO_BINDS)) && EXTRA_BINDS=$DEST/hypr/prism-binds.lua

if [[ -f $DEST/config.json ]]; then
    ok "keeping your config.json"
else
    write_file "$DEST/config.json" <<EOF
{
    "user": {
        "name": $(json_str "$NAME"),
        "avatar": $(json_str "$AVATAR")
    },
    "apps": {
        "terminal": $(json_str "$TERMINAL"),
        "browser": $(json_str "$BROWSER"),
        "files": $(json_str "$FILES"),
        "editor": $(json_str "$EDITOR_APP"),
        "searchUrl": "https://duckduckgo.com/?q=",
        "editFolders": [
            $(json_str "$HYPR_DIR"),
            $(json_str "$DEST")
        ]
    },
    "wallpaper": {
        "dir": $(json_str "$WALL_DIR"),
        "videoDir": $(json_str "$VIDEOS/Wallpapers"),
        "transition": "random",
        "matugenIndex": 0,
        "mode": "dark",
        "scheme": "",
        "nameFile": "",
        "copyTo": $(json_str "$DEST/.state/wallpaper")
    },
    "paths": {
        "matugenColors": $(json_str "$DEST/.state/colors.lua"),
        "binds": $(json_str "$HYPR_LUA"),
        "extraBinds": $(json_str "$EXTRA_BINDS"),
        "screentime": $(json_str "$( ((WANT_ST)) && echo "$SCREENTIME_DIR")"),
        "screenshots": $(json_str "$PICTURES/Screenshots"),
        "recordings": $(json_str "$VIDEOS/Recordings")
    },
    "lock": {
        "enabled": $LOCK,
        "pamConfig": "hyprlock"
    }
}
EOF
    ok "hi ${NAME}! terminal: $TERMINAL · files: $FILES · editor: $EDITOR_APP · browser: $BROWSER"
fi

# ============================================================== hyprland ===
STARTER=0
if ((DO_HYPR)); then
    step "Hyprland"
    state=custom
    if [[ ! -f $HYPR_LUA ]]; then
        state=none
    elif grep -q "Prism starter config" "$HYPR_LUA"; then
        state=starter
    else
        tmp=$(mktemp)
        awk -v b="$LUA_B" -v e="$LUA_E" '$0 == b { s = 1; next } s && $0 == e { s = 0; next } !s' "$HYPR_LUA" >"$tmp"
        if cmp -s <(sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp") <(sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' /usr/share/hypr/hyprland.lua 2>/dev/null) ||
            grep -qi "autogenerated" "$tmp"; then
            state=default
        fi
        rm -f "$tmp"
    fi
    [[ -f $HYPR_DIR/hyprland.conf && $state == none ]] && warn "found an old hyprland.conf — Hyprland uses hyprland.lua instead once it exists"

    install_starter=0
    case $state in
    none | default)
        info "Your Hyprland config is $([[ $state == none ]] && echo "missing" || echo "Hyprland's untouched default")."
        ask "Install Prism's full Hyprland config (layout, animations, window rules, keybinds)?" Y && install_starter=1
        ;;
    starter)
        ok "using Prism's starter config"
        STARTER=1
        ;;
    custom)
        info "You have your own hyprland.lua — Prism will only add its autostart$( ((DO_BINDS)) && echo " and keybinds") at the end."
        ask "Replace it with Prism's full config instead? (yours is backed up)" N && install_starter=1
        ;;
    esac

    if ((install_starter)); then
        backup "$HYPR_LUA"
        sed -e "s/__KB_LAYOUT__/$KB/" \
            -e "s|^local terminal = .*|local terminal = \"$TERMINAL\"|" \
            -e "s|^local files    = .*|local files    = \"$FILES\"|" \
            -e "s|^local browser  = .*|local browser  = \"$BROWSER\"|" \
            "$( ((DRY)) && echo "$SRC" || echo "$DEST")/hypr/starter-hyprland.lua" | write_file "$HYPR_LUA"
        ok "installed the full config (keyboard: $KB) → $(tilde "$HYPR_LUA")"
        STARTER=1
    fi

    {
        printf -- '-- Prism (added by install.sh — install.sh --uninstall removes this block)\n'
        printf 'dofile("%s/hypr/prism.lua")\n' "$DEST"
        ((DO_BINDS)) && printf 'dofile("%s/hypr/prism-binds.lua")\n' "$DEST"
    } | put_block "$HYPR_LUA" "$LUA_B" "$LUA_E"
    ok "Prism autostart$( ((DO_BINDS)) && echo " + keybinds") loaded from hyprland.lua"
    if ((DO_BINDS)) && [[ $state == custom ]] && ((!install_starter)); then
        info "${D}Prism's binds replace whatever those keys did before — SUPER+/ lists them, hypr/prism-binds.lua changes them${R}"
    fi

    # idle (dim -> lock -> screens off) is built into Prism; hypridle would do it twice
    ok "idle: dim at 3 min · lock at 4 · screens off at 5 (Dashboard → Settings to change)"

    # things that fight Prism for the same job
    declare -A ROLE=([waybar]="bar" [swaync]="notifications" [mako]="notifications" [dunst]="notifications"
        [hyprpaper]="wallpaper" [swww-daemon]="wallpaper" [hypridle]="idle" [ags]="shell" [eww]="widgets")
    found=0
    for p in "${!ROLE[@]}"; do
        refs=$(grep -rlsE "^[^-#]*\b$p\b" "$HYPR_DIR" --include='*.lua' --include='*.conf' 2>/dev/null | grep -v "hypridle.conf" | tr '\n' ' ')
        running=0
        pgrep -x "$p" >/dev/null 2>&1 && running=1
        ((running)) || [[ -n $refs ]] || continue
        ((found)) || info "Other tools doing Prism's jobs:"
        found=1
        msg="$p (${ROLE[$p]})"
        ((running)) && msg+=" is running"
        [[ -n $refs ]] && msg+=" · started in: ${refs//$HOME/\~}"
        warn "$msg"
        def=Y
        [[ ${ROLE[$p]} == shell || ${ROLE[$p]} == widgets ]] && def=N
        ((running)) && ask "  Stop $p now?" $def && run pkill -x "$p" && ok "stopped $p"
        systemctl --user is-enabled "$p.service" >/dev/null 2>&1 && ask "  Disable its user service?" $def &&
            run systemctl --user disable --now "$p.service"
    done
    ((found)) && info "Remove those from your autostart so they don't come back next login."
fi

# ======================================================== kitty + gtk ===
# does the user's own matugen config (outside Prism's block) already write this?
own_output() { [[ -f $MATUGEN_CONF ]] && awk -v b="$SH_B" -v e="$SH_E" '$0 == b { s = 1 } !s; $0 == e { s = 0 }' "$MATUGEN_CONF" | grep -q "$1"; }
THEME_KITTY=0 THEME_GTK=0
if ((DO_APPS)); then
    step "Apps"
    if ask "Colour kitty and GTK apps from your wallpaper too?" Y; then
        # kitty
        if own_output "kitty/"; then
            ok "kitty: your matugen config already colours it — left alone"
        elif [[ ! -f $KITTY_CONF ]]; then
            run mkdir -p "$(dirname "$KITTY_CONF")"
            run cp -- "$DEST/apps/kitty.conf" "$KITTY_CONF"
            ok "kitty: starter config (JetBrains Mono, blur-friendly opacity, wallpaper colours)"
        elif ! grep -q "prism-colors.conf" "$KITTY_CONF"; then
            printf 'include prism-colors.conf' | put_block "$KITTY_CONF" "$SH_B" "$SH_E"
            ok "kitty: added the wallpaper colours to your kitty.conf"
        else
            ok "kitty: already uses Prism's colours"
        fi
        own_output "kitty/" || THEME_KITTY=1

        # GTK 3 / 4 (adw-gtk3 theme + matugen colours)
        for g in gtk-3.0 gtk-4.0; do
            d=$CONFIG_HOME/$g
            if [[ ! -f $d/settings.ini ]]; then
                write_file "$d/settings.ini" <<EOF
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Adwaita Sans 11
gtk-application-prefer-dark-theme=1
EOF
            fi
            grep -qs "colors.css" "$d/gtk.css" && ! has_block "$d/gtk.css" "$CSS_B" ||
                printf "@import 'colors.css';" | put_block "$d/gtk.css" "$CSS_B" "$CSS_E"
        done
        if have gsettings; then
            run gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark 2>/dev/null
            run gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark 2>/dev/null
            run gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null
            run gsettings set org.gnome.desktop.interface font-name "Adwaita Sans 11" 2>/dev/null
        fi
        ok "GTK: adw-gtk3 + Papirus icons, coloured from the wallpaper"
        THEME_GTK=1
    fi
fi

# =========================================================== screen time ===
# The tracker (https://github.com/Jack02134x/hyprland-screen_time) has its own
# installer; Prism downloads it and hands over. Older checkouts without one get
# a plain systemd user service written here instead.
if ((WANT_ST)); then
    step "Screen time"
    if [[ -d $SCREENTIME_DIR/.git ]]; then
        if run git -C "$SCREENTIME_DIR" pull --ff-only -q >>"$LOG" 2>&1; then
            ok "tracker updated ($(tilde "$SCREENTIME_DIR"))"
        else
            warn "couldn't update the tracker (local changes?) — keeping the copy you have"
        fi
    elif [[ -e $SCREENTIME_DIR ]]; then
        warn "$(tilde "$SCREENTIME_DIR") exists but isn't a git checkout — leaving it alone"
    elif run git clone --depth 1 -q "$SCREENTIME_REPO" "$SCREENTIME_DIR" >>"$LOG" 2>&1; then
        ok "downloaded the tracker to $(tilde "$SCREENTIME_DIR")"
    else
        warn "couldn't download $SCREENTIME_REPO — skipping screen time"
        WANT_ST=0
    fi
fi

if ((WANT_ST)); then
    st_flags=(--yes)
    ((DO_PACKAGES)) && st_flags+=(--deps)
    ((DRY)) && st_flags+=(--dry-run)
    if [[ -f $SCREENTIME_DIR/install.sh ]] || ((DRY)); then
        if run_i env -C "$SCREENTIME_DIR" bash ./install.sh "${st_flags[@]}"; then
            ok "tracker installed by its own installer"
        else
            warn "the tracker's installer failed — see the output above"
        fi
    else
        write_file "$ST_SERVICE" <<EOF
[Unit]
Description=Hyprland screen time tracker
Documentation=$SCREENTIME_REPO
StartLimitIntervalSec=0

[Service]
Type=simple
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/env python3 $SCREENTIME_DIR/tracker.py
Restart=always
RestartSec=3
KillSignal=SIGTERM
TimeoutStopSec=10

[Install]
WantedBy=default.target
EOF
        run systemctl --user daemon-reload >/dev/null 2>&1
        if run systemctl --user enable --now hypr-screentime.service >/dev/null 2>&1; then
            ok "tracker running (systemctl --user status hypr-screentime)"
        else
            warn "couldn't start the tracker service — it starts on your next login"
        fi
        write_file "$ST_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Screen Time
Comment=Hyprland screen time dashboard
Exec=python3 $SCREENTIME_DIR/gui.py
Icon=preferences-system-time
Terminal=false
Categories=Utility;
StartupWMClass=hypr-screentime
EOF
    fi

    # an existing config.json (re-runs, updates) gets the tracker path if it has none
    if ((!DRY)) && [[ -f $DEST/config.json ]] && have python3; then
        python3 - "$DEST/config.json" "$SCREENTIME_DIR" <<'PY'
import json, sys
path, folder = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
paths = cfg.setdefault("paths", {})
if not paths.get("screentime"):
    paths["screentime"] = folder
    with open(path, "w") as f:
        json.dump(cfg, f, indent=4, sort_keys=True)
PY
    fi
fi

# =============================================================== matugen ===
step "Colours (matugen)"
[[ -f $MATUGEN_CONF ]] || printf '[config]\n' | write_file "$MATUGEN_CONF"
{
    printf '# Prism — added by install.sh (rerun it or use --uninstall to change this block)\n'
    printf '[templates.prism]\ninput_path = %s\noutput_path = %s\n' "'$DEST/matugen/prism-colors.lua'" "'$DEST/.state/colors.lua'"
    # the starter Hyprland config reads the palette for its borders
    ((STARTER)) && printf "post_hook = 'hyprctl reload >/dev/null 2>&1 || true'\n"
    if ((THEME_KITTY)) && ! own_output "kitty/"; then
        printf '\n[templates.prism-kitty]\ninput_path = %s\noutput_path = %s\n' "'$DEST/matugen/kitty-colors.conf'" "'$CONFIG_HOME/kitty/prism-colors.conf'"
        printf "post_hook = 'pkill -USR1 -x kitty || true'\n"
    fi
    if ((THEME_GTK)); then
        for g in gtk-3.0 gtk-4.0; do
            own_output "$g/colors.css" && continue
            printf '\n[templates.prism-%s]\ninput_path = %s\noutput_path = %s\n' "${g%%.*}" "'$DEST/matugen/gtk-colors.css'" "'$CONFIG_HOME/$g/colors.css'"
        done
    fi
} | put_block "$MATUGEN_CONF" "$SH_B" "$SH_E"
ok "every wallpaper change now recolours Prism$( ((STARTER)) && echo ", window borders")$( ((THEME_KITTY)) && echo ", kitty")$( ((THEME_GTK)) && echo " and GTK apps")"

# ============================================================ wallpapers ===
step "Wallpapers"
run mkdir -p "$WALL_DIR" "$PICTURES/Screenshots" "$VIDEOS/Recordings" "$VIDEOS/Wallpapers"
shopt -s nullglob nocaseglob
bundled=("$DEST"/wallpapers/*.jpg)
((DRY)) && bundled=("$SRC"/wallpapers/*.jpg)
if ((${#bundled[@]})); then
    run cp -n -- "${bundled[@]}" "$WALL_DIR/"
    ok "${#bundled[@]} wallpapers in $(tilde "$WALL_DIR") — drop your own in there too (SUPER+W to pick)"
fi
walls=("$WALL_DIR"/*.{png,jpg,jpeg,webp})
((DRY)) && walls=("${bundled[@]}")
shopt -u nullglob nocaseglob

if ((${#walls[@]})) && [[ ! -s $DEST/.state/colors.lua ]] && have matugen; then
    first=${walls[RANDOM % ${#walls[@]}]}
    if ((DRY)); then
        run matugen image "$first" -m dark --source-color-index 0
    elif matugen image "$first" -m dark --source-color-index 0 >>"$LOG" 2>&1; then
        cp -- "$first" "$DEST/.state/wallpaper"
        ok "first palette made from $(basename "$first")"
    else
        warn "matugen failed (see $(tilde "$LOG")) — pick a wallpaper with SUPER+W later"
    fi
    if ((IN_HYPR)) && have awww; then
        pidof awww-daemon >/dev/null || { run setsid -f awww-daemon >/dev/null 2>&1; ((DRY)) || sleep 0.6; }
        run awww img "$first" --transition-type grow >/dev/null 2>&1
    fi
fi

# ================================================================= login ===
if ((DO_LOGIN && DO_HYPR)) && ! systemctl is-enabled display-manager.service >/dev/null 2>&1; then
    step "Logging in"
    if ask "Start Hyprland automatically when you log in on the first console (tty1)?" Y; then
        LOGIN_SH='# start Hyprland after logging in on tty1 (added by Prism'"'"'s install.sh)
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" = 1 ]; then
    if command -v start-hyprland >/dev/null 2>&1; then exec start-hyprland; else exec Hyprland; fi
fi'
        login_shell=$(basename "$(getent passwd "$USER" | cut -d: -f7)")
        case $login_shell in
        zsh)
            printf '%s' "$LOGIN_SH" | put_block "$HOME/.zprofile" "$SH_B" "$SH_E"
            ok "zsh: Hyprland starts from ~/.zprofile"
            ;;
        fish)
            write_file "$FISH_LOGIN" <<'EOF'
# start Hyprland after logging in on tty1 (added by Prism's install.sh)
if status is-login; and test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
    if command -q start-hyprland; exec start-hyprland; else; exec Hyprland; end
end
EOF
            ok "fish: Hyprland starts from $(tilde "$FISH_LOGIN")"
            ;;
        *)
            if [[ ! -f $HOME/.bash_profile ]]; then
                printf '# ~/.bash_profile\n[[ -f ~/.bashrc ]] && . ~/.bashrc\n' | write_file "$HOME/.bash_profile"
            fi
            printf '%s' "$LOGIN_SH" | put_block "$HOME/.bash_profile" "$SH_B" "$SH_E"
            ok "bash: Hyprland starts from ~/.bash_profile"
            ;;
        esac
        info "${D}(log in on tty2 — Ctrl+Alt+F2 — if you ever need a plain console)${R}"
    fi
fi

# ================================================================= start ===
if ((DO_START && IN_HYPR)); then
    step "Starting Prism"
    if ask "Reload Hyprland and start Prism now?" Y; then
        ((DO_HYPR)) && run hyprctl reload >/dev/null
        pgrep -f 'wl-paste --type text --watch' >/dev/null || run setsid -f wl-paste --type text --watch cliphist store
        pgrep -f 'wl-paste --type image --watch' >/dev/null || run setsid -f wl-paste --type image --watch cliphist store
        pidof quickshell >/dev/null && run pkill -x quickshell && { ((DRY)) || sleep 0.5; }
        run setsid -f quickshell >/dev/null 2>&1
        ok "Prism is running"
    fi
fi

# ================================================================== done ===
step "All done"
cat <<EOF

  ${B}Keys${R}  ${D}— SUPER + / shows every one${R}
    SUPER + Q / Return   terminal           SUPER + D           close window
    SUPER + S            launcher           SUPER + Escape      dashboard
    SUPER + N            notifications      SUPER + SHIFT + Esc control drawer
    SUPER + V            clipboard          SUPER + .           emoji
    SUPER + W            wallpapers         SUPER + O           workspace overview
    SUPER + 1…0          workspaces         SUPER + SHIFT + TAB window switcher
    Print                screenshots        SUPER + ALT + R     screen recording
    SUPER + L            lock               SUPER + M           power menu

  ${B}Make it yours${R}
    settings      Dashboard → Settings, or $(tilde "$DEST")/config.json
    Hyprland      $(tilde "$HYPR_LUA")
    Prism keys    $(tilde "$DEST")/hypr/prism-binds.lua
    commands      $(tilde "$DEST")/action_commands.md
    update        cd $(tilde "$DEST") && git pull && ./install.sh
    undo          $(tilde "$DEST")/install.sh --uninstall
    log           $(tilde "$LOG")

EOF

if ((DO_START && ON_CONSOLE && !DRY)); then
    if ask "Start Hyprland now?" Y; then
        cleanup
        if have start-hyprland; then exec start-hyprland <"$TTY"; else exec Hyprland <"$TTY"; fi
    fi
fi
((IN_HYPR)) || info "Log in on tty1 (or type ${B}start-hyprland${R}) and Prism comes up with Hyprland."
