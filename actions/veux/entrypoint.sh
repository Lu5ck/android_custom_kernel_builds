#!/usr/bin/bash
msg(){
    echo "===================================="
    echo "$*"
    echo "===================================="
}

workdir="$GITHUB_WORKSPACE"

free
df -h

echo "Updating container..."
pacman -Syu --noconfirm

ls

