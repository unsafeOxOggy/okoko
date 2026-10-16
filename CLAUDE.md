# okoko - contexte projet (handoff pour Claude Code)

> Ce fichier est relu automatiquement au démarrage d'une session Claude Code dans ce repo.
> Il résume le but, l'architecture, l'état courant et les tâches en attente. Mets-le à jour
> quand l'état change.

## But

Rice i3 **modulaire et thémable** pour VM d'entraînement offensif (Kali en KVM/QEMU).
Réécriture totale de `okoko-i3` (ancien repo = configs à plat copiées en dur), inspirée de
`xct/kali-clean`. Priorités : léger pour une VM, installeur reproductible basé `apt`,
switch de thème instantané, workflow pentest (IP VPN + cible toujours visibles).

Stack : `i3` - `polybar` - `picom` - `kitty` - `rofi` - `dunst` - `zsh + starship`.

## Architecture (3 idées clés)

1. **Un moteur de thèmes, plusieurs apps.** Les couleurs vivent dans *un* `themes/<nom>.theme`.
   `okoko theme <nom>` rend tous les `templates/*` (remplace `{{VAR}}` -> `#RRGGBB`,
   `{{VAR.hex}}` -> `RRGGBB`) vers `~/.config/okoko/current/`, puis recharge à chaud
   i3/polybar/kitty/dunst/tmux (voir `lib/theme.sh` -> `theme_reload`).
2. **Symlinks, pas de copies.** `install.sh`/`okoko link` sauvegardent les dotfiles existants
   dans `~/.local/state/okoko/backup/<ts>/` puis lient ceux de `home/`. `okoko uninstall` restaure.
3. **Fait pour le taf.** Barre montre `tun0` + cible ; `Super+t` cible, `Super+i` copie VPN.

## Layout

```
okoko                  # CLI principale (theme/doctor/link/update/uninstall/wallpaper/bar)
install.sh             # installeur idempotent (apt + font + symlinks + chsh), flags --dry-run --minimal --yes
lib/core.sh            # log, prompts (gum si dispo), run/spin, apt_install, sudo_keepalive
lib/detect.sh          # distro, virt (systemd-detect-virt), backend picom (xrender en VM / glx sinon)
lib/theme.sh           # moteur de thèmes : THEME_VARS, THEME_TARGETS, theme_apply/reload
lib/link.sh            # symlinks + backup + manifest (~/.local/state/okoko/manifest) + restore
bin/okoko-session      # autostart idempotent (exec_always depuis i3) : picom, bar, wall, dunst, agent VM
bin/okoko-bar          # lance les îlots polybar sur chaque écran + modules vpn/target/workspaces
bin/okoko-menu         # menus rofi : theme | power | target | keys (cheat sheet générée)
bin/okoko-wall         # wallpaper : next/gen/restore (gen = formes géométriques depuis la palette)
bin/okoko-lock         # i3lock-color thémé
bin/okoko-dropdown     # terminal déroulant (scratchpad)
templates/             # 1 fichier/app avec tokens {{COULEUR}} (+ starship.toml, colors.sh, btop.theme...)
themes/*.theme         # palettes
home/                  # dotfiles -> symlinkés dans ~ (i3 en config.d/, zsh en okoko/zsh/)
wallpapers/ tests/ .github/workflows/ci.yml
```

## Thèmes (7)

