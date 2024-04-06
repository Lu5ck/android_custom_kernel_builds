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
    sed -i '/^source "drivers\/kernelsu\/Kconfig"$/d' drivers/Kconfig
fi

msg "Get latest KSU"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

msg "Enable KSU flag"
if grep -q "^CONFIG_KSU=n$" "$config_file"; then
    sed -i 's/^CONFIG_KSU=n$/CONFIG_KSU=y/' "$config_file"
elif grep -q "^CONFIG_KSU=y$" "$config_file"; then
    :
else
    echo "CONFIG_KSU=y" >> "$config_file"
fi

msg "Downloading toolchain"
mkdir toolchain && (cd toolchain; bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S)

KERNEL_DEFCONFIG="veux_defconfig"
KERNEL_CMDLINE="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=out LLVM=1"
export PATH=$(pwd)/toolchain/bin/:$PATH
export ARCH=arm64
export SUBARCH=arm64
export DISABLE_WRAPPER=1
make $KERNEL_CMDLINE $KERNEL_DEFCONFIG 
make $KERNEL_CMDLINE -j$(nproc --all)

msg "Preparing AnyKernel3"
cd $workdir
mv out/arch/arm64/boot/dts/vendor/qcom/blair.dtb "../builder/actions/veux positron/AnyKernel3/dtb" || exit 1
cp out/arch/arm64/boot/Image "../builder/actions/veux positron/AnyKernel3" || exit 1
