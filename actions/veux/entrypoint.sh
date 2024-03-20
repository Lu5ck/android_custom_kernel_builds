workdir="$GITHUB_WORKSPACE"

free
df -h

msg "Updating container..."
pacman -Syu

ls
