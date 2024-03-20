#!/usr/bin/bash
msg(){
    echo "===================================="
    echo "$*"
    echo "===================================="
}

workdir="$GITHUB_WORKSPACE"

free
df -h

msg "Updating container..."
pacman -Syu --noconfirm

echo $workdir

ls

