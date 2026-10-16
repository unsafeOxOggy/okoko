# okoko · aliases
if (( $+commands[eza] )); then
    alias ls='eza --group-directories-first --icons=auto'
    alias ll='eza -lh --group-directories-first --icons=auto --git'
    alias la='eza -lah --group-directories-first --icons=auto --git'
    alias lt='eza --tree --level=2 --icons=auto'
else
    alias ls='ls --color=auto'; alias ll='ls -lh'; alias la='ls -lah'
fi
(( $+commands[batcat] )) && alias cat='batcat --paging=never --style=plain' && alias bat='batcat'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias please='sudo $(fc -ln -1)'
alias c='clear'
alias ports='ss -tulpn'
alias myip='curl -s https://ifconfig.me; echo'
alias cb='xclip -selection clipboard'
