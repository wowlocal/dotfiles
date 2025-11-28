#!/bin/bash
# Preview script for lf file manager

file="$1"
w="$2"
h="$3"

# Check if bat is available, otherwise fall back to cat
if command -v bat &> /dev/null; then
    bat --color=always --style=numbers --line-range=:500 --terminal-width="$w" "$file"
else
    cat "$file"
fi
