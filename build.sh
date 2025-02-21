#!/usr/bin/env bash

#
# Copyright (C) 2022-2024 Kneba <abenkenary3@gmail.com>
#

# Main
MainPath="$(pwd)"
MainClangPath="${MainPath}/clang"
ClangPath="${MainClangPath}"
MainGCCaPath="${MainPath}/GCC64"
MainGCCbPath="${MainPath}/GCC32"
GCCaPath="${MainGCCaPath}"
GCCbPath="${MainGCCbPath}"

# Identity
CODENAME=markw
KERNELNAME=Melon
VARIANT=HMP
VERSION=EOL
KVERSION=4.9-337

# Show manufacturer info
MANUFACTURERINFO="ASUSTek Computer Inc."

# Clone Kernel Source
git clone --depth=1 --recursive https://$USERNAME:$TOKEN@github.com/mozzaru/android_kernel_xiaomi_markw_new -b 15 kernel

# Clone Snapdragon Clang
ClangPath=${MainClangPath}
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
mkdir $ClangPath
rm -rf $ClangPath/*
msg "|| Cloning sdclang toolchain ||"
git clone --depth=1 https://github.com/RyuujiX/SDClang -b 14 $ClangPath

# Clone GCC
mkdir $GCCaPath
mkdir $GCCbPath

msg "|| Cloning GCC toolchain ||"
git clone --depth=1 https://github.com/Kneba/aarch64-linux-android-4.9 $GCCaPath
git clone --depth=1 https://github.com/Kneba/arm-linux-androideabi-4.9 $GCCbPath

# Prepared
KERNEL_ROOTDIR=$(pwd)/kernel # IMPORTANT ! Fill with your kernel source root directory.
export KBUILD_BUILD_USER=queen # Change with your own name or else.
export KBUILD_BUILD_HOST=fedora-rawhide # Change with your host name.
IMAGE=$(pwd)/kernel/out/arch/arm64/boot/Image.gz-dtb
CLANG_VER="Qualcomm® Snapdragon™ clang version 14.1.5"
#LLD_VER="$("$ClangPath"/bin/ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING="$CLANG_VER"
ClangMoreStrings="AR=llvm-ar NM=llvm-nm AS=llvm-as STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf HOSTAR=llvm-ar HOSTAS=llvm-as LD_LIBRARY_PATH=$ClangPath/lib LD=ld.lld HOSTLD=ld.lld"
export TZ=Asia/Jakarta
DATE=$(date +"%Y%m%d")
DATE2=$(date +"%Y%m%d"-%H%M)
START=$(date +"%s")

# Java
command -v java > /dev/null 2>&1

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

# Telegram messaging
tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="$1"
}
# Compiler
compile(){
cd ${KERNEL_ROOTDIR}
msg "|| Cooking kernel. . . ||"
export HASH_HEAD=$(git rev-parse --short HEAD)
export COMMIT_HEAD=$(git log --oneline -1)
export TZ=Asia/Jakarta
make -j$(nproc) O=out ARCH=arm64 markw_defconfig
make -j$(nproc) ARCH=arm64 SUBARCH=arm64 O=out \
    PATH=$ClangPath/bin:$GCCaPath/bin:$GCCbPath/bin:/usr/bin:${PATH} \
    CC=clang \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    HOSTCC=gcc \
    HOSTCXX=g++ ${ClangMoreStrings}

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

   msg "|| Cloning AnyKernel ||"
   git clone --depth=1 https://github.com/mozzaru/AnyKernel-ksu -b hmp-old AnyKernel
   cp $IMAGE AnyKernel
}

# Push kernel to telegram
function push() {
    cd AnyKernel
    curl -F document="@$ZIP_FINAL.zip" "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="🔐<b>Build Done</b>
        - <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s)... </code>

        <b>📅 Build Date: </b>
        -<code>$DATE</code>

         <b>💿 Compiler: </b>
        -<code>$KBUILD_COMPILER_STRING</code>

        <b>📱 Device: </b>
        -<code>$DEVICE_CODENAME($MANUFACTURERINFO)</code>

        <b>🆑 Changelog: </b>
        - <code>$COMMIT_HEAD</code>
        <b></b>
        #$KERNELNAME #$CODENAME #$VARIANT"
}

# Find Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="❌ Tetap menyerah...Pasti bisa!!!"
    exit 1
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
	cp -af $KERNEL_ROOTDIR/init.$CODENAME.Spectrum.rc spectrum/init.spectrum.rc && sed -i "s/persist.spectrum.kernel.*/persist.spectrum.kernel TheOneMemory/g" spectrum/init.spectrum.rc
	cp -af $KERNEL_ROOTDIR/changelog META-INF/com/google/android/aroma/changelog.txt
	cp -af anykernel-real.sh anykernel.sh
	sed -i "s/kernel.string=.*/kernel.string=$KERNELNAME/g" anykernel.sh
	sed -i "s/kernel.type=.*/kernel.type=$VARIANT/g" anykernel.sh
	sed -i "s/kernel.for=.*/kernel.for=$CODENAME/g" anykernel.sh
	sed -i "s/kernel.compiler=.*/kernel.compiler=$KBUILD_COMPILER_STRING/g" anykernel.sh
	sed -i "s/kernel.made=.*/kernel.made=dotkit @queenserenade/g" anykernel.sh
	sed -i "s/kernel.version=.*/kernel.version=$KVERSION/g" anykernel.sh
	sed -i "s/message.word=.*/message.word=Appreciate your efforts for choosing TheOneMemory kernel./g" anykernel.sh
	sed -i "s/build.date=.*/build.date=$DATE/g" anykernel.sh
	sed -i "s/build.type=.*/build.type=$VERSION/g" anykernel.sh
	sed -i "s/supported.versions=.*/supported.versions=9-13/g" anykernel.sh
	sed -i "s/device.name1=.*/device.name1=markw/g" anykernel.sh
	sed -i "s/device.name2=.*/device.name2=markw/g" anykernel.sh
	sed -i "s/device.name3=.*/device.name3=Redmi 4 Prime (markw)/g" anykernel.sh
	sed -i "s/device.name4=.*/device.name4=xiaomi_markw/g" anykernel.sh
	sed -i "s/device.name5=.*/device.name5=xiaomi_markw/g" anykernel.sh
	sed -i "s/markw=.*/markw=1/g" anykernel.sh
	cd META-INF/com/google/android
	sed -i "s/KNAME/$KERNELNAME/g" aroma-config
	sed -i "s/KVER/$KVERSION/g" aroma-config
	sed -i "s/KAUTHOR/dotkit @quuenserenade/g" aroma-config
	sed -i "s/KDEVICE/Redmi 4 Prime/g" aroma-config
	sed -i "s/KBDATE/$DATE/g" aroma-config
	sed -i "s/KVARIANT/$VARIANT/g" aroma-config
	cd ../../../..

	zip -r9 $KERNELNAME-$VARIANT-$VERSION-"$DATE2" * -x .git README.md anykernel-real.sh .gitignore zipsigner* "*.zip"

	ZIP_FINAL="$KERNELNAME-$VARIANT-$VERSION-$DATE2"

	msg "|| Signing Zip ||"
	tg_post_msg "<code>🔑 Signing Zip file with AOSP keys..</code>"

	curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
	java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
	ZIP_FINAL="$ZIP_FINAL-signed"
	cd ..
}

compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
