#!/bin/bash
#
# setup script: Скрипт принимает аргумент (имя пользователя), создаёт директорию, файл .bashrc, выдаёт приветствие и записывает факт создания в лог
#

set -euo pipefail

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
    u)
      if [[ ! "${OPTARG}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "ERROR: invalid username ${OPTARG}" >&2
        exit 2
      fi
      usr="${OPTARG}"
      ;;
    s) 
      createsshdir=true
      ;;
    m) 
      modify=true
      ;;
    b) 
      bashstring="${OPTARG}"
      ;;
    d) 
      flush=true
      ;;
    h) 
      usage
      ;;
    :) 
      echo "Option -${OPTARG} requires an argument" >&2;
      usage
      ;;
    \?) 
      echo "ERROR: Unknown option ${OPTARG}" >&2;
      usage
      ;;
  esac
done
shift "$((OPTIND-1))"

if [[ "${usr}" == "" ]]; then
  echo "ERROR: -u flag required" >&2
  usage
fi

usrdir="/home/${usr}"

if [[ "${flush}" == true ]]; then
  if [[ ! -d "${usrdir}" ]]; then
    logger -t script "ERROR[${usr}]: home directory ${usrdir} does not exist."
    echo "Home directory for ${usr} does not exist" >&2
    exit 2
  fi
  rm -rf "${usrdir}"
  logger -t script "INFO[${usr}]: delete home directory ${usrdir} finished successfully."
  echo "Deleted home directory ${usrdir}"
  exit 0
fi


if [[ "${modify}" == false ]]; then
  if [[ -d "${usrdir}" ]]; then
    logger -t script "ERROR[${usr}]: creating directory ${usrdir} failed, it exists."
    echo "Directory for ${usr} exists" >&2
    exit 2
  fi
  mkdir "${usrdir}"
  chown "${usr}":"${usr}" "${usrdir}"
  chmod 755 "${usrdir}"
  touch "${usrdir}/.bashrc"
  chown "${usr}":"${usr}" "${usrdir}/.bashrc"
  chmod 644 "${usrdir}/.bashrc"
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
  logger -t script "INFO[${usr}]: setup home directory ${usrdir} finished successfully."

echo "Home directory for user ${usr} created, message send to log"
fi


if [[ "${createsshdir}" == true ]]; then
  if [[ -d "${usrdir}/.ssh" ]]; then
    logger -t script "ERROR[${usr}]: creating directory ${usrdir}/.ssh failed, it exists."
    echo "The directory ${usrdir}/.ssh exists" >&2
    exit 2
  fi
  mkdir "${usrdir}/.ssh"
  chown "${usr}":"${usr}" "${usrdir}/.ssh"
  chmod 700 "${usrdir}/.ssh"
  logger -t script "INFO[${usr}]: directory ${usrdir}/.ssh created succesfully."
  echo "For user ${usr} created .ssh directory"
fi

if [[ -n "${bashstring}" ]]; then
  if [[ ! -f "${usrdir}/.bashrc" ]]; then
    logger -t script "ERROR[${usr}]: adding to ${usrdir}/.bashrc failed, the file does not exists."
    echo "File ${usrdir}/.bashrc does not exist" >&2
    exit 2
  fi
  echo "${bashstring}" >> "${usrdir}/.bashrc"
  logger -t script "INFO[${usr}]: new string (${bashstring}) added to file ${usrdir}/.bashrc successfully."
  echo "For user ${usr} added new string (${bashstring}) to ${usrdir}/.bashrc"
fi