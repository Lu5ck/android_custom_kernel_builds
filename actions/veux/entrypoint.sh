#!/usr/bin/bash
msg(){
    echo
    echo "==> $*"
    echo
}

free
df -h

msg "Updating container..."
pacman -Syu --noconfirm > /dev/null 2>&1

msg "Installing prerequisites..."
pacman -S --noconfirm curl wget git make zip tar binutils gcc flex bison bc inetutils coreutils > /dev/null 2>&1

cd source
workdir=$(pwd)

if [ -d "drivers/kernelsu" ]; then
    msg "Removing imported KSU"
    rm -rf "drivers/kernelsu"
fi

msg "Get latest KSU"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main

cd $workdir

msg "Grant executable right to builtin script"
chmod +x build_kernel.sh

msg "Running Builtin script"
./build_kernel.sh

msg "Getting output file"
outputfile="$(realpath "$(ls -d Rashoumon_veux_ksu_*)")"
echo "outputfile=$outputfile" >> $GITHUB_OUTPUT
