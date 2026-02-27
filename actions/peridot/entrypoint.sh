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
pacman -S --noconfirm curl wget git make zip tar binutils gcc flex bison bc inetutils diffutils libxml2-legacy python3 > /dev/null 2>&1

cd source
workdir=$(pwd)
config_file="$workdir/arch/arm64/configs/gki_defconfig"

if [ -d "drivers/kernelsu" ]; then
    msg "Removing imported KSU"
    rm -rf "drivers/kernelsu"
    sed -i '/^source "drivers\/kernelsu\/Kconfig"$/d' drivers/Kconfig
fi

msg "Get latest KSU"
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/refs/heads/next-susfs-a14-6.1-dev/kernel/setup.sh" | bash -

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


export PATH=$(pwd)/toolchain/bin/:$PATH
export BUILD_CC="$(pwd)/toolchain/neutron-clang/bin/clang"
export ARCH=arm64
export SUBARCH=arm64
export DISABLE_WRAPPER=1
KERNEL_DEFCONFIG="gki_defconfig vendor/peridot_GKI.config vendor/custom.config"
KERNEL_CMDLINE="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=out LLVM=1 LLVM_IAS=1 \
AR=$(pwd)/toolchain/neutron-clang/bin/llvm-ar \
NM=$(pwd)/toolchain/neutron-clang/bin/llvm-nm \
LD=$(pwd)/toolchain/neutron-clang/bin/ld.lld \
STRIP=$(pwd)/toolchain/neutron-clang/bin/llvm-strip \
OBJCOPY=$(pwd)/toolchain/neutron-clang/bin/llvm-objcopy \
OBJDUMP=$(pwd)/toolchain/neutron-clang/bin/llvm-objdump \
READELF=$(pwd)/toolchain/neutron-clang/bin/llvm-readelf \
HOSTCC=$(pwd)/toolchain/neutron-clang/bin/clang \
HOSTCXX=$(pwd)/toolchain/neutron-clang/bin/clang++"
make $KERNEL_CMDLINE $KERNEL_DEFCONFIG 
make $KERNEL_CMDLINE -j$(nproc --all)

msg "Preparing AnyKernel3"
cd $workdir
ls out/arch/arm64/boot/
cp out/arch/arm64/boot/Image "../builder/actions/peridot/AnyKernel3" || exit 1
