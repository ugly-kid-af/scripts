#!/bin/bash
 # Copyright (c) 2020 Tesla59 <talktonishantsingh.ns@gmail.com>

# Export Your Telegram configs here
# For security concern, dont push your chat ID and token publically
export ID=""
export token=""
export MSG_URL="https://api.telegram.org/bot$token/sendMessage"
export BUILD_URL="https://api.telegram.org/bot$token/sendDocument"

# Function to post messages to telegram
function post_msg {
        curl -s -X POST "$MSG_URL" -d chat_id="$ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
}

echo Use deafult configuration [y/n]
read config

if [ "$config" = "y" ]
then
	CLEANBUILD=1
	CLEANDEVICE=1
	SYNCSOURCE=1
	CCACHE=1
	buildvariant=user
elif [ "$config" = "n" ]
then
	echo Clean Build?[y/n]
	read CLEANBUILD
	echo Clean device sources?[y/n]
	read CLEANDEVICE
	echo Sync Sources?[y/n]
	read SYNCSOURCE
	echo Use Cache?
	read CCACHE
	echo Build Variant [user/userdebug/eng]
	read buildvariant
fi

post_msg "<code>Build Triggered For PixysOS</code>"

if [ $CLEANBUILD = 1 ] || [ $CLEANBUILD = "y" ]
then
	post_msg "<code>Cleaning Sources</code>"
	make clean && make clean
fi

if [ $CLEANDEVICE = 1 ] || [ $CLEANDEVICE = "y" ]
then
	post_msg "<code>Cleaning Device Specific Sources</code>"
	rm -rf device/xiaomi/violet
	rm -rf kernel/xiaomi/sm6150
	rm -rf vendor/xiaomi
	post_msg "<code>Cloning Repo</code>"
	git clone https://github.com/pixysos-devices/device_xiaomi_violet -b ten device/xiaomi/violet
	git clone https://github.com/pixysos-devices/vendor_xiaomi_violet -b ten vendor/xiaomi/violet
	git clone https://github.com/pixysos-devices/kernel_xiaomi_violet -b ten kernel/xiaomi/sm6150
fi

if [ $SYNCSOURCE = 1 ] || [ $SYNCSOURCE = "y" ]
then
	post_msg "<code>ReSyncing Source</code>"
	repo init -u https://github.com/PixysOS/manifest.git -b ten
	repo sync -j$( nproc --all)
fi

# set ccache
if [ $CCACHE = 1 ] || [ $CCACHE = "y" ]
then
	ccache -M 100G
	export USE_CCACHE=1
	export CCACHE_EXEC=/usr/bin/ccache
fi

# Start Compiling
post_msg "<code>Build Started</code>"

BUILD_START=$(date +"%s")

. b*/e*
echo lunch pixys_violet-$buildvariant
lunch pixys_violet-$buildvariant
mka pixys | tee log

BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

post_msg "<code>Build Completed in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</code>"

# Upload Build
post_msg "<code>Uploading build to private Gdrive</code>"
rclone copy out/target/product/violet/P*.zip tesla:violet/pixys/$(date +%Y%m%d)_01/
ls out/target/product/violet/P*.zip > tmp
FILE=$(sed 's/^.\{,26\}//' tmp)
rm tmp
LINK="https://downloads.tesla59.workers.dev/violet/pixys/$(date +%Y%m%d)_01/$FILE"
post_msg "$LINK"