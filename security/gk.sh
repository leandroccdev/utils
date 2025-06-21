#!/usr/bin/bash
# Vim Config
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

# Description
#   Generates random secure passwords based on /dev/urandom
# Development OS: Arch 6.14.10

allowed_sets="[:alnum:][:alpha:][:digit:][:graph:]" 
min_k_len=4
min_elements=4

# Functions
# ------------------------------------------------------------------------------
# $1: command
# $2: packages gestor
function install_if_not_exists {
#<
    if [[ -z $(command -v "${1}") ]]; then
        echo "Installing '${1}'..."
        sudo $2 -S $1
    fi
#>
}
function show_allowed_sets {
#<
    echo "tr allowed sets:"
    echo -n $allowed_sets | sed -E 's/\[:/-  /g; s/:\]/\n/g'
    exit 0
#>
}
function show_help {
#<
    echo -e "Simple password generator
    Generates random secure password with /dev/urandom as input.
Usage:
    gk [tr set][length][number]   Generate password elements
    gk -h                         Shows help
Defaults:
    tr set: alnum
    length: ${min_k_len} chars
    number: 4 elements
tr allowed sets:
"
    show_allowed_sets
#>
}
# $1: tr set without the brackets and colon. (default: alnum)
# $2: key's length (default: $min_k_len chars; min: chars)
# $3: generated keys number (default: $min_elements elements)
function gk {
#<
    # Allowed sets validation
    [[ ! $allowed_sets == *"${1}"* ]] && echo "[Error] Set '$1' not allowed" \
        && show_allowed_sets && exit 1;
    # Format set
    tr_set="[:$1:]"

    # Key length validation
    k_len=$min_k_len # default
    [[ -n $2 && $2 -lt $k_len ]] && \
        echo "[Error] Key must be at least ${k_len} chars length!" && exit 1;
    [[ -n $2 && $2 -gt $k_len ]] && k_len=$2;

    # Generated keys number validation
    [[ -n $3 && $3 -lt 1 ]] && echo "[Error] You must generate at least one element!" \
        && exit 1;
    to_generate=$min_elements # default
    [[ -n $3 && $3 -gt 0 ]] && to_generate=$3;

    # Generate
    function p_generate {
        echo -n $(< /dev/urandom tr -cd "$tr_set" | head -c $k_len)
    }
    echo "Passwords:"
    for (( i=0; i<$to_generate; i++ )) do echo "- $(p_generate)"; done
#>
}
# ------------------------------------------------------------------------------

# Install all necessary packages
#<
install_if_not_exists "pacman" "tr"
install_if_not_exists "pacman" "sed"
#>

# Main menu
case $1 in
    "-h") show_help;;
    *) gk $*;;
esac
