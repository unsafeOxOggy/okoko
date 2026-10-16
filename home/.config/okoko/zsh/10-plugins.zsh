# okoko · plugins from Debian packages (no network plugin manager)
_okoko_src() { [[ -r $1 ]] && source "$1"; }
_okoko_src /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
_okoko_src /usr/share/doc/fzf/examples/key-bindings.zsh
_okoko_src /usr/share/doc/fzf/examples/completion.zsh
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[starship] )) && eval "$(starship init zsh)"
# syntax highlighting must load last
_okoko_src /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
unfunction _okoko_src
