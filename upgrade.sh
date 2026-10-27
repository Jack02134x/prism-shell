#!/usr/bin/env bash
# Prism — upgrade an installed Prism to the latest version on GitHub.
#
#   ~/.config/quickshell/upgrade.sh
#   # or, from anywhere
#   bash <(curl -fsSL https://raw.githubusercontent.com/Jack02134x/prism-shell/main/upgrade.sh)
#
# 1. downloads what changed (git), including files that were removed
# 2. your own edits to Prism's files are backed up to .state/, then kept on top
#    of the new version where they still apply
# 3. hands over to the new install.sh --refresh, which re-applies Prism to what
#    you already set up (no setup questions; nothing you said no to comes back),
#    installs any packages the new version needs, updates Prism Login Manager if
#    Prism installed it (--no-plm skips that), and restarts Prism
#
# config.json, .state/ (palette, settings, history), .cache/ and local/ are
# never touched. upgrade.sh --help for options.

set -uo pipefail

PRISM_REPO="${PRISM_REPO:-https://github.com/Jack02134x/prism-shell.git}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/prism-install.log"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ -t 1 ]]; then
    B=$'\e[1m' D=$'\e[2m' R=$'\e[0m' RED=$'\e[31m' GRN=$'\e[32m' YEL=$'\e[33m' MAG=$'\e[35m' CYN=$'\e[36m'
else
    B="" D="" R="" RED="" GRN="" YEL="" MAG="" CYN=""
fi
mkdir -p "$(dirname "$LOG")" 2>/dev/null

