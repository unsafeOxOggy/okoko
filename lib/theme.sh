# shellcheck shell=bash
# okoko - theme engine.
#
# A theme (themes/<name>.theme) is a list of shell color variables.
# Every templates/<file> is rendered by replacing {{VAR}} with "#RRGGBB" and
# {{VAR.hex}} with "RRGGBB", then written to its destination (see THEME_TARGETS).

THEME_VARS=(BG BG_ALT SURFACE ACCENT ACCENT2 FG MUTED URGENT WARN
            C0 C1 C2 C3 C4 C5 C6 C7 C8 C9 C10 C11 C12 C13 C14 C15)

# template -> destination
declare -gA THEME_TARGETS=(   # -g: stays global even when sourced from a function (bats setup)
    [i3-colors.conf]="$OKOKO_GEN/i3-colors.conf"
    [kitty-theme.conf]="$OKOKO_GEN/kitty-theme.conf"
    [xfce4-terminal.sh]="$OKOKO_GEN/xfce4-terminal.sh"
    [rofi-colors.rasi]="$OKOKO_GEN/rofi-colors.rasi"
    [tmux-theme.conf]="$OKOKO_GEN/tmux-theme.conf"
    [starship.toml]="$OKOKO_GEN/starship.toml"
    [colors.sh]="$OKOKO_GEN/colors.sh"
    [dunst-colors.conf]="${XDG_CONFIG_HOME:-$HOME/.config}/dunst/dunstrc.d/90-okoko-colors.conf"
    [btop.theme]="${XDG_CONFIG_HOME:-$HOME/.config}/btop/themes/okoko.theme"
)

theme_list() {
    local f
    for f in "$OKOKO_ROOT"/themes/*.theme; do basename "$f" .theme; done
}

theme_current() {
    cat "$OKOKO_STATE/theme" 2>/dev/null || echo okoko
}

theme_load() {   # theme_load <name> : sources the palette into the current shell
    local file="$OKOKO_ROOT/themes/$1.theme"
    [[ -f "$file" ]] || die "unknown theme '$1' (available: $(theme_list | xargs))"
    # shellcheck disable=SC1090
    . "$file"
    local v
    for v in "${THEME_VARS[@]}"; do
        [[ "${!v:-}" =~ ^#[0-9A-Fa-f]{6}$ ]] || die "theme $1: $v is missing or not #RRGGBB"
    done
}

theme_render() {   # theme_render <template> <dest>
    local tpl="$OKOKO_ROOT/templates/$1" dest="$2" v expr=()
    for v in "${THEME_VARS[@]}"; do
        expr+=(-e "s/{{$v\.hex}}/${!v#\#}/g" -e "s/{{$v}}/${!v}/g")
    done
    expr+=(-e "s/{{NAME}}/$NAME/g")
    if [[ "$DRY_RUN" == 1 ]]; then
        printf '%s  render %s -> %s%s\n' "$C_DIM" "$1" "$dest" "$C_RST"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    sed "${expr[@]}" "$tpl" >"$dest.tmp" && mv "$dest.tmp" "$dest"
}

theme_apply() {    # theme_apply <name> [--no-reload]
    local name="$1" t
    theme_load "$name"
    for t in "${!THEME_TARGETS[@]}"; do
        theme_render "$t" "${THEME_TARGETS[$t]}"
    done
    [[ "$DRY_RUN" == 1 ]] || printf '%s\n' "$name" >"$OKOKO_STATE/theme"
    ok "theme '$name' rendered"
    [[ "${2:-}" == --no-reload ]] && return
    theme_reload
}

# Hot-reload every running component so a theme switch is instant.
theme_reload() {
    [[ "$DRY_RUN" == 1 ]] && return
    pgrep -x i3 >/dev/null && i3-msg -q reload
    pkill -USR1 -x kitty 2>/dev/null || true
    sh "$OKOKO_GEN/xfce4-terminal.sh" >/dev/null 2>&1 || true   # open windows update at once
    pgrep -x dunst >/dev/null && { has dunstctl && dunstctl reload 2>/dev/null || pkill -x dunst; }
    pgrep -x tmux >/dev/null && tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null
    if [[ -n "${DISPLAY:-}" ]] && has okoko-wall; then okoko-wall auto >/dev/null 2>&1 & fi
    return 0
}
