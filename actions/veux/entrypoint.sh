#!/usr/bin/bash
msg(){
    echo "===================================="
    echo "$*"
    echo "===================================="
}

free
df -h

msg "Updating container..."
pacman -Syu --noconfirm

cd source
workdir=pwd

msg "Removing imported KSU, if any"
if [ -d "drivers/kernelsu" ]; then
    rm -rf "drivers/kernelsu"
fi

msg "Get latest KSU"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main

echo $workdir
cd $workdir

msg "Grant executable rights to builtin script"
chmod +x build_kernel.sh

build_kernel.sh
