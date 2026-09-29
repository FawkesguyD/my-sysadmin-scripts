#!/bin/bash
#
# setup script: Скрипт принимает аргумент (имя пользователя), создаёт директорию, файл .bashrc, выдаёт приветствие и записывает факт создания в лог
#

set -euo pipefail
IFS='
'

usage() {
  cat <<EOF
Usage: script.sh -u USERNAME [-s | -m | -d | -b]

Options:
  -u USERNAME     User
  -s              Create .ssh directory
  -m              Modify
  -b STRING       Add string to .bashrc
  -d              Delete home dir
  -h              Show help message
}
EOF
  exit 2
}

usr=""
createsshdir=false
modify=false
flush=false
bashstring=""

while getopts ":u:b:hsmd" opt; do
  case "${opt}" in
    u) usr="${OPTARG}" ;;
    s) createsshdir=true ;;
    m) modify=true ;;
    b) bashstring="${OPTARG}" ;;
    d) flush=true ;;
    h) usage; exit 0 ;;
    :) echo "Option -${OPTARG} need an argument" >&2; usage; exit 2 ;;
    \?) echo "ERROR: Unknown option ${OPTARG}" >&2; usage; exit 2 ;;
  esac
done
shift "$((OPTIND-1))"


usrdir="/home/${usr}"

if [[ "${flush}" == true ]]; then
  rm -rf "${usrdir}"
  logger -t script "INFO[${usr}]: delete home dir finished successfully."
  exit 0
fi


if [[ "${modify}" == false ]]; then
  mkdir "${usrdir}"
  cat <<'EOF' > "${usrdir}/.bashrc"
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
  logger -t script "INFO[${usr}]: setup finished successfully."
fi


if [[ "${createsshdir}" == true ]]; then
  mkdir "${usrdir}/.ssh"
  logger -t script "INFO[${usr}]: add .ssh dir"
fi

if [[ "${bashstring}" != "" ]]; then
  echo "${bashstring}" >> "${usrdir}/.bashrc"
  logger -t script "INFO[${usr}]: new string to bashrc added successfully."
fi


echo "Пользователь ${usr} добавлен в систему, информация записана в лог"