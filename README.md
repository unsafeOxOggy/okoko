<div align="center">

# okoko

**A modular, themeable i3 rice for offensive-security VMs.**

Lightweight enough for a KVM/QEMU guest, reproducible from a single `apt`-based
installer, and built around the way you actually work in a lab: VPN IP and target
always on the bar, instant theme switching, and a built-in keybinding cheat sheet.

`i3` - `polybar` - `picom` - `kitty` - `rofi` - `dunst` - `zsh + starship`

</div>

---

## Why this exists

This is a ground-up rewrite of my earlier `okoko-i3`, inspired by
[xct/kali-clean](https://github.com/xct/kali-clean). The old version was a flat pile
of configs copied into place. okoko is built on three ideas instead:

1. **One theme engine, many apps.** Colors live in *one* `*.theme` file. A single
   `okoko theme redteam` re-renders i3, polybar, kitty, rofi, dunst, tmux, btop,
   starship and fzf, then hot-reloads everything - no logout.
2. **Symlinks, not copies.** `install.sh` backs up your existing dotfiles and
   symlinks okoko's in. `okoko update` pulls and relinks. `okoko uninstall` restores.
3. **Made for the work.** The bar shows your `tun0` IP and current target; `Super+t`
   sets the current target and `Super+i` copies your `tun0` IP - both stay visible on the bar.

## Install

```bash
git clone https://github.com/unsafeOxOggy/okoko.git
cd okoko
./install.sh
```

Then log out, pick **i3** at the LightDM menu, and log back in.
`./install.sh --minimal` installs only the core (no zsh/extras); `--dry-run` prints
every action without touching your system. In a KVM/QEMU guest the installer offers
**kvm-autofit** (see below); force the choice with `--autofit=bash|rs|none`.

> Targets Debian 12+ / Kali Rolling. Needs a non-root user with `sudo`.

## The `okoko` command

```
okoko theme [name]      apply a theme (no name -> interactive picker)
okoko theme --list      list themes
okoko wallpaper next    cycle wallpaper (or: gen | restore)
okoko doctor            check the environment, report problems
okoko autofit [bash|rs] install kvm-autofit (screen follows the KVM window)
okoko link              (re)deploy dotfiles as symlinks
okoko update            git pull + relink + reapply theme
okoko uninstall         remove symlinks, restore backups
```

## Keybindings (highlights)

`$mod` = **Super**. Full, always-up-to-date list: **`Super+F1`**.

| Shortcut | Action |
|---|---|
| `Super+Return` | terminal - `Super+grave` dropdown - `Super+Shift+Return` floating |
| `Super+space` | app launcher - `Super+Tab` window switcher |
| `Super+h/j/k/l` | focus (vim) - `+Shift` move |
| `Super+1..0` | workspace - `+Shift` move window there |
| `Super+t` | set target IP - `Super+i` copy VPN IP |
| `Super+Shift+t` | switch theme - `Super+q` next wallpaper |
| `Super+x` | power menu - `Super+Escape` lock - `Print` screenshot |

## Themes

| | palette | vibe |
|---|---|---|
| **okoko** | [`#091413 #285A48 #408A71 #B0E4CC`](https://colorhunt.co/palette/091413285a48408a71b0e4cc) | dark terminal green (default) |
| **redteam** | [`#000000 #830000 #BC0202 #FF0000`](https://colorhunt.co/palette/000000830000bc0202ff0000) | black & blood red |
| **synthwave** | [`#0D1164 #640D5F #EA2264 #F78D60`](https://colorhunt.co/palette/0d1164640d5fea2264f78d60) | neon retro night |
| **blueteam** | [`#091540 #1B2CC1 #7692FF #ABD2FA`](https://colorhunt.co/palette/0915401b2cc17692ffabd2fa) | deep navy |
| **tokyo-night** | [Tokyo Night](https://omarchy.gallery/themes/tokyo-night) | classic dark blue/purple |
| **kanagawa** | [Kanagawa](https://omarchy.gallery/themes/kanagawa) | muted ink-wash (Wave) |
| **catppuccin-latte** | [Catppuccin Latte](https://omarchy.gallery/themes/catppuccin-latte) | soft **light** theme |

Palettes are checked for WCAG AA contrast on UI text (body >= 4.5:1); the ANSI terminal
ramp (C0-C15) stays faithful to each upstream theme. Tokyo Night, Kanagawa and
Catppuccin Latte palettes come from [Omarchy](https://omarchy.gallery).
Add your own: drop a `themes/mytheme.theme` (copy an existing one) and run `okoko theme mytheme`.

### Add a theme

```sh
cp themes/okoko.theme themes/mytheme.theme
$EDITOR themes/mytheme.theme          # set BG/SURFACE/ACCENT/FG + the C0..C15 ramp
okoko theme mytheme
```

## Layout

```
okoko
|-- okoko                 # the CLI (theme/doctor/update/...)
|-- install.sh            # idempotent installer (symlink + backup)
|-- lib/                  # core.sh - detect.sh - theme.sh - link.sh - autofit.sh
|-- bin/                  # okoko-session - okoko-bar - okoko-menu - okoko-wall - okoko-lock - okoko-dropdown
|-- templates/            # one file per app, with {{COLOR}} placeholders
|-- themes/               # *.theme palettes
|-- home/                 # dotfiles, symlinked into ~ (i3 split into config.d/, zsh split into okoko/zsh/)
|-- extras/kvm-autofit/    # vendored bash edition of kvm-autofit
|-- wallpapers/
`-- tests/                # bats smoke tests (+ shellcheck in CI)
```

## Notes

- **Compositor backend is auto-detected**: `xrender` inside VMs / software GL,
  `glx` on real GPUs (`okoko doctor` shows which).
- **VM guest integration** (spice/qemu agent, clipboard, resolution) starts
  automatically when a hypervisor is detected.
- **kvm-autofit** fixes the classic KVM annoyance where the guest screen does not
  follow the viewer window (wrong size at the greeter, after login, or when toggling
  fullscreen until you log out and back in). A udev rule (bash edition) or a small
  netlink daemon (Rust edition, built separately from `kvm-autofit-rs`) applies the
  size the host asks for on every X display, greeter included. The bash edition is
  vendored here; `okoko autofit rs` uses a `kvm-autofit-rs` checkout found in
  `~/kvm-autofit-rs` (or `$KVM_AUTOFIT_RS_DIR`) and falls back to bash otherwise.
  In virt-manager keep *View -> Scale Display -> Auto resize VM with window* on.
- **Nothing runs `curl | sh`**: zsh plugins come from Debian packages; the Nerd
  Font is only fetched if `fonts-jetbrains-mono` isn't available.
- The target/VPN helpers keep your `tun0` IP and current engagement target
  visible on the bar and in the prompt - handy on a lab VM you own and snapshot.

## Credits

Spiritual ancestor: [xct/kali-clean](https://github.com/xct/kali-clean).
Palettes from [Color Hunt](https://colorhunt.co). Font: JetBrainsMono Nerd Font.
