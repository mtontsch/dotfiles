# Shared aliases — sourced by .zshrc

# ls / navigation
alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lah'
alias ..='cd ..'
alias ...='cd ../..'

# grep
alias grep='grep --color=auto'

# git
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'

# tmux: attach to session (or create "main") — the usual post-ssh command
ta() { tmux attach -t "${1:-main}" 2>/dev/null || tmux new -s "${1:-main}"; }

# chezmoi
alias cz='chezmoi'
alias cza='chezmoi apply'
alias czd='chezmoi diff'

# pixi
alias px='pixi'
alias pxr='pixi run'
