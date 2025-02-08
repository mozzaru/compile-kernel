#!/usr/bin/env bash
#
# Copyright (C) 2023 Kneba <abenkenary3@gmail.com>
#

# Main
MainPath="$(pwd)"
MainClangPath="${MainPath}/clang"
ClangPath="${MainClangPath}"

# Identity
VERSION=9.4-337
KERNELNAME=TheOneMemory
CODENAME=markw
VARIANT=EAS

# Show manufacturer info
MANUFACTURERINFO="Xiaomi.inc."

# Clone Kernel Source
git clone --depth=1 https://$USERNAME:$TOKEN@github.com/mozzaru/android_kernel_xiaomi_markw_new -b 15 kernel

# Clone StRess Clang
ClangPath=${MainClangPath}
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
mkdir $ClangPath
rm -rf $ClangPath/*
msg "|| Cloning Proton clang  ||"
git clone --depth=1 https://github.com/kdrag0n/proton-clang.git $ClangPath

# Prepared
KERNEL_ROOTDIR=$(pwd)/kernel # IMPORTANT ! Fill with your kernel source root directory.
export KBUILD_BUILD_USER=queen # Change with your own name or else.
IMAGE=$(pwd)/kernel/out/arch/arm64/boot/Image.gz-dtb
CLANG_VER="$("$ClangPath"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
LLD_VER="$("$ClangPath"/bin/ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING="$CLANG_VER with $LLD_VER"
DATE=$(date +"%Y-%m-%d")
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
make -j$(nproc) O=out ARCH=arm64 markw_defconfig
make -j$(nproc) ARCH=arm64 SUBARCH=arm64 O=out \
    LD_LIBRARY_PATH="${ClangPath}/lib64:${LD_LIBRARY_PATH}" \
    PATH=$ClangPath/bin:${PATH} \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    CC=clang \
    AR=llvm-ar \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi
   
  git clone https://github.com/mozzaru/AnyKernel-ksu -b hmp-old AnyKernel
	cp $IMAGE AnyKernel
}
# Push kernel to channel
function push() {
    cd AnyKernel
    curl -F document=@"$ZIP_FINAL.zip" "$BOT_BUILD_URL" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Compile took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>$DEVICE_CODENAME</b> | <b>${KBUILD_COMPILER_STRING}</b>"
}
# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="I'm tired of compiling kernels,And I choose to give up...please give me motivation"
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
    sed -i "s/kernel.made=.*/kernel.made=dotkit @fakedotkit/g" anykernel.sh
    sed -i "s/kernel.version=.*/kernel.version=$KERVER/g" anykernel.sh
    sed -i "s/message.word=.*/message.word=Appreciate your efforts for choosing TheOneMemory kernel./g" anykernel.sh
    sed -i "s/build.date=.*/build.date=$DATE/g" anykernel.sh
    sed -i "s/build.type=.*/build.type=$VERSION/g" anykernel.sh
    sed -i "s/supported.versions=.*/supported.versions=9-15/g" anykernel.sh
    sed -i "s/device.name1=.*/device.name1=markw/g" anykernel.sh
    sed -i "s/device.name2=.*/device.name2=markw/g" anykernel.sh
    sed -i "s/device.name3=.*/device.name3=Redmi 4 Prime (markw)/g" anykernel.sh
    sed -i "s/device.name4=.*/device.name4=xiaomi_markw/g" anykernel.sh
    sed -i "s/device.name5=.*/device.name5=xiaomi_markw/g" anykernel.sh
    sed -i "s/markw=.*/markw=1/g" anykernel.sh
    cd META-INF/com/google/android
    sed -i "s/KNAME/$KERNELNAME/g" aroma-config
    sed -i "s/KVER/$KERVER/g" aroma-config
    sed -i "s/KAUTHOR/dotkit @fakedotkit/g" aroma-config
    sed -i "s/KDEVICE/Redmi 4 Prime/g" aroma-config
    sed -i "s/KBDATE/$DATE/g" aroma-config
    sed -i "s/KVARIANT/$VARIANT/g" aroma-config
    cd ../../../..

    zip -r9 $KERNELNAME-$DATE2.zip * -x .git README.md anykernel-real.sh ./*placeholder .gitignore zipsigner*

    ## Prepare a final zip variable
    ZIP_FINAL="$KERNELNAME-$DATE2"

    msg "|| Signing Zip ||"
    tg_post_msg "<code>🔑 Signing Zip file with AOSP keys..</code>"

    curl -sLo zipsigner-3.0-dexed.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
    java -jar zipsigner-3.0-dexed.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
    ZIP_FINAL="$ZIP_FINAL-signed"
    cd ..
}
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
