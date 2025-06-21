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

# Description
#<
#   Automate the download of bigBlueButton meeting. Creates a class video from
#   deskshare.webm video track and webcams.web audio track and a .str subtitles.
#   Creates the following folder structure:
#   output_folder:
#   - webcams.webm (Activated web cams)
#   - deskshare.webm (Desktop shares)
#   - chat.xml (slides_new.xml)
#   - class.str (chat.xml converted into .str movies file)
#   - class.webm (webcams audio + deskshare video)
#>
# Development OS: Arch 6.14.10
# Usage
#   dlclass.sh url output_folder
# url
#   [domain]/playback/presentation/2.3/[id]

# Functions
# -----------------------------------------------------------------------------
#<
# $1: command
# $2: packages gestor
function install_if_not_exists {
    if [[ -z $(command -v "${1}") ]]; then
        echo "Installing '${1}'..."
        sudo $2 -S $1
    fi
}

# $1: file_path
function file_exists {
#<
    if [[ -e $1 ]]; then
        read -p "File '$1' already exists, delete it? y/n: " answer
        answer=$(echo -n $answer | tr '[:upper:]' '[:lower:]')
        if [[ $answer == "y" ]]; then
            echo "'$1' deleted!"
            rm $1
        else
            echo "Abborted"
            exit 1
        fi
    fi
#>
}

# $1: folder_path
function folder_exists {
#<
    if [[ -d "$1" ]]; then
        read -p "Folder '$1' already exists, delete it? y/n: " answer
        answer=$(echo -n $answer | tr '[:upper:]' '[:lower:]')
        if [[ $answer == "y" ]]; then
            echo "Folder '$1' deleted!"
            rm -rf $1
        else
            echo "Abborted
            exit 1"
        fi
    fi
#>
}
#>
# -----------------------------------------------------------------------------

# Install all necessary packages
#<
install_if_not_exists "python" "pacman"
install_if_not_exists "tr" "pacman"
install_if_not_exists "sed" "pacman"
install_if_not_exists "wget" "pacman"
install_if_not_exists "ffmpeg" "pacman"
install_if_not_exists "xmlstarlet" "pacman"
#>

# Sets default output folder
#<
output_folder="out/"
if [[ -n $2 ]]; then
    output_folder="${2}/"
fi
folder_exists $output_folder
#>

# Create output folder
#<
if [[ ! -d $output_folder ]]; then
    echo "Output folder '$output_folder' created!"
    mkdir $output_folder
fi
#>

# Define urls
#<
url=`echo -n $1 | sed 's|presentation/2.3/||' | sed 's/playback/presentation/'`
webcam="${url}/video/webcams.webm"
deskshare="${url}/deskshare/deskshare.webm"
chat="${url}/slides_new.xml"
#>

# Output files
#<
webcam_out="${output_folder}webcam.webm"
deskshare_out="${output_folder}deskshare.webm"
chat_out="${output_folder}chat.xml"
merged_file="${output_folder}class.webm"
chat_subtitles="${output_folder}class.str"
subs_duration=2 # Seconds
#>

# Files already exists?
#<
file_exists $webcam_out
file_exists $deskshare_out
file_exists $chat
#>

# Download files
#<
echo -n "Downloading files..."
wget -q $chat -O $chat_out &
wget -q $webcam -O $webcam_out &
wget -q $deskshare -O $deskshare_out &
wait
echo "done"
#>

# Make class video
#<
echo -n "Generating class video..."
ffmpeg -v quiet -i $webcam_out -i $deskshare_out -map 1:v -map 0:a -c copy $merged_file
echo "'${merged_file}' generated!"
#>

# Generate .srt file
#<
echo -n "Generating .str subs from '${chat_out}'..."
xmlstarlet sel -t -m '//chattimeline' -v '@name' -o '###' -v '@in' -o '###' -v '@message' -n $chat_out \
| python -c '
import re
import sys
from copy import deepcopy
from html import unescape
def in2time(t):
    hh = t//3600
    mm = t//60-t//3600*3600//60
    ss = t-(t//60*60)
    return f"{hh:02d}:{mm:02d}:{ss:02d},000"

subs_duration = int(sys.argv[1])
last_t = 0
_stdin = [l for l in sys.stdin]
for i in range(len(_stdin)):
    l = _stdin[i]

    # Parse message
    l = unescape(l)
    l = l.replace("\n", "")

    # Avoid empty lines
    if len(l) < 3:
        continue

    lparts = l.split("###")
    author = ""
    msg = ""
    if len(lparts) < 3:
        t = deepcopy(last_t) + 1
        msg = lparts[0]
    else:
        t = int(lparts[1])
        last_t = deepcopy(t)
        author = lparts[0]
        msg = lparts[2]

    # Extract links
    m = re.search(r"href=\"(.*?)\"", msg)
    if m:
        href = m.group(1)
        m2 = re.findall(r"(<a\b[^>]*>.*?</a>)", msg)
        to_replace = "".join([e for e in m2])
        msg = msg.replace(to_replace, href)

    # Generate sub entry
    st = f"{in2time(t)} --> {in2time(t + subs_duration)}"
    sub = f"{i}\n{st}\n<font color=yellow>{author}: {msg}</font>\n"
    print(sub)
' $subs_duration > $chat_subtitles
echo "done"
#>
