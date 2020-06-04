#!/bin/bash
 # Copyright (c) 2020 Tesla59 <talktonishantsingh.ns@gmail.com>

# Export Your Telegram configs here
# For security concern, dont push your chat ID and token publically
export ID=""
export token=""
export MSG_URL="https://api.telegram.org/bot$token/sendMessage"
export BUILD_URL="https://api.telegram.org/bot$token/sendDocument"

# Function to post messages to telegram
post_msg() {
        curl -s -X POST "$MSG_URL" -d chat_id="$ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
}

# Function to post Docs to telegram
post_doc() {
        curl --progress-bar -F document=@"$1" "$BUILD_URL" \
        -F chat_id="$ID"  \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$2"
}

echo Make Clean Build? [y/n]
read MAKECLEAN
echo Build with dtbo? [y/n]
read MAKEDTBO

# Cleaning Everything
if [ $MAKECLEAN = 1 ] || [ "$MAKECLEAN" = "y" ]
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
git clone https://github.com/tesla59/AnyKernel3 zipper

# Exports
export KBUILD_BUILD_HOST="veronica"
export KBUILD_BUILD_USER="tesla"
export KBUILD_JOBS="$((`grep -c '^processor' /proc/cpuinfo`))"
export ARCH=arm64 && export SUBARCH=arm64

# Here we go
BUILD_START=$(date +"%s")
post_msg "<code>Compilation started</code>"
make O=out ARCH=arm64 vendor/violet-perf_defconfig
make -j$(nproc --all) O=out ARCH=arm64 CC="$(pwd)/clang/clang-r370808/bin/clang" CLANG_TRIPLE="aarch64-linux-gnu-" CROSS_COMPILE="$(pwd)/gcc/bin/aarch64-linux-android-" CROSS_COMPILE_ARM32="$(pwd)/gcc32/bin/arm-linux-androideabi-" | tee full.log

# Building DTBO
if [ $MAKEDTBO = 1 ] || [ "$MAKEDTBO" = "y" ]
then
	post_msg "<code>Building DTBO</code>"
	python2 "scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
	create "out/arch/arm64/boot/dtbo.img" --page_size=4096 "out/arch/arm64/boot/dts/qcom/sm6150-idp-overlay.dtbo"
fi
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

# Refining the kernel
if [ -f out/arch/arm64/boot/Image.gz-dtb ]
then
	cp out/arch/arm64/boot/Image.gz-dtb zipper
	cp out/arch/arm64/boot/dtbo.img zipper
	cd zipper
	zip -r9 hydrakernel-$(TZ=Asia/Kolkata date +'%Y%m%d-%H%M').zip * -x README.md hydrakernel-$(TZ=Asia/Kolkata date +'%Y%m%d-%H%M').zip
	post_doc "hydrakernel-$(TZ=Asia/Kolkata date +'%Y%m%d-%H%M').zip" "<code>Build Completed in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</code>"
	rclone copy hydrakernel-$(TZ=Asia/Kolkata date +'%Y%m%d-%H%M').zip tesla:kernel/violet/$(date +%Y%m%d)/
	post_msg "https://downloads.tesla59.workers.dev/kernel/violet/$(date +%Y%m%d)/hydrakernel-$(TZ=Asia/Kolkata date +'%Y%m%d-%H%M').zip"
else
	post_doc "full.log" "<code>Build failed after %(($DIFF / 60)) mins and %(($DIFF % 60)) Second(s)</code>"
fi
