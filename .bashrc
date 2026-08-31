#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History: big file, no duplicates, share across terminals
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Append to history file immediately (not just on exit)
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

alias wpass='nmcli device wifi show-password'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=kvantum
export GTK_THEME=Adwaita:dark

export PATH="$PATH:$HOME/.config/composer/vendor/bin:$HOME/.cargo/bin"

#alias mountwork='gocryptfs ~/hider/.work_vault ~/hider/work'
#alias umountwork='fusermount -u ~/hider/work'

# Better bash completion
[[ -r "/usr/share/bash-completion/bash_completion" ]] && . "/usr/share/bash-completion/bash_completion"

# FZF (Fuzzy Finder for history and files)
eval "$(fzf --bash)"

# Zoxide (Smarter 'cd' that remembers your directories)
eval "$(zoxide init bash)"
alias cd="z"

# Eza (Better 'ls' with colors)
alias ls="eza --icons=always --color=always"
alias ll="eza -l --icons=always --color=always"

if [ -z "$SSH_AUTH_SOCK" ]; then
   eval $(ssh-agent -s) > /dev/null
fi

export MOZ_ENABLE_WAYLAND=1
export THUNDERBIRD_WAYLAND=1
alias reset-dock='sudo sh -c "echo -n \"usb2\" > /sys/bus/usb/drivers/usb/unbind && sleep 1 && echo -n \"usb2\" > /sys/bus/usb/drivers/usb/bind"'

# Fix Lenovo dock USB (Renesas controller) after using with Windows — no reboot needed
alias fixdock='sudo /usr/local/bin/renesas-usb-fix.sh'
