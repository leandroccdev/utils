#!/usr/bin/bash
# Vim config
#<
#   Use the following configs to edit this file at vim
# set autoindent
# set tabstop=4
# set shiftwidth=4
# set expandtab
# set encoding=utf-8
# set foldmethod=marker
# set foldmarker=#<,#>
# set syntax on
# set filetype=sh
# set nowrap
#>
#
# Description
#   Search for specific message from teacher (BASTIAN LANDSKRON.*XX:XX.*XX:XX). Then
#   a cut is made with ffmpeg in order to extract just the class video.
#   It must be used after class data was downloaded.
#
# Development OS: Arch 6.14.10
#
# Usage
#   cut-class.sh clasx-XXX
#   Note: class-XXX is a folder

# Functions
# -----------------------------------------------------------------------------
#<
function install_if_not_exists {
    if [[ -z $(command -v "${1}") ]]; then
        echo "Installing '${1}'..."
        sudo $2 -S $1
    fi
}
#>
# -----------------------------------------------------------------------------

# Install all necessary packages
#<
install_if_not_exists "grep" "pacman"
install_if_not_exists "awk" "pacman"
install_if_not_exists "ffmpeg" "pacman"
#>

[[ ! -d $1 ]] && echo "[Error] '$1' not found!" && exit 1;

chat_str="${1}/class.str"
vclass="${1}/class.webm"
vout="${1}/class_only.webm"

[[ ! -f $chat_str ]] && echo "[Error] '$chat_str' not found!" && exit 1;
[[ ! -f $vclass ]] && echo "[Error] '$vclass' not found!" && exit 1;

cut_at=$(grep -E 'BASTIAN LANDSKRON:.*[0-9]{1,2}:[0-9]{2}.*[0-9]{1,2}:[0-9]{2}' \
-B 1 "$chat_str" | awk 'NR == 1 { split($1, t, ","); print t[1] }')

# Cut not found
[[ -z "$cut_at" ]] && echo "[Error] Cut point not found!" && exit 1;

ffmpeg -loglevel quiet -i $vclass -to $cut_at -c copy $vout
