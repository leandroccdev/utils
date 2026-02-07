#!/bin/bash
# Remove spaces from file names and replace them with underscores

for f in *\ *; do
    if [[ -f "$f" && "$f" == *" "* ]]; then
        echo $"f"
        mv -n "$f" "${f// /_}"
    fi
done
