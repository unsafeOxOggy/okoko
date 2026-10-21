# okoko - pentest-lab workflow helpers for an authorized testing VM.
# The target IP and VPN IP are shared with the bar / tmux / the prompt through
# small state files under ~/.local/state/okoko so every component stays in sync.

OKOKO_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/okoko"

# tgt [IP|clear]  - show or set the engagement target, mirrored to the bar.
tgt() {
    local f="$OKOKO_STATE_DIR/target"
    mkdir -p "$OKOKO_STATE_DIR"
    case "$1" in
        "")      [[ -s $f ]] && cat "$f" || echo "no target set" ;;
        clear|-) : >"$f"; echo "target cleared" ;;
        *)       printf '%s\n' "$1" >"$f"; export OKOKO_TARGET="$1"; echo "target -> $1" ;;
    esac
    pkill -RTMIN+1 -x i3blocks 2>/dev/null   # refresh the target block
}

# Expose VPN/target to the prompt before each command.
_okoko_precmd() {
    local v t
    v=$(okoko-bar vpn --plain 2>/dev/null); t=$(cat "$OKOKO_STATE_DIR/target" 2>/dev/null)
    [[ -n $v ]] && export OKOKO_VPN="$v" || unset OKOKO_VPN
    [[ -n $t ]] && export OKOKO_TARGET="$t" || unset OKOKO_TARGET
}
autoload -Uz add-zsh-hook && add-zsh-hook precmd _okoko_precmd

# serve [port]  - HTTP server on the VPN IP for file transfer during a lab (default 8000).
serve() {
    local port="${1:-8000}" ip
    ip=$(okoko-bar vpn --plain 2>/dev/null)
    echo "serving $PWD  ->  http://${ip:-0.0.0.0}:$port/"
    python3 -m http.server "$port"
}

# mkloot  - create a tidy working tree for the current target.
mkloot() {
    local base="$HOME/engagements/${1:-$(cat "$OKOKO_STATE_DIR/target" 2>/dev/null || date +%F)}"
    mkdir -p "$base"/{recon,loot,exploit,notes}
    echo "$base"
    cd "$base"
}
