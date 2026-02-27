#!/usr/bin/bash
msg(){
    echo
    echo "==> $*"
    echo
}

set_config_flag() {
    local flag="$1"
    local file="$2"

    msg "Enabling $flag flag"
    
    if grep -q "^${flag}=n$" "$file"; then
        sed -i "s/^${flag}=n$/${flag}=y/" "$file"
    elif grep -q "^${flag}=y$" "$file"; then
        :  # already enabled
    else
        echo "${flag}=y" >> "$file"
    fi
}

extract_tarball(){
    echo "Extracting $1 to $2"
    tar xf "$1" -C "$2"
}

free
df -h

msg "Updating container..."
pacman -Syu --noconfirm > /dev/null 2>&1

msg "Installing prerequisites..."
pacman -S --noconfirm curl wget git make zip tar binutils gcc flex bison bc inetutils diffutils python3 libxml2-legacy cpio pahole > /dev/null 2>&1

cd source
workdir=$(pwd)
config_file="$workdir/arch/arm64/configs/vendor/custom.config"

if [ -d "drivers/kernelsu" ]; then
    msg "Removing imported KSU"
    rm -rf "drivers/kernelsu"
    sed -i '/^source "drivers\/kernelsu\/Kconfig"$/d' drivers/Kconfig
fi

msg "Get latest KSU"
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/refs/heads/dev_susfs/kernel/setup.sh" | bash -s dev_susfs

msg "Get susfs files"
git clone https://gitlab.com/simonpunk/susfs4ksu.git susfs
ls susfs
cp -r susfs/kernel_patches/include/linux/* include/linux/
cp -r susfs/kernel_patches/fs/* fs/

#set_config_flag CONFIG_KPROBES "$config_file"
#set_config_flag CONFIG_HAVE_KPROBES "$config_file"
#set_config_flag CONFIG_KPROBE_EVENTS "$config_file"
set_config_flag CONFIG_KSU "$config_file"
set_config_flag CONFIG_KSU_SUSFS "$config_file"
set_config_flag CONFIG_KSU_SUSFS_SUS_MOUNT "$config_file"
set_config_flag CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG "$config_file"
set_config_flag CONFIG_KSU_SUSFS_SUS_KSTAT "$config_file"
set_config_flag CONFIG_KSU_SUSFS_SUS_MAP "$config_file"
#set_config_flag CONFIG_KSU_SUSFS_SUS_PATH "$config_file"
set_config_flag CONFIG_KSU_SUSFS_SPOOF_UNAME "$config_file"
#set_config_flag CONFIG_KSU_SUSFS_OPEN_REDIRECT "$config_file"
set_config_flag CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS "$config_file"

msg "Downloading toolchain"
#mkdir toolchain && (cd toolchain; bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S)
#wget -q --no-check-certificate https://github.com/ZyCromerZ/Clang/releases/download/20.0.0git-20250129-release/Clang-20.0.0git-20250129.tar.gz -O /tmp/aosp-clang.tar.gz
wget -q --no-check-certificate https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android16-qpr2-release/clang-r574158.tar.gz -O /tmp/aosp-clang.tar.gz
mkdir -p toolchain
extract_tarball /tmp/aosp-clang.tar.gz toolchain

export PATH=$(pwd)/toolchain/bin/:$PATH
export BUILD_CC="$(pwd)/toolchain/bin/clang"
export ARCH=arm64
export SUBARCH=arm64
export DISABLE_WRAPPER=1
KERNEL_DEFCONFIG="gki_defconfig vendor/pineapple_GKI.config vendor/peridot_GKI.config vendor/custom.config"
KERNEL_CMDLINE="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=out LLVM=1 LLVM_IAS=1"
make $KERNEL_CMDLINE $KERNEL_DEFCONFIG 
make $KERNEL_CMDLINE -j$(nproc --all)

msg "Preparing AnyKernel3"
cd $workdir
ls out/arch/arm64/boot/
cp out/arch/arm64/boot/Image "../builder/actions/peridot/AnyKernel3" || exit 1
