# okoko · history, options, completion, keybindings
typeset -U path
path=(~/.local/bin $path)
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt extended_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks share_history inc_append_history
setopt auto_cd auto_pushd pushd_ignore_dups interactive_comments no_beep prompt_subst
WORDCHARS=${WORDCHARS//\/}

autoload -Uz compinit
compinit -d ~/.cache/zcompdump-$ZSH_VERSION
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{green}-- %d --%f'

bindkey -e
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^H' backward-kill-word

export EDITOR="${EDITOR:-vim}"
export PAGER=less
[[ -r ~/.config/okoko/current/colors.sh ]] && source ~/.config/okoko/current/colors.sh
