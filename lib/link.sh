# shellcheck shell=bash
# okoko — dotfile deployment by symlink, with backups and a manifest for uninstall.
#
# Every file under $OKOKO_ROOT/home/ is linked to the same path under $HOME.
# Existing real files are moved to $OKOKO_STATE/backup/<timestamp>/ first.

MANIFEST="$OKOKO_STATE/manifest"

link_file() {   # link_file <src> <dest>
    local src="$1" dest="$2"
    # Never replace a working dotfile with a dangling link.
    if [[ ! -e "$src" ]]; then
        warn "skipping ~/${dest#"$HOME"/}: $src is missing"
        return 0
    fi
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        return 0
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        local bdir="$OKOKO_STATE/backup/$BACKUP_STAMP"
        local rel="${dest#"$HOME"/}"
        run mkdir -p "$bdir/$(dirname "$rel")"
        run mv "$dest" "$bdir/$rel"
        info "backed up ~/$rel"
    fi
    run mkdir -p "$(dirname "$dest")"
    run ln -s "$src" "$dest"
    [[ "$DRY_RUN" == 1 ]] || grep -qxF "$dest" "$MANIFEST" 2>/dev/null || printf '%s\n' "$dest" >>"$MANIFEST"
}

link_tree() {   # link_tree <subdir-of-home/>   e.g. ".config/i3"
    local base="$OKOKO_ROOT/home" sub="$1" f
    BACKUP_STAMP="${BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"
    while IFS= read -r -d '' f; do
        link_file "$f" "$HOME/${f#"$base"/}"
    done < <(find "$base/$sub" \( -type f -o -type l \) -print0 | sort -z)
}

link_bin() {    # expose bin/okoko-* (and the okoko CLI) in ~/.local/bin
    local f
    BACKUP_STAMP="${BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"
    for f in "$OKOKO_ROOT"/bin/*; do
        link_file "$f" "$HOME/.local/bin/$(basename "$f")"
    done
    link_file "$OKOKO_ROOT/okoko" "$HOME/.local/bin/okoko"
}

unlink_all() {
    [[ -f "$MANIFEST" ]] || { warn "nothing to remove (no manifest)"; return; }
    local dest
    while IFS= read -r dest; do
        if [[ -L "$dest" && "$(readlink -f "$dest")" == "$OKOKO_ROOT"/* ]]; then
            run rm "$dest" && info "removed ${dest/#$HOME/~}"
        fi
    done <"$MANIFEST"
    [[ "$DRY_RUN" == 1 ]] || : >"$MANIFEST"
}

restore_latest_backup() {
    local last
    last="$(find "$OKOKO_STATE/backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n1)"
    [[ -n "$last" ]] || { info "no backup to restore"; return; }
    info "restoring files from $last"
    (cd "$last" && find . -type f -print0) | while IFS= read -r -d '' f; do
        f="${f#./}"
        [[ -e "$HOME/$f" ]] && continue
        run mkdir -p "$HOME/$(dirname "$f")"
        run cp -a "$last/$f" "$HOME/$f"
        ok "restored ~/$f"
    done
}
