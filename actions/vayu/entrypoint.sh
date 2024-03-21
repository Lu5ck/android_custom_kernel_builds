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
apt update && apt upgrade -y

msg "Installing prerequisites..."
apt install -y git make bc bison openssl curl zip kmod cpio flex libelf-dev libssl-dev libtfm-dev wget device-tree-compiler ca-certificates python3 python2 xz-utils libgcc-10-dev > /dev/null 2>&1
ln -sf "/usr/bin/python${python_version}" /usr/bin/python

cd source
workdir=$(pwd)
config_file="$workdir/arch/arm64/configs/vayu_user_defconfig"

if [ -d "drivers/kernelsu" ]; then
    msg "Removing imported KSU"
    rm -rf "drivers/kernelsu"
    sed -i '/^source "drivers\/kernelsu\/Kconfig"$/d' drivers/Kconfig
fi

msg "Get latest KSU"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main

msg "Enable KSU flag"
if grep -q "^CONFIG_KSU=n$" "$config_file"; then
    sed -i 's/^CONFIG_KSU=n$/CONFIG_KSU=y/' "$config_file"
elif grep -q "^CONFIG_KSU=y$" "$config_file"; then
    :
else
    echo "CONFIG_KSU=y" >> "$config_file"
fi

msg "Setup toolchain"
downloadurl="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r498229b.tar.gz"
echo "Downloading $downloadurl"
wget -q --no-check-certificate $downloadurl -O /tmp/aosp-clang.tar.gz

downloadurl="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/heads/android12L-release.tar.gz"
echo "Downloading $downloadurl"
wget -q --no-check-certificate $downloadurl -O /tmp/aosp-gcc-arm64.tar.gz

downloadurl="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/heads/android12L-release.tar.gz"
echo "Downloading $downloadurl"
wget -q --no-check-certificate $downloadurl -O /tmp/aosp-gcc-arm.tar.gz

downloadurl="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/+archive/refs/heads/android12L-release.tar.gz"
echo "Downloading $downloadurl"
wget -q --no-check-certificate $downloadurl -O /tmp/aosp-gcc-host.tar.gz

echo "Extracting toolchain"
mkdir -p /aosp-clang /aosp-gcc-arm64 /aosp-gcc-arm /aosp-gcc-host
extract_tarball /tmp/aosp-clang.tar.gz /aosp-clang
extract_tarball /tmp/aosp-gcc-arm64.tar.gz /aosp-gcc-arm64
extract_tarball /tmp/aosp-gcc-arm.tar.gz /aosp-gcc-arm
extract_tarball /tmp/aosp-gcc-host.tar.gz /aosp-gcc-host

echo "Linking toolchain"
for i in /aosp-gcc-host/bin/x86_64-linux-*; do
    ln -sf "$i" "${i/x86_64-linux-}"
done

echo "Setting path to toolchain"
export PATH="/aosp-clang/bin:/aosp-gcc-arm64/bin:/aosp-gcc-arm/bin:/aosp-gcc-host/bin:$PATH"

msg "Building Kernel"
arch_opts="ARCH=arm64 SUBARCH=arm64"
make_opts="CC=clang LD=ld.lld NM=llvm-nm STRIP=llvm-strip OBJCOPY=llvm-objcopy"
make_opts+=" OBJDUMP=llvm-objdump READELF=llvm-readelf LLVM_IAS=1"
host_make_opts="HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld HOSTAR=llvm-ar"
defconfig=vayu_user_defconfig
export ARCH="arm64"
export SUBARCH="arm64"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export CROSS_COMPILE="aarch64-linux-android-"
export CROSS_COMPILE_ARM32="arm-linux-androideabi-"

make O=out $arch_opts $make_opts $host_make_opts "$defconfig"
make O=out $arch_opts $make_opts $host_make_opts -j"$(nproc --all)" prepare
if ! make O=out $arch_opts $make_opts $host_make_opts -j"$(nproc --all)"; then
    err "Failed building kernel, probably the toolchain is not compatible with the kernel, or kernel source problem"
    exit 3
fi

msg "Preparing AnyKernel3"
cd $workdir
cp out/arch/arm64/boot/Image.gz-dtb ../AnyKernel3
