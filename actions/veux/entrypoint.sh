#!/usr/bin/bash
workdir="$GITHUB_WORKSPACE"

free
df -h

echo "Updating container..."
yes | pacman -Syu

ls

