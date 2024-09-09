#!/bin/bash

#set -e
KERNELDIR=$(pwd)

# Identity
DEVICENAME=X00T/D
CODENAME=Hayzel
KERNELNAME=TOM
VARIANT=HMP
VERSION=CLO

COMMIT_BUILD_URL=https://github.com/Tiktodz/android_kernel_asus_sdm636/commits/tom/hmp/

## Telegram Topic (Default 0 = false)
TG_SUPER=0

BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot$TG_TOKEN/sendDocument"

tg_post_msg(){
        if [ $TG_SUPER = 1 ]
        then
            curl -s -X POST "$BOT_MSG_URL" \
            -d chat_id="$TG_CHAT_ID" \
            -d message_thread_id="$TG_TOPIC_ID" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1"
        else
            curl -s -X POST "$BOT_MSG_URL" \
            -d chat_id="$TG_CHAT_ID" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1"
        fi
}

tg_post_build()
{
	if [ $TG_SUPER = 1 ]
	then
	    curl -F document=@"$1" "$BOT_BUILD_URL" \
	    -F chat_id="$TG_CHAT_ID"  \
	    -F message_thread_id="$TG_TOPIC_ID" \
	    -F "disable_web_page_preview=true" \
	    -F "parse_mode=Markdown" \
	    -F caption="$2"
	else
	    curl -F document=@"$1" "$BOT_BUILD_URL" \
	    -F chat_id="$TG_CHAT_ID"  \
	    -F "disable_web_page_preview=true" \
	    -F "parse_mode=Markdown" \
	    -F caption="$2"
	fi
}

tg_post_msg "<b>`date '+%d %b %Y, %H:%M %Z'`</b>
🔨 Compile kernel <b>$KERNELNAME</b> for <b>$DEVICENAME</b>
💾 Powered by <b>`source /etc/os-release && echo ${NAME}`</b>
🆑 Changelog URL <a href='$COMMIT_BUILD_URL'>Click Here</a>
🙇 Memetainer <b>@queenserenade</b>"

## Cloning toolchain
if ! [ -d "$KERNELDIR/ew" ]; then
mkdir -p $KERNELDIR/ew && cd $KERNELDIR/ew
wget -q https://github.com/Tiktodz/electrowizard-clang/releases/download/ElectroWizard-Clang-18.1.8-release/ElectroWizard-Clang-18.1.8.tar.gz -O "ElectroWizard-Clang-18.1.8.tar.gz"
tar -xf ElectroWizard-Clang-18.1.8.tar.gz
rm -rf ElectroWizard-Clang-18.1.8.tar.gz
cd ..
fi

## Copy this script inside the kernel directory
KERNEL_DEFCONFIG=X00TD_defconfig
DATE=$(date '+%Y%m%d')
FINAL_KERNEL_ZIP="$KERNELNAME-$VARIANT-$VERSION-$(date '+%Y%m%d-%H%M').zip"
KERVER=$(make kernelversion)
export KBUILD_BUILD_TIMESTAMP=$(date)
export PATH="$KERNELDIR/ew/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export LLVM_IAS=1
export KBUILD_BUILD_USER="queen"
export KBUILD_BUILD_HOST=$(source /etc/os-release && echo "${NAME}" | cut -d" " -f1)
export KBUILD_COMPILER_STRING="$($KERNELDIR/ew/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
ClangMoreStrings="AR=llvm-ar NM=llvm-nm AS=llvm-as STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf HOSTAR=llvm-ar HOSTAS=llvm-as LD_LIBRARY_PATH=$KERNELDIR/ew/lib LD=ld.lld HOSTLD=ld.lld"

# Speed up build process
MAKE="./makeparallel"

# Java
command -v java > /dev/null 2>&1

BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

mkdir -p out
make O=out clean

echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
echo -e "$blue***********************************************"
echo "          BUILDING KERNEL          "
echo -e "***********************************************$nocol"
make $KERNEL_DEFCONFIG O=out 2>&1 | tee -a error.log
make -j$(nproc --all) O=out \
	ARCH=$ARCH \
	SUBARCH=$ARCH \
	CC="$KERNELDIR/ew/bin/clang" \
	CROSS_COMPILE=aarch64-linux-gnu- \
	HOSTCC="$KERNELDIR/ew/bin/clang" \
	HOSTCXX="$KERNELDIR/ew/bin/clang++" ${ClangMoreStrings} 2>&1 | tee -a error.log

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

echo "**** Kernel Compilation Completed ****"
echo "**** Verify Image.gz-dtb ****"
if ! [ -f $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb ];then
    tg_post_build "error.log" "Compile Error!!"
    echo "$red Compile Failed!!!$nocol"
    exit 1
fi

# Anykernel3 time!!
echo "**** Verifying AnyKernel3 Directory ****"
if ! [ -d "$KERNELDIR/AnyKernel3" ]; then
  echo "AnyKernel3 not found! Cloning..."
  if ! git clone --depth=1 https://github.com/Tiktodz/AnyKernel3 -b hmp-new AnyKernel3; then
    tg_post_build "$KERNELDIR/out/arch/arm64/boot/Image.gz-dtb" "Failed to Clone Anykernel, Sending image file instead"
    echo "Cloning failed! Aborting..."
    exit 1
  fi
fi

ANYKERNEL3_DIR=$KERNELDIR/AnyKernel3/

# Generating Changelog
echo "<b><#selectbg_g>$(date)</#></b>" > changelog
git log --oneline -n15 | cut -d " " -f 2- | awk '{print "<*> " $(A) "</*>"}' | tee -a changelog

echo "**** Copying Image.gz-dtb ****"
cp $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb $ANYKERNEL3_DIR/

echo "**** Time to zip up! ****"
cd $ANYKERNEL3_DIR/
cp -af $KERNELDIR/init.$CODENAME.Spectrum.rc spectrum/init.spectrum.rc && sed -i "s/persist.spectrum.kernel.*/persist.spectrum.kernel TheOneMemory/g" spectrum/init.spectrum.rc
cp -af $KERNELDIR/changelog META-INF/com/google/android/aroma/changelog.txt
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
sed -i "s/supported.versions=.*/supported.versions=9-13/g" anykernel.sh
sed -i "s/device.name1=.*/device.name1=X00TD/g" anykernel.sh
sed -i "s/device.name2=.*/device.name2=X00T/g" anykernel.sh
sed -i "s/device.name3=.*/device.name3=Zenfone Max Pro M1 (X00TD)/g" anykernel.sh
sed -i "s/device.name4=.*/device.name4=ASUS_X00TD/g" anykernel.sh
sed -i "s/device.name5=.*/device.name5=ASUS_X00T/g" anykernel.sh
sed -i "s/X00TD=.*/X00TD=1/g" anykernel.sh
cd META-INF/com/google/android
sed -i "s/KNAME/$KERNELNAME/g" aroma-config
sed -i "s/KVER/$KERVER/g" aroma-config
sed -i "s/KAUTHOR/dotkit @fakedotkit/g" aroma-config
sed -i "s/KDEVICE/Zenfone Max Pro M1/g" aroma-config
sed -i "s/KBDATE/$DATE/g" aroma-config
sed -i "s/KVARIANT/$VARIANT/g" aroma-config
cd ../../../..

zip -r9 "../$FINAL_KERNEL_ZIP" * -x .git README.md anykernel-real.sh ./*placeholder .gitignore zipsigner* "*.zip"

ZIP_FINAL="$FINAL_KERNEL_ZIP"

cd ..

echo "**** Sign zip with AOSP key ****"
curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
ZIP_FINAL="$ZIP_FINAL-signed"

echo "**** Uploading your zip now ****"
tg_post_build "$ZIP_FINAL.zip" "⏳ *Compile Time*
• $(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds
🐧 *Linux Version*
• ${KERVER}
📀 *Compiler*
• ${KBUILD_COMPILER_STRING}
🆕 *Last commit*
\`\`\`
$(git log --oneline -n5 | cut -d" " -f2- | awk '{print "• " $(A)}')
\`\`\`"
