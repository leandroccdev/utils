#!/usr/bin/bash
#
# Description
#     Extracts the audio track from all mp4 video files in M4A format.

# $1: MP4 video file
function extractsAudioTrack {
    v_in=$1 # MP4 video file
    a_out="${1%.*}.m4a" # M4A audio file
    if [[ ! -f "$a_out" ]] ; then
        echo "[Info] Output file: '$a_out'"
        ffmpeg -loglevel quiet -i "$v_in" -vn -acodec copy "$a_out" 2>&1 > /dev/null
        rm "$v_in"
        echo "[Info] File '$v_in' deleted!"
    else
        echo "[Info] File '$a_out' already exists!"
    fi
}

for video_file in *.mp4; do
    extractsAudioTrack "$video_file"
done