log() { printf '[%s] %s\n' "$(date +%T)" "$*" >>"$LOG" 2>/dev/null; }
step() { printf '\n%s%s◆ %s%s\n' "$B" "$MAG" "$*" "$R"; log "== $*"; }
info() { printf '  %s\n' "$*"; log "$*"; }
ok() { printf '  %s✓%s %s\n' "$GRN" "$R" "$*"; log "ok: $*"; }
warn() { printf '  %s!%s %s\n' "$YEL" "$R" "$*"; log "warn: $*"; }
die() { printf '\n%s✗ %s%s\n' "$RED" "$*" "$R" >&2; log "fatal: $*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
tilde() { printf '%s' "${1/#$HOME/\~}"; }

TTY=/dev/null
[[ -r /dev/tty && -w /dev/tty ]] && (: </dev/tty) 2>/dev/null && TTY=/dev/tty

YES=0 DRY=0 CHECK=0 FORCE=0 NO_PLM=0
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

usage() {
    cat <<EOF
${B}Prism upgrade${R} — get the latest Prism, keep your settings

Usage: upgrade.sh [options]

  -y, --yes       accept every default, don't ask
  -n, --dry-run   show what's new and what would happen, change nothing
      --check     only say whether an update is available
                  (exit 0: there is one, 1: up to date, 2: couldn't check)
      --force     re-apply (install.sh --refresh) even when already up to date
      --no-plm    don't update Prism Login Manager this time
  -h, --help      this help

Log: $(tilde "$LOG")
EOF
}

SCRATCH=""
cleanup() { [[ -n $SCRATCH ]] && rm -rf "$SCRATCH"; SCRATCH=""; }
trap cleanup EXIT

# git as Prism (so stash works without a git identity), blind to chmod-only changes
g() { git -C "$DEST" -c core.fileMode=false -c user.name=Prism -c user.email=prism@localhost "$@"; }

# everything below runs from inside main(): git replaces this file while it runs
main() {
    local f
    while (($#)); do
        case $1 in
        -y | --yes) YES=1 ;;
        -n | --dry-run) DRY=1 ;;
        --check) CHECK=1 ;;
        --force) FORCE=1 ;;
        --no-plm) NO_PLM=1 ;;
        -h | --help) usage; exit 0 ;;
        *) usage; die "unknown option: $1" ;;
        esac
        shift
    done

    # the copy this script belongs to, else the usual place
    local self
    self=$(readlink -f "${BASH_SOURCE[0]:-}" 2>/dev/null || true)
    if [[ -n $self && -f $(dirname "$self")/shell.qml ]]; then
        DEST=$(dirname "$self")
    else
        DEST=$CONFIG_HOME/quickshell
    fi

    ((EUID == 0)) && die "Run this as your normal user, not root."
    [[ -f $DEST/shell.qml ]] && grep -q "Prism" "$DEST/shell.qml" ||
        die "Prism isn't installed in $(tilde "$DEST") — install it with install.sh first."
    have git || die "git is needed (sudo pacman -S git)"
    log "---- upgrade $STAMP (yes=$YES dry=$DRY check=$CHECK force=$FORCE) ----"

    ((CHECK)) || printf '\n%s%sPrism upgrade%s  %s%s%s\n' "$B" "$MAG" "$R" "$D" "$(tilde "$DEST")" "$R"

    # ------------------------------------------------------------- fetch ---
    local fresh=0 branch remote
    if [[ ! -d $DEST/.git ]]; then
        # a copy without git history (very old installs): track the repo from here on
        ((CHECK)) && { echo "can't tell: $(tilde "$DEST") isn't a git checkout yet (run upgrade.sh once)"; exit 2; }
        fresh=1
    fi
    branch=main
    if ((!fresh)); then
        branch=$(g symbolic-ref --short -q HEAD) || die "$(tilde "$DEST") isn't on a branch (detached HEAD) — check out main first."
        remote=$(g config --get "branch.$branch.remote") || remote=origin
        g remote get-url "$remote" >/dev/null 2>&1 || remote=""
    fi

    ((CHECK)) || step "Checking for updates"
    local fetch_from=${remote:-$PRISM_REPO}
    if ((fresh)); then
        # fetch into a scratch repo first so a dry run changes nothing
        SCRATCH=$(mktemp -d)
        local scratch=$SCRATCH
        git -C "$scratch" init -q && git -C "$scratch" fetch -q --depth 1 "$PRISM_REPO" "$branch" >>"$LOG" 2>&1 ||
            die "couldn't reach $PRISM_REPO (internet?)"
        NEW=$(git -C "$scratch" rev-parse FETCH_HEAD)
    else
        g fetch -q "$fetch_from" "$branch" >>"$LOG" 2>&1 || {
            ((CHECK)) && { echo "couldn't check: no connection to $fetch_from"; exit 2; }
            die "couldn't reach $fetch_from (internet?)"
        }
        NEW=$(g rev-parse FETCH_HEAD)
    fi
    OLD=$( ((fresh)) || g rev-parse HEAD)

    local behind=0
    if ((!fresh)); then
        if [[ $OLD == "$NEW" ]] || g merge-base --is-ancestor "$NEW" "$OLD" 2>/dev/null; then
            behind=0
        elif g merge-base --is-ancestor "$OLD" "$NEW" 2>/dev/null; then
            behind=$(g rev-list --count "$OLD..$NEW")
        else
            ((CHECK)) && { echo "can't tell: your checkout has its own commits"; exit 2; }
            die "your copy has commits of its own that the new version doesn't. Merge it yourself:
    cd $(tilde "$DEST") && git pull"
        fi
    fi

    if ((CHECK)); then
        if ((behind)); then
            echo "update available: $behind new change$( ((behind > 1)) && echo s)"
            exit 0
        fi
        echo "Prism is up to date"
        exit 1
    fi

    if ((!fresh && !behind)); then
        ok "Prism is already up to date ($(g log -1 --format='%h, %cr'))"
        if ((!FORCE)); then
            info "${D}(--force re-applies it anyway)${R}"
            exit 0
        fi
    fi

    # ------------------------------------------------------ what's new ---
    if ((behind)); then
        step "What's new"
        g log --no-decorate --format='    %C(auto)%h%C(reset) %s %C(dim)(%cr)%C(reset)' "$OLD..$NEW" | head -n 25
        ((behind > 25)) && info "${D}… and $((behind - 25)) more${R}"
        info "${D}$(g diff --shortstat "$OLD" "$NEW")${R}"
    elif ((fresh)); then
        info "this copy has no git history yet — it'll follow $PRISM_REPO from now on"
    fi

    # ------------------------------------------------------ your edits ---
    local -a edits=()
    if ((!fresh)); then
        mapfile -t edits < <(g diff --name-only HEAD 2>/dev/null)
    fi
    local backup=$DEST/.state/upgrade-backup-$STAMP keep=1
    if ((${#edits[@]})); then
        step "Your changes"
        info "You've edited ${#edits[@]} of Prism's files:"
        for f in "${edits[@]:0:15}"; do printf '    %s%s%s\n' "$D" "$f" "$R"; done
        ((${#edits[@]} > 15)) && info "${D}…${R}"
        ask "Keep your changes on top of the new version? (no = take the new files)" Y || keep=0
        info "${D}either way, your versions are saved in $(tilde "$backup")${R}"
    fi

    if ((DRY)); then
        step "Dry run"
        info "would update $(tilde "$DEST") to $(git -C "${scratch:-$DEST}" rev-parse --short "$NEW") and run install.sh --refresh:"
        if grep -q -- "--refresh)" "$DEST/install.sh"; then
            bash "$DEST/install.sh" --refresh --dry-run --yes $( ((NO_PLM)) && echo --no-plm)
        else
            info "then the new install.sh would re-apply Prism (this copy's install.sh is too old to preview that)"
        fi
        exit 0
    fi

    # ---------------------------------------------------------- update ---
    step "Updating"
    if ((${#edits[@]})); then
        local f
        for f in "${edits[@]}"; do
            [[ -e $DEST/$f ]] || continue
            mkdir -p "$backup/$(dirname "$f")" && cp -p -- "$DEST/$f" "$backup/$f"
        done
        ok "backed up your edits to $(tilde "$backup")"
    fi

    if ((fresh)); then
        # adopt the folder: the repo's files replace Prism's, and files the old
        # version had that the new one doesn't (they'd break the shell) move out
        g init -q && g remote add origin "$PRISM_REPO" 2>/dev/null
        g fetch -q --depth 1 origin "$branch" >>"$LOG" 2>&1 || die "couldn't download $PRISM_REPO"
        g reset -q "FETCH_HEAD" && g branch -q -M "$branch" && g branch -q -u "origin/$branch" 2>/dev/null
        local -a stale
        mapfile -t stale < <(g ls-files --others --exclude-standard -- '*.qml' '*.js' '*.py' '*.sh' '*.lua' 'qmldir')
        if ((${#stale[@]})); then
            for f in "${stale[@]}"; do
                mkdir -p "$backup/$(dirname "$f")" && mv -- "$DEST/$f" "$backup/$f"
            done
            ok "moved ${#stale[@]} old file(s) the new version doesn't have to $(tilde "$backup")"
            info "${D}(your own additions belong in local/ — Prism leaves that folder alone)${R}"
        fi
        mapfile -t edits < <(g diff --name-only)
        if ((${#edits[@]})); then
            for f in "${edits[@]}"; do
                [[ -e $DEST/$f && ! -e $backup/$f ]] && mkdir -p "$backup/$(dirname "$f")" && cp -p -- "$DEST/$f" "$backup/$f"
            done
            ok "${#edits[@]} file(s) differed from the new version — the new ones are used; yours: $(tilde "$backup")"
        fi
        g checkout -q -- . || die "couldn't write the new files"
        ok "now following $PRISM_REPO"
    elif ((${#edits[@]} && keep)); then
        g stash push -q -m "prism upgrade $STAMP" || die "couldn't set your edits aside (git stash) — nothing changed"
        g merge -q --ff-only "$NEW" || { g stash pop -q; die "couldn't update — nothing changed (see $(tilde "$LOG"))"; }
        if g stash pop -q >>"$LOG" 2>&1; then
            ok "updated, with your changes kept"
        else
            # where an edit clashes with the new version, the new version wins
            local -a clash
            mapfile -t clash < <(g diff --name-only --diff-filter=U)
            for f in "${clash[@]}"; do g checkout -q HEAD -- "$f"; done
            g reset -q
            if ((${#clash[@]})); then
                g stash drop -q
                ok "updated, with your changes kept — except in:"
                for f in "${clash[@]}"; do printf '    %s%s%s\n' "$YEL" "$f" "$R"; done
                info "those clashed with the new version, which is used there; yours: $(tilde "$backup")"
            else
                warn "updated, but your changes couldn't be put back — they're in $(tilde "$backup") (and in: git stash list)"
            fi
        fi
    else
        ((${#edits[@]})) && g checkout -q -- .
        g merge -q --ff-only "$NEW" || die "couldn't update (see $(tilde "$LOG"))"
        ok "updated to $(g log -1 --format='%h')"
    fi

    # --------------------------------------------------------- re-apply ---
    # the new install.sh knows what the new version needs
    local -a flags=(--refresh)
    ((YES)) && flags+=(--yes)
    ((NO_PLM)) && flags+=(--no-plm)
    cleanup
    exec bash "$DEST/install.sh" "${flags[@]}"
}

main "$@"
exit
