#!/bin/bash
 # Copyright (c) 2020 Tesla59 <talktonishantsingh.ns@gmail.com>

# Export Your Telegram configs here
# For security concern, dont push your chat ID and token publically
export ID=""
export token=""
export MSG_URL="https://api.telegram.org/bot$token/sendMessage"

# Function to post messages to telegram
function post_msg {
        curl -s -X POST "$MSG_URL" -d chat_id="$ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
}

# Make Clean build or not, default is Yes
MAKECLEAN=1
# Build DTBO or not, default is Yes
MAKEBUILD=1
# Upload build or not
CLEAN=1

post_msg "<code>Started Build</code>"
# Cleaning Everything
if [ $MAKECLEAN = 1 ]
then
	post_msg "<code>Cleaning Stuff</code>"
	make O=out clean
	make O=out mrproper
	rm -rf out zipper
	mkdir out
fi

# Cloning GCC and CLANG
post_msg "<code>Cloning compiler</code>"
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 gcc
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 --depth=1 gcc32
git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 --depth=1 clang
git clone https://android.googlesource.com/platform/system/libufdt scripts/ufdt/libufdt

# Exports
export KBUILD_BUILD_HOST="veronica"
export KBUILD_BUILD_USER="tesla"
export KBUILD_JOBS="$((`grep -c '^processor' /proc/cpuinfo`))"
export ARCH=arm64 && export SUBARCH=arm64

# Here we go
post_msg "<code>Compilation startedf</code>"
make O=out clean
make O=out mrproper
make O=out ARCH=arm64 vendor/violet-perf_defconfig
make -j$(nproc --all) O=out ARCH=arm64 CC="$(pwd)/clang/clang-r370808/bin/clang" CLANG_TRIPLE="aarch64-linux-gnu-" CROSS_COMPILE="$(pwd)/gcc/bin/aarch64-linux-android-" CROSS_COMPILE_ARM32="$(pwd)/gcc32/bin/arm-linux-androideabi-" | tee log.log

# Building DTBO
if [ $MAKEDTBO = 1 ]
then
	post_msg "<code>Building DTBO</code>"
	python2 "scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
	create "out/arch/arm64/boot/dtbo.img" --page_size=4096 "out/arch/arm64/boot/dts/qcom/sm6150-idp-overlay.dtbo"
fi

# Refining the kernel
git clone https://github.com/tesla59/AnyKernel3 zipper
cp out/arch/arm64/boot/Image.gz-dtb zipper
cp out/arch/arm64/boot/dtbo.img zipper
cd zipper
zip -r9 hydrakernel-$(TZ=Asia/Kolkata date +'%Y%m%d-%H%M').zip * -x README.md hydrakernel-$(TZ=Asia/Kolkata date +'%Y%m%d-%H%M').zip

# Uploading to gdrive
if [ $UPLOAD = 1 ]
then
	post_msg "<code>Uploading To Private Gdrive</code>"
	rclone copy hydra*.zip tesla:kernel/violet/$(date +%Y%m%d-%H%M)_01/
fi
