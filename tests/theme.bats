#!/usr/bin/env bats
# Smoke tests for the theme engine (no X / no packages required).
bats_require_minimum_version 1.5.0

setup() {
    export OKOKO_ROOT="$BATS_TEST_DIRNAME/.."
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    export XDG_STATE_HOME="$HOME/.local/state" XDG_CONFIG_HOME="$HOME/.config"
    # lib/core.sh defines its own run() (logged command runner), which would shadow
    # bats' run helper: keep bats' version available as bats_run first.
    declare -F bats_run >/dev/null || eval "bats_run() $(declare -f run | tail -n +2)"
    source "$OKOKO_ROOT/lib/core.sh"
    source "$OKOKO_ROOT/lib/theme.sh"
}

@test "lists the shipped themes" {
    bats_run theme_list
    [[ "$output" == *okoko* && "$output" == *redteam* ]]
}

@test "every theme defines all required vars as #RRGGBB" {
    for t in $(theme_list); do theme_load "$t"; done
}

@test "rendering leaves no template placeholders" {
    theme_apply okoko --no-reload
    # every target must exist, otherwise "no placeholder found" would pass vacuously
    for f in colors.sh i3-colors.conf kitty-theme.conf rofi-colors.rasi starship.toml; do
        [ -s "$XDG_CONFIG_HOME/okoko/current/$f" ]
    done
    bats_run -1 grep -rl '{{' "$XDG_CONFIG_HOME/okoko/current"
}

@test "colors.sh is valid shell" {
    theme_apply okoko --no-reload
    bats_run bash -n "$XDG_CONFIG_HOME/okoko/current/colors.sh"
    [ "$status" -eq 0 ]
}

@test "switching theme updates the saved name" {
    theme_apply redteam --no-reload
    [ "$(theme_current)" = redteam ]
}