`okoko` (défaut, vert terminal), `redteam`, `synthwave`, `blueteam` (Color Hunt) +
`tokyo-night`, `kanagawa`, `catppuccin-latte` (depuis Omarchy, demandés par l'utilisateur).
**catppuccin-latte est CLAIR** (le moteur gère clair/sombre, les couleurs sont juste des variables).

Ajouter un thème : `cp themes/okoko.theme themes/x.theme`, éditer, `okoko theme x`.
Contrôle contraste WCAG AA : `python3 -I <scratchpad>/contrast.py themes/` (script jetable, à
recréer si besoin : il calcule le ratio sur des paires FG/BG/ACCENT/MUTED). Règle retenue :
**UI text >= 4.5:1** ; la rampe ANSI C0-C15 reste fidèle à l'upstream (usages large/bold -> 3:1 OK).

## VM cible

- `ssh kali@192.168.100.18` - user `kali`. **Clé SSH déjà installée** (accès sans mdp). Ne jamais écrire
  de mot de passe ici : ce fichier est poussé sur un dépôt GitHub **public**.
- KVM/QEMU, virtio-GPU (-> picom `xrender`), 4 CPU / 8 Go / Kali Rolling, LightDM, zsh+OMZ.
- **Snapshots en place** (l'utilisateur peut casser/restaurer librement).
- Déploiement : `rsync -az --exclude=.git ./ kali@192.168.100.18:~/okoko/` puis `okoko link` / `okoko theme`.

## État courant (MAJ 2026-10-16)

- [x] Projet écrit, 7 thèmes, `bash -n` + i3 `-C` OK, git branche `master`.
- [x] Déployé sur la VM : dotfiles **linkés**, thème **rendu**, CLI `okoko` opérationnelle.
- [!] **Paquets apt PAS encore installés** sur la VM (dunst, fonts-jetbrains-mono, papirus,
  unclutter, i3lock-color, xss-lock + extras fzf/eza/bat/zoxide/starship/btop/gum...).
  -> l'utilisateur doit lancer **`cd ~/okoko && ./install.sh`** dans un terminal de la VM
  (le classificateur de sécurité empêche Claude de saisir le mot de passe sudo à sa place).
- [x] Remote GitHub `git@github.com:unsafeOxOggy/okoko.git` (**public**). Le `.git` local a disparu le
  2026-10-16 (cause inconnue, pas d'action de Claude) -> historique repris d'un nouveau commit initial.
- [x] kvm-autofit intégré : `lib/autofit.sh`, étape 6/7 de `install.sh` (`--autofit=bash|rs|none`,
  proposé seulement si `VIRT` = kvm/qemu), `okoko autofit [bash|rs]`, check dans `okoko doctor`.
  Édition bash **vendorisée** dans `extras/kvm-autofit/` (source : `~/DEV/kvm-autofit`, commit dans
  `extras/kvm-autofit/VENDORED` - re-copier après chaque changement là-bas). Édition Rust : jamais de
  binaire dans ce dépôt ; on utilise `~/kvm-autofit-rs/dist/bin` (`KVM_AUTOFIT_RS_DIR`) sinon repli bash.
  La VM a actuellement l'édition **rust** installée (démon actif).

## TODO / en attente

1. [x] **rofi drun seul, sans arrondis** (fait 2026-10-16, synchronisé sur la VM, `rofi -dump-theme` OK
   en rofi 2.0.0). `mainbox` = `[inputbar, listview]` ; plus de mode-switcher ni de `border-radius`.
   `bin/okoko-menu` (`_rofi`) remet le widget `message` via `-theme-str` pour garder ses `-mesg`.
   Reste : valider visuellement sur la VM. `Super+Tab` (`rofi -show window`) est conservé.
2. Faire installer les paquets sur la VM (`./install.sh`) puis valider `okoko doctor` (tout [x])
   et le rendu réel (barre, rofi, lock) - idéalement screenshot via la VM.

## Décisions prises

- **polybar** gardé par défaut (pas Quickshell : Wayland/Qt6, hors apt Kali, lourd pour VM) - validé par l'utilisateur.
- **Retiré du projet** : générateur de reverse-shell et palette de commandes offensives
  (`menu_revshell`/`menu_cmds` et leurs bindings) - demande explicite de l'utilisateur.
  Ne **pas** les réintroduire. Garder seulement le workflow neutre cible/VPN/presse-papier.

## Conventions / pièges

- **Glyphs Nerd Font** : écrire un fichier directement via l'outil Write peut perdre les
  glyphes PUA. Méthode utilisée : écrire des tokens `@@xHEX@@` (ex `@@xf31a@@`) puis convertir
  en une passe Python (`chr(int(hex,16))`, via `os.walk` pour attraper les dossiers cachés `.config`).
- **Pas de `curl | sh`** : plugins zsh via paquets Debian. La **Nerd Font** est toujours requise
  (le paquet Debian `fonts-jetbrains-mono` est la police *sans* icônes) : install.sh étape 2 la
  télécharge depuis la release Nerd Fonts épinglée (`NERD_VER`) et vérifie `NERD_SHA256`.
  Bug corrigé le 2026-10-16 : l'ancien test sur le paquet Debian sautait le téléchargement
  -> plus aucune icône dans polybar.
- **Barre "îlots"** (2026-10-16, demandé par l'utilisateur) : style waybar-themes V2.2 porté
  sur polybar. 4 barres `override-redirect` (icons, workspaces, title, status) lancées par
  `okoko-bar launch`, bordure 2px `colors.border` (FG 80%), fond `colors.background` (BG 90%),
  radius 4. Largeurs fixes (polybar ne s'auto-dimensionne pas) ; i3 réserve la place avec
  `gaps top 36` (pas de `smart_gaps`, sinon fenêtres sous la barre). Workspaces = script
  `okoko-bar workspaces` (python3, abonnement i3) : 1-5 toujours affichés, au-delà une 6e case
  partagée ; seuls des numéros sont imprimés (pas d'injection de tags polybar). Couleurs des
  cases : actif FG/BG, occupé MUTED/BG, vide SURFACE/FG, urgent URGENT + texte le plus
  contrasté (contrastes >= 4.5:1 vérifiés sur les 7 thèmes).
- **sudo sur la VM** : Kali = tickets sudo par-tty ; feeding du mdp programmatiquement bloqué par
  le classificateur. -> laisser l'utilisateur lancer les étapes sudo lui-même (cf. règle CLAUDE.md
  globale "me prévenir pour les actions manuelles").
- i3 `window_type` est un **enum** (pas de regex avec alternation) ; `window_role` accepte le regex.
- `home/.zshrc` (point d'entrée : `STARSHIP_CONFIG` + source `~/.config/okoko/zsh/*.zsh`, puis
  `~/.zshrc.local`) et `home/.xsessionrc` (PATH `~/.local/bin` pour i3) manquaient jusqu'au 2026-10-16 ->
  shell cassé sur la VM (lien mort). `link_file` ignore désormais une source absente. Le `.zshrc`
  Kali d'origine (OMZ) est sauvegardé dans `~/.local/state/okoko/backup/20261016-061757/.zshrc`.
- `theme_apply <nom> --no-reload` pour rendre sans recharger (utile hors session X / en test).

## [!] Éviter le faux positif "cyber" (safeguards Opus 5.5)

Contexte à garder en tête pour **ne pas re-déclencher** le message
"Opus 5.5's safeguards flagged this session ... Details: `[cyber]`" (qui coupe la réponse
en plein milieu et bascule sur un modèle de repli).

- **Nature du projet, à rappeler si besoin** : c'est un *rice de bureau i3* (dotfiles, thèmes,
  barre, raccourcis) **défensif/éducatif**, pour une **VM de lab que l'utilisateur possède et
  snapshote**. Aucun ciblage de tiers, aucune exploitation. Travail d'automatisation de config,
  pas de pentest actif.
- **Le classificateur est une protection plateforme** : je ne peux pas le désactiver ni le
  contourner, et je ne dois pas essayer. On réduit seulement les *faux positifs* par la manière
  d'écrire.
- **Ce qui l'avait déclenché** : des heredocs bash générant des one-liners de **reverse-shell**
  et une **palette de commandes offensives** (nmap/nc/...). Ces éléments ont été **retirés du
  projet** et **ne doivent pas être réintroduits** (cf. section "Décisions prises").
- **Bonnes pratiques d'écriture** dans ce repo :
  - Pas de payloads offensifs concrets (reverse-shells, one-liners d'exploitation, listes de
    commandes d'attaque) dans le code, les templates ou les commits.
  - Le workflow pentest reste **neutre et métadonnées seulement** : afficher/copier l'IP `tun0`
    et une IP cible, créer des dossiers de travail - pas de génération de commandes offensives.
  - Décrire les fichiers par leur **rôle** ("module de workflow qui copie l'IP VPN") plutôt que
    coller du contenu sensible.
- **Si ça re-déclenche quand même** : c'est un faux positif. En informer l'utilisateur, continuer
  la partie sûre de la tâche, et lui laisser l'option `/feedback` (un signalement a déjà été
  rédigé) ou éditer/retry. Ne pas abandonner le projet légitime pour autant.

## Rappels prefs utilisateur (voir ~/.claude/CLAUDE.md)

Design : couleurs Color Hunt si non imposées (+ lien + tokens CSS + contraste AA) ; formes
géométriques de base non étirées ; police adaptée au domaine. Prévenir pour toute action manuelle
et finir par une checklist. (Les règles stack web Rust/Supabase ne s'appliquent pas ici.)
