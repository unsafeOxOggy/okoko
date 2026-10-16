# okoko - zsh entry point - the real config lives in ~/.config/okoko/zsh/*.zsh
# (loaded in name order). Put machine-local tweaks in ~/.zshrc.local.

export STARSHIP_CONFIG="$HOME/.config/okoko/current/starship.toml"

for _okoko_rc in ~/.config/okoko/zsh/*.zsh(N); do
    source "$_okoko_rc"
done
unset _okoko_rc

[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
