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

function post_doc {
	curl --progress-bar -F document=@"$1" "$BUILD_URL" \
	-F chat_id="$ID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$2"
}

echo Use deafult configuration [y/n]
echo Default config Clean Build, clean build, resync sources, gapps build and build with ccache
read config

if [ "$config" = "y" ]
then
	CLEANBUILD=1
	CLEANDEVICE=1
	SYNCSOURCE=1
	CCACHE=1
	buildvariant=user
	gapps=1
elif [ "$config" = "n" ]
then
	echo Sync Sources?[y/n]
        read SYNCSOURCE
	echo Clean device sources?[y/n]
        read CLEANDEVICE
	echo Clean Build?[y/n]
	read CLEANBUILD
	echo Build With Gapps?[y/n]
	read gapps
	echo Use Cache?[y/n]
	read CCACHE
	echo Build Variant [user/userdebug/eng]
	read buildvariant
fi

post_msg "<code>Build Triggered For PixysOS</code>"

# Sync Source
if [ $SYNCSOURCE = 1 ] || [ $SYNCSOURCE = "y" ]
then
        post_msg "<code>ReSyncing Source</code>"
        repo init -u https://github.com/PixysOS/manifest.git -b ten
        repo sync -j$( nproc --all)
fi

# Sync Device Sources
if [ $CLEANDEVICE = 1 ] || [ $CLEANDEVICE = "y" ]
then
        post_msg "<code>Cleaning Device Specific Sources</code>"
        rm -rf device/xiaomi/violet
        rm -rf kernel/xiaomi/sm6150
        rm -rf vendor/xiaomi
        post_msg "<code>Cloning Repo</code>"
        git clone https://github.com/pixysos-devices/device_xiaomi_violet -b ten device/xiaomi/violet
        git clone https://github.com/pixysos-devices/vendor_xiaomi_violet -b ten vendor/xiaomi/violet
        git clone https://github.com/pixysos-devices/kernel_xiaomi_sm6150 -b ten kernel/xiaomi/sm6150 --depth=1
fi

## Clean Build
if [ $CLEANBUILD = 1 ] || [ $CLEANBUILD = "y" ]
then
	post_msg "<code>Cleaning Sources</code>"
	make clean && make clean
fi

# GApps
if [ $gapps = 1 ] || [ "$gapps" = "y" ]
then
	post_msg "<code>Building with Gapps</code>"
	export BUILD_WITH_GAPPS=true
else
	post_msg "<code>Building Non gapps build</code>"
	export BUILD_WITH_GAPPS=false
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
rm -rf out/target/product/violet/Pixys*
echo lunch pixys_violet-$buildvariant
lunch pixys_violet-$buildvariant
mka pixys | tee log

BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

if [ -f out/target/product/violet/Pixys*.zip ]
then	
	post_msg "<code>Build Completed in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</code>"
	
	# Upload Build
	post_msg "<code>Uploading build to private Gdrive</code>"
	rclone copy out/target/product/violet/P*.zip tesla:violet/pixys/$(date +%Y%m%d)/
	ls out/target/product/violet/P*.zip > tmp
	FILE=$(sed 's/^.\{,26\}//' tmp)
	rm tmp
	LINK="https://downloads.tesla59.workers.dev/violet/pixys/$(date +%Y%m%d)/$FILE"
	post_msg "$LINK"

	# Die
	post_msg "<code>that wll be 10$. Payment only via Tikshla Coins</code>"
else
	cat log | grep -i failed -A5 > error.log
	post_doc "error.log" "Build Failed After $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	post_msg "@tesla59  FEEX EET ASAAAP"
fi
