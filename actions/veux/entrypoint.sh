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
pacman -S --noconfirm curl wget git make zip tar binutils gcc flex bison bc inetutils diffutils > /dev/null 2>&1

cd source
workdir=$(pwd)
config_file="$workdir/arch/arm64/configs/veux_defconfig"

if [ -d "drivers/kernelsu" ]; then
    msg "Removing imported KSU"
    rm -rf "drivers/kernelsu"
fi

msg "Disable KSU flag, if any"
sed -i '/^CONFIG_KSU=/d' "$config_file"

sed -i 's/^kernel\.string=.*/kernel.string=Rashoumon Kernel/' $workdir/AnyKernel3/anykernel.sh

msg "Grant executable right to builtin script"
chmod +x build_kernel.sh

msg "Run Builtin compile script"
./build_kernel.sh

msg "Getting output file"
zip_file=$(find $workdir/AnyKernel3 -maxdepth 1 -type f -name "Rashoumon_veux_*" -print -quit)
rm -f $zip_file
cp -r $workdir/AnyKernel3 $workdir/AnyKernel3-NoKSU

msg "Cleaning up"
rm -f $workdir/AnyKernel3/Image
rm -f $workdir/AnyKernel3/dtb

cd $workdir
if [ -d "out" ]; then
    msg "Removing out folder"
    rm -rf "out"
fi

msg "Enable KSU flag"
if grep -q "^CONFIG_KSU=n$" "$config_file"; then
    sed -i 's/^CONFIG_KSU=n$/CONFIG_KSU=y/' "$config_file"
elif grep -q "^CONFIG_KSU=y$" "$config_file"; then
    :
else
    echo "CONFIG_KSU=y" >> "$config_file"
fi

msg "Get latest KSU"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main

sed -i 's/^kernel\.string=.*/kernel.string=Rashoumon Kernel with KSU/' $workdir/AnyKernel3/anykernel.sh

msg "Run Builtin compile script"
./build_kernel.sh

msg "Getting output file"
zip_file=$(find $workdir/AnyKernel3 -maxdepth 1 -type f -name "Rashoumon_veux_*" -print -quit)
rm -f $zip_file
