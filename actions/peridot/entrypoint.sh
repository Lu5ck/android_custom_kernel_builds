#!/usr/bin/bash
msg(){
    echo
    echo "==> $*"
    echo
}

extract_tarball(){
    echo "Extracting $1 to $2"
    tar xf "$1" -C "$2"
}

free
df -h

msg "Updating container..."
dnf -y upgrade > /dev/null 2>&1

msg "Installing prerequisites..."
dnf -y install curl wget git make zip tar binutils gcc flex bison bc diffutils libxml2 python3 hostname iputils which findutils patch xz zstd glibc-devel elfutils-libelf-devel openssl-devel ncurses-devel dwarves rsync > /dev/null 2>&1

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
wget -q --no-check-certificate https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android16-qpr2-release/clang-r574158.tar.gz -O /tmp/aosp-clang.tar.gz
mkdir -p toolchain
extract_tarball /tmp/aosp-clang.tar.gz toolchain

export PATH=$(pwd)/toolchain/bin/:$PATH
export BUILD_CC="$(pwd)/toolchain/bin/clang"
export ARCH=arm64
export SUBARCH=arm64
export DISABLE_WRAPPER=1
KERNEL_DEFCONFIG="gki_defconfig vendor/peridot_GKI.config vendor/custom.config"
KERNEL_CMDLINE="CFLAGS=-std=gnu17 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=out LLVM=1 LLVM_IAS=1"
make $KERNEL_CMDLINE $KERNEL_DEFCONFIG 
make $KERNEL_CMDLINE -j$(nproc --all)

msg "Preparing AnyKernel3"
cd $workdir
ls out/arch/arm64/boot/
cp out/arch/arm64/boot/Image "../builder/actions/peridot/AnyKernel3" || exit 1
