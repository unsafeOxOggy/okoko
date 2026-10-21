#!/usr/bin/env bash
# okoko - installer. Idempotent, backs up existing dotfiles, deploys via symlink.
set -euo pipefail
OKOKO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export OKOKO_ROOT
source "$OKOKO_ROOT/lib/core.sh"
source "$OKOKO_ROOT/lib/detect.sh"
source "$OKOKO_ROOT/lib/theme.sh"
source "$OKOKO_ROOT/lib/link.sh"
source "$OKOKO_ROOT/lib/autofit.sh"

for a in "$@"; do case "$a" in
    --dry-run) DRY_RUN=1 ;; --yes|-y) ASSUME_YES=1 ;;
    --minimal) MINIMAL=1 ;;
    --autofit=bash|--autofit=rs|--autofit=none) AUTOFIT="${a#--autofit=}" ;;
    --autofit=*) die "--autofit expects bash, rs or none" ;;
esac; done
MINIMAL="${MINIMAL:-0}"
AUTOFIT="${AUTOFIT:-ask}"

[[ $EUID -eq 0 ]] && die "run as a normal user with sudo, not as root"
detect_all
is_debian_like || warn "okoko targets Debian/Kali; '$DISTRO_ID' is untested - continuing"

step "okoko installer  -  $DISTRO_NAME  -  virt=$VIRT"
confirm "Install okoko (backs up any existing dotfiles first)?" y || { info "aborted"; exit; }
sudo_keepalive

step "1/7  packages"
run sudo apt-get update -qq
CORE=(i3-wm i3status i3blocks picom kitty rofi feh flameshot dunst
      fonts-font-awesome fonts-jetbrains-mono papirus-icon-theme
      xclip xdotool x11-xserver-utils x11-utils unclutter copyq
      xfce4-screensaver libnotify-bin wget tar fontconfig)
EXTRA=(zsh zsh-autosuggestions zsh-syntax-highlighting fzf eza bat zoxide starship
       fastfetch btop tmux neovim imagemagick librsvg2-bin gum playerctl brightnessctl)
VM=(spice-vdagent qemu-guest-agent)
apt_install "${CORE[@]}"
[[ "$MINIMAL" == 1 ]] || apt_install "${EXTRA[@]}"
if [[ "$VIRT" != none ]]; then apt_install "${VM[@]}"; fi

step "2/7  Nerd Font"
# Debian's fonts-jetbrains-mono is the plain font (no icons): the bar, rofi and the
# prompt need the *Nerd Font* build, which Debian does not package. Pinned + checksummed.
NERD_VER=v3.4.0
NERD_SHA256=ef552a3e638f25125c6ad4c51176a6adcdce295ab1d2ffacf0db060caf8c1582
# (no grep -q here: it exits at the first match, fc-list gets SIGPIPE and pipefail fails the test)
if ! fc-list 2>/dev/null | grep -i "JetBrainsMono Nerd Font" >/dev/null; then
    TMP_DIR=$(mktemp -d); trap 'rm -rf "$TMP_DIR"' EXIT
    spin "download JetBrainsMono Nerd Font $NERD_VER" wget -q -O "$TMP_DIR/f.tar.xz" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_VER/JetBrainsMono.tar.xz"
    if [[ "$DRY_RUN" == 1 ]] || echo "$NERD_SHA256  $TMP_DIR/f.tar.xz" | sha256sum --quiet -c -; then
        run mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
        run tar -xf "$TMP_DIR/f.tar.xz" -C "$HOME/.local/share/fonts/JetBrainsMonoNerd" --wildcards '*.ttf'
        run fc-cache -f
    else
        warn "Nerd Font checksum mismatch - not installed (icons will be missing)"
    fi
fi
fc-list 2>/dev/null | grep -i "JetBrainsMono Nerd Font" >/dev/null && ok "font ready" || warn "JetBrainsMono Nerd Font missing"

step "3/7  deploy dotfiles (symlinks + backup)"
BACKUP_STAMP=$(date +%Y%m%d-%H%M%S)
run mkdir -p "$HOME/.local/bin" "$HOME/Pictures/Screenshots"
link_bin
link_tree ".config"
for f in .zshrc .xsessionrc; do link_file "$OKOKO_ROOT/home/$f" "$HOME/$f"; done
# starter wallpaper(s)
run mkdir -p "$HOME/.config/okoko/wallpapers"
run cp -n "$OKOKO_ROOT"/wallpapers/* "$HOME/.config/okoko/wallpapers/" 2>/dev/null || true
ok "dotfiles deployed (backup: $OKOKO_STATE/backup/$BACKUP_STAMP)"

step "4/7  apply theme"
theme_apply "$(theme_current)" --no-reload

step "5/7  shell"
if has zsh && [[ "$MINIMAL" != 1 ]] && [[ "$SHELL" != *zsh ]]; then
    if confirm "Make zsh your default shell?" y; then
        run chsh -s "$(command -v zsh)" && ok "default shell -> zsh (effective next login)"
    fi
fi

step "6/7  VM display auto-fit (kvm-autofit)"
if [[ "$AUTOFIT" == ask ]]; then
    if autofit_wanted && confirm "KVM guest: install kvm-autofit so the screen follows the VM window?" y; then
        AUTOFIT=bash
        [[ -x "$AUTOFIT_RS_DIR/dist/bin/kvm-autofit" ]] && confirm "Use the Rust edition found in $AUTOFIT_RS_DIR?" n && AUTOFIT=rs
    else
        AUTOFIT=none
    fi
fi
if [[ "$AUTOFIT" == none ]]; then info "skipped"; else autofit_install "$AUTOFIT" || true; fi

step "7/7  done"
okoko doctor || true
cat <<DONE

${C_GRN}${C_BLD}okoko installed.${C_RST}
  1. Log out, pick ${C_BLD}i3${C_RST} at the LightDM session menu, log back in.
  2. ${C_BLD}Super+F1${C_RST} shows the keybinding cheat sheet.
  3. ${C_BLD}Super+Shift+t${C_RST} switches theme - ${C_BLD}okoko doctor${C_RST} checks health.
DONE
