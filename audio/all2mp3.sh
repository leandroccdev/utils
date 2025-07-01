#!/usr/bin/bash
# Vim config
#<
# Use the following configs to edit this file at vim
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
#    Convert all files to mp3 using ffmpeg at current directory
#
# Development OS: Arch 6.14.10

# Functions
# -----------------------------------------------------------------------------
# $1: command
# $2: packages gestor
function install_if_not_exists {
    if [[ -z $(command -v "${1}") ]]; then
        echo "Installing '${1}'..."
        sudo $2 -S $1
    fi
}

# $1: File to convert
function convert2mp3 {
#<
    a_in=$1 # Audio de entrada
    a_out="${1%.*}.mp3" # Audio de salida
    if [[ ! -f "$a_out" ]]; then
        echo "[Info] Output file: '${a_out}'"
        ffmpeg -loglevel quiet -i "$a_in" -c:v copy -c:a libmp3lame -q:a 6 "$a_out" 2>&1 > /dev/null
        rm "$a_in"
        echo "[info] File '$a_in' deleted!"
    else
        echo "[Info] File '${a_out}' already exists!"
    fi
#>
}
# -----------------------------------------------------------------------------

# Install all necessary packages
#<
install_if_not_exists "ffmpeg" "pacman"
#>

#<
# This isn't gonna work for \n at file names
shopt -s extglob
audio_files_count=$($(ls -c *.+(m4a|wav|flac|ogg|aac) 2>/dev/null) | wc -l)
[[ !$audio_files_count -gt 0 ]] && echo "[Info] No processable files were found!" && exit 0;

for audio_file in *.+(m4a|wav|flac|ogg|aac); do
    convert2mp3 "$audio_file"
done
shopt -u extglob
#>
