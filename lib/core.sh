# shellcheck shell=bash
# okoko - core helpers: logging, prompts, command runner, state paths.

OKOKO_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/okoko"
OKOKO_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/okoko"
OKOKO_GEN="$OKOKO_CONF/current"          # theme-rendered files live here
OKOKO_LOG="$OKOKO_STATE/okoko.log"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

mkdir -p "$OKOKO_STATE"

if [[ -t 1 ]]; then
    C_RST=$'\e[0m' C_DIM=$'\e[2m' C_RED=$'\e[31m' C_GRN=$'\e[32m'
    C_YLW=$'\e[33m' C_CYN=$'\e[36m' C_BLD=$'\e[1m'
else
    C_RST='' C_DIM='' C_RED='' C_GRN='' C_YLW='' C_CYN='' C_BLD=''
fi

_log()  { printf '%s [%s] %s\n' "$(date +%F\ %T)" "$1" "$2" >>"$OKOKO_LOG"; }
info()  { printf '%s[*]%s %s\n' "$C_CYN" "$C_RST" "$*"; _log INFO "$*"; }
ok()    { printf '%s[+]%s %s\n' "$C_GRN" "$C_RST" "$*"; _log OK "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YLW" "$C_RST" "$*" >&2; _log WARN "$*"; }
err()   { printf '%s[x]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; _log ERROR "$*"; }
die()   { err "$*"; exit 1; }
step()  { printf '\n%s%s== %s%s\n' "$C_BLD" "$C_CYN" "$*" "$C_RST"; _log STEP "$*"; }

has() { command -v "$1" >/dev/null 2>&1; }

# Fancy prompts when gum is available and we are interactive; plain fallback otherwise.
_gum_ok() { [[ -t 0 && -t 1 ]] && has gum; }

confirm() {   # confirm "Question?" [default y|n]
    local q="$1" def="${2:-y}"
    [[ "$ASSUME_YES" == 1 ]] && { [[ "$def" == y ]]; return; }
    if _gum_ok; then
        if [[ "$def" == y ]]; then gum confirm "$q"; else gum confirm --default=false "$q"; fi
        return
    fi
    local hint="[Y/n]"; [[ "$def" == n ]] && hint="[y/N]"
    read -r -p "$q $hint " reply
    reply="${reply:-$def}"
    [[ "$reply" =~ ^[Yy] ]]
}

choose() {    # choose "Header" default opt1 opt2 ...  -> prints choice
    local header="$1" def="$2"; shift 2
    if [[ "$ASSUME_YES" == 1 ]]; then printf '%s\n' "$def"; return; fi
    if _gum_ok; then
        gum choose --header "$header" --selected "$def" "$@"
        return
    fi
    local i=1 opt
    printf '%s\n' "$header" >&2
    for opt in "$@"; do printf '  %d) %s\n' "$i" "$opt" >&2; ((i++)); done
    read -r -p "Choice [$def]: " reply
    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= $# )); then
        printf '%s\n' "${!reply}"
    else
        printf '%s\n' "$def"
    fi
}

# run <cmd...> : executes (or prints in dry-run), logging everything.
run() {
    _log RUN "$*"
    if [[ "$DRY_RUN" == 1 ]]; then
        printf '%s  $ %s%s\n' "$C_DIM" "$*" "$C_RST"
        return 0
    fi
    "$@" >>"$OKOKO_LOG" 2>&1
}

# spin "Title" <cmd...> : same as run, with a spinner when possible.
spin() {
    local title="$1"; shift
    if [[ "$DRY_RUN" != 1 ]] && _gum_ok; then
        _log RUN "$*"
        gum spin --spinner dot --title " $title" -- bash -c '"$@" >>"'"$OKOKO_LOG"'" 2>&1' _ "$@"
    else
        info "$title"
        run "$@"
    fi
}

sudo_keepalive() {
    [[ "$DRY_RUN" == 1 ]] && return
    sudo -v || die "sudo is required"
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
}

apt_install() {   # apt_install pkg... (skips packages that are unknown to apt)
    local want=() p
    for p in "$@"; do
        if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "ok installed"; then continue; fi
        if apt-cache show "$p" >/dev/null 2>&1; then want+=("$p"); else warn "package not available: $p"; fi
    done
    (( ${#want[@]} == 0 )) && return 0
    spin "apt: ${want[*]}" sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${want[@]}"
}
