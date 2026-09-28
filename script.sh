#!/bin/bash
#
# setup script: Скрипт принимает аргумент (имя пользователя), создаёт директорию, файл .bashrc, выдаёт приветствие и записывает факт создания в лог
#

set -euo pipefail

usr=$1

mkdir "/home/${usr}"
touch "/home/${usr}/.bashrc"
cat <<'EOF' > ~/.bashrc
# Only for interactive shells
case $- in
    *i*) ;;
      *) return;;
esac

# Command history
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# Prompt
PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

logger -t script "Setup for ${usr} finished successfully."
echo "Пользователь ${usr} добавлен в систему, информация записана в лог"