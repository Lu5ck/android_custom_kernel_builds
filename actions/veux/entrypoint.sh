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

if [ -d "drivers/kernelsu" ]; then
    msg "Removing imported KSU"
    rm -rf "drivers/kernelsu"
fi

msg "Get latest KSU"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main

cd $workdir
config_file="$workdir/arch/arm64/configs/veux_defconfig"

msg "Enable KSU flag"
# Check if the file contains the line "CONFIG_KSU=y"
if grep -q "^CONFIG_KSU=n$" "$config_file"; then
    sed -i 's/^CONFIG_KSU=n$/CONFIG_KSU=y/' "$config_file"
else
    echo "CONFIG_KSU=y" >> "$config_file"
fi

msg "Grant executable right to builtin script"
chmod +x build_kernel.sh

msg "Run Builtin compile script"
./build_kernel.sh

msg "Getting output file"
ksu_zip_file=$(find $workdir/AnyKernel3 -maxdepth 1 -type f -name "Rashoumon_veux_*" -print -quit)
mv $ksu_zip_file $workdir/Rashoumon_ksu_veux.zip
ksu_zip_file=$(find $workdir -maxdepth 1 -type f -name "Rashoumon_ksu_veux*" -print -quit)
echo "ksu_zip_file=$ksu_zip_file" >> $$GITHUB_ENV
echo $ksu_zip_file

msg "Cleaning up"
cd AnyKernel3
rm -y Image
rm -y dtb
cd $workdir
make clean

if [ -d "out" ]; then
    msg "Removing out folder"
    rm -rf "out"
fi

msg "Disable KSU flag"
# Check if the file contains the line "CONFIG_KSU=y"
if grep -q "^CONFIG_KSU=y$" "$config_file"; then
    sed -i 's/^CONFIG_KSU=y$/CONFIG_KSU=n/' "$config_file"
else
    echo "CONFIG_KSU=n" >> "$config_file"
fi

msg "Run Builtin compile script"
./build_kernel.sh

msg "Getting output file"
nonksu_zip_file=$(find $workdir/AnyKernel3 -maxdepth 1 -type f -name "Rashoumon_veux_*" -print -quit)
mv $nonksu_zip_file $workdir/Rashoumon_veux.zip
nonksu_zip_file=$(find $workdir -maxdepth 1 -type f -name "Rashoumon_veux*" -print -quit)
echo "nonksu_zip_file=$nonksu_zip_file" >> $$GITHUB_ENV
echo $nonksu_zip_file
