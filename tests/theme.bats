#!/usr/bin/env bats
# Smoke tests for the theme engine (no X / no packages required).

setup() {
    export OKOKO_ROOT="$BATS_TEST_DIRNAME/.."
    export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
    export XDG_STATE_HOME="$HOME/.local/state" XDG_CONFIG_HOME="$HOME/.config"
    source "$OKOKO_ROOT/lib/core.sh"
    source "$OKOKO_ROOT/lib/theme.sh"
}

@test "lists the shipped themes" {
    run theme_list
    [[ "$output" == *okoko* && "$output" == *redteam* ]]
}

@test "every theme defines all required vars as #RRGGBB" {
    for t in $(theme_list); do theme_load "$t"; done
}

@test "rendering leaves no template placeholders" {
    theme_apply okoko --no-reload
    run grep -rl '{{' "$XDG_CONFIG_HOME/okoko/current"
    [ "$status" -ne 0 ]
}

@test "colors.sh is valid shell" {
    theme_apply okoko --no-reload
    run bash -n "$XDG_CONFIG_HOME/okoko/current/colors.sh"
    [ "$status" -eq 0 ]
}

@test "switching theme updates the saved name" {
    theme_apply redteam --no-reload
    [ "$(theme_current)" = redteam ]
}
