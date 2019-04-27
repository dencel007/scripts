#!/usr/bin/env bash
export TZ="Asia/Kolkata";

# make more room in the environment
# sudo rm -rf ~/.rbenv ~/.phpbrew

# predefined variables - https://semaphoreci.com/docs/available-environment-variables.html
cd $SEMAPHORE_PROJECT_DIR

echo -e "\n\033[0;30m##################################################"
echo -e "\033[0;92m### semaphore ci v1.0 - kernel building script ###"
echo -e "\033[0;30m##################################################\033[0m\n"

# identify git branchname
if [[ $BRANCH_NAME == *clang* || "$*" == *"-clang"* ]]; then
  export GITBRANCH=clang
  echo -e "\033[0;91m> current git branch = CLANG \033[0m\n"
elif [[ $BRANCH_NAME == *dtc* || "$*" == *"-dtc"* ]]; then
  export GITBRANCH=dtc
  echo -e "\033[0;91m> current git branch = DTC CLANG \033[0m\n"
elif [[ $BRANCH_NAME == *miui* ]]; then
  export GITBRANCH=miui
  echo -e "\033[0;91m> current git branch = MIUI \033[0m\n"
else
  export GITBRANCH=aosp
  echo -e "\033[0;91m> current git branch = AOSP \033[0m\n"
fi

# identify os type
if [[ $BRANCH_NAME == *miui* ]]; then
  export OSTYPE=MIUI
  echo -e "\033[0;91m> building for = MIUI \033[0m\n"
else
  export OSTYPE=AOSP
  echo -e "\033[0;91m> building for = AOSP \033[0m\n"
fi

# identify os version
if [[ $BRANCH_NAME == *pie* || $BRANCH_NAME == *p9x* ]]; then
  export OSVERSION=P
  echo -e "\033[0;91m> building for android = P \033[0m\n"
elif [[ $BRANCH_NAME == *oreo* || $BRANCH_NAME == *o8x* ]]; then
  export OSVERSION=O
  echo -e "\033[0;91m> building for android = O \033[0m\n"
elif [[ $BRANCH_NAME == *miui* ]]; then
  export OSVERSION=N
  echo -e "\033[0;91m> building for android = N \033[0m\n"
fi

# identify branch is whether treble or not
if grep -q by-name/cust "arch/arm/boot/dts/qcom/msm8937.dtsi"; then
  export MAKETYPE=treble
  echo -e "\033[0;91m> make type = treble \033[0m\n"
else
  export MAKETYPE=non-treble
  echo -e "\033[0;91m> make type = non-treble \033[0m\n"
fi

# most of the code below this line are applicable for all kernel builds, except, anykernel clone is again santoni specific
export KERNEL_WORKING_DIR=$(dirname "$(pwd)")

# directories - read n' understand the paths, u dumbass !
export GCCDIR=${HOME}/gcc-host-linux-x86
export CLANGDIR=${HOME}/clang-host-linux-x86

export ZIP_DIR=${SEMAPHORE_PROJECT_DIR}/AnyKernel2
export OUT_DIR=${SEMAPHORE_PROJECT_DIR}/out

# zip related stuff
export ZIP_NAME="${KERNEL_NAME}.${OSTYPE}.${OSVERSION}.$(date +%d%m%Y.%H%M).zip";
export FINAL_NAME="${KERNEL_NAME}.${OSTYPE}.${OSVERSION}"; 
export FINAL_ZIP=$ZIP_DIR/${ZIP_NAME}
export IMAGE_OUT=$OUT_DIR/arch/arm64/boot/Image.gz-dtb

# misc
export MAKE="make O=${OUT_DIR}";

# Want to use a different toolchain? (Linaro, UberTC, etc) - @bitrvmpd
# ==================================
# point CROSS_COMPILE to the folder of the desired toolchain
# don't forget to specify the prefix. Mine is: aarch64-linux-android-

export CROSS_COMPILEK=$HOME/gcc-host-linux-x86/bin/aarch64-linux-gnu-

# functions - @infinity-plus
function sendlog {
	RESULT=$(curl -sf --data-binary @"${1:--}" https://del.dog/documents) ||
	{
        echo "ERROR: failed to post document" >&2
        exit 1
    }
        KEY=$(jq -r .key <<< "${RESULT}")
        url="https://del.dog/${KEY}"
	curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="Build failed, "$1" "$url" " -d chat_id=$CHAT_ID
}
function transfer() {
	zipname="$(echo $1 | awk -F '/' '{print $NF}')";
	url="$(curl -# -T $1 https://transfer.sh)";
	echo -e "\n\033[0;35m>Download ${zipname} at ${url} \033[0;0m\n";
}

# build environment setup - fcuk, i won't credit this to anyone !
# sudo apt-get install -y build-essential libncurses5-dev bzip2 bc ccache git-core
install-package jq ccache bc libncurses5-dev git-core gnupg flex bison gperf build-essential zip curl libc6-dev ncurses-dev

if [[ "$*" == *"-gcc8"* ]]; then
  git clone https://github.com/RaphielGang/aarch64-linux-gnu-8.x $HOME/gcc-host-linux-x86 --depth=1
elif [[ "$*" == *"-gcc9"* ]]; then
  git clone https://github.com/VRanger/aarch64-linux-gnu/ -b gnu-9.x $HOME/gcc-host-linux-x86 --depth=1
elif [[ "$*" == *"-linaro7"* ]]; then
  git clone https://github.com/teamfirangi/linaro-7.3 $HOME/gcc-host-linux-x86 --depth=1
else
  git clone https://github.com/ryan-andri/aarch64-linaro-linux-gnu-4.9 $HOME/gcc-host-linux-x86 --depth=1
fi

# get GCC version - @infinity-plus
export GCCVERSION=$($GCCDIR/bin/*-gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
echo -e "\033[0;31m\n$GCCVERSION ready to compile ! \033[0;0m\n"

# get google clang toolchain
if [[ $GITBRANCH == dtc ]]; then
  git clone https://github.com/VRanger/dragontc $HOME/clang-host-linux-x86 --depth=1
elif [[ $GITBRANCH == clang ]]; then
	git clone https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5407736 $HOME/clang-host-linux-x86 --depth=1

# get clang version - @infinity-plus
export CLANGVERSION=$($CLANGDIR/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
echo -e "\033[0;31m\n$CLANGVERSION ready to compile ! \033[0;0m\n"
fi

# get anykernel2 for TWRP flashing, got something else ? PM me plox
if [[ $GITBRANCH == miui ]]; then
	rm -rf $ZIP_DIR;
	git clone https://github.com/dencel007/AnyKernel2 -b santoni-modules ${ZIP_DIR} --depth=1
else
	rm -rf $ZIP_DIR;
	git clone https://github.com/dencel007/AnyKernel2 -b santoni-main ${ZIP_DIR} --depth=1
fi

# Prepend ccache into the PATH
echo 'export PATH="/usr/lib/ccache:$PATH"' | tee -a ~/.bashrc

# Source bashrc to test the new PATH
source ~/.bashrc && echo $PATH

export USE_CCACHE=1
ccache -M 6G

# build starts here
cd $SEMAPHORE_PROJECT_DIR

# out directory config - but why ?
# http://bit.ly/2UQv06H - read thoroughly
  rm -rf $OUT_DIR;
	mkdir -p $OUT_DIR;
  $MAKE clean

if [[ $GITBRANCH == miui ]]; then
  echo -e "\033[0;35m> making modules for miui \033[0;0m\n"
  export ARCH=arm64 
  export CROSS_COMPILE=$HOME/gcc-host-linux-x86/bin/aarch64-linux-gnu-
  make O=out $DEFCONFIGK ;
  make O=out modules
fi

# make your kernel
if [[ $GITBRANCH == clang ]]; then
  start=$SECONDS
  echo -e "\n\033[0;35m> starting CLANG kernel build with $CLANGVERSION toolchain \033[0;0m\n"
  export ARCH=arm64 
  export SUBARCH=arm64
  make O=out ARCH=arm64 $DEFCONFIGK ;
  PATH="$HOME/clang-host-linux-x86/bin:$HOME/gcc-host-linux-x86/bin:${PATH}"

  make -j$(nproc --all) O=out \
                        ARCH=arm64 \
                        SUBARCH=arm64 \
                        CC=$HOME/clang-host-linux-x86/bin/clang \
                        CLANG_TRIPLE=aarch64-linux-gnu- \
                        CROSS_COMPILE=aarch64-linux-gnu- | tee build-log.txt ;

elif [[ $GITBRANCH == dtc ]]; then
  start=$SECONDS
  echo -e "\n\033[0;35m> starting CLANG kernel build with $CLANGVERSION toolchain \033[0;0m\n"
  export ARCH=arm64 
  export SUBARCH=arm64
  make O=out ARCH=arm64 $DEFCONFIGK ;
  PATH="$HOME/clang-host-linux-x86/bin:$HOME/gcc-host-linux-x86/bin:${PATH}"

  make -j$(nproc --all) O=out \
                        ARCH=arm64 \
                        SUBARCH=arm64 \
                        CC=$HOME/clang-host-linux-x86/bin/clang \
                        CLANG_TRIPLE=aarch64-linux-gnu- \
                        CLANG_LD_PATH=${HOME}/clang-host-linux-x86/clang/lib \
                        LLVM_DIS=${HOME}/clang-host-linux-x86/bin/llvm-dis | tee build-log.txt ;

else
  start=$SECONDS
  echo -e "\033[0;35m> starting AOSP kernel build with $GCCVERSION toolchain \033[0;0m\n"

  export ARCH=arm64 
  export CROSS_COMPILE=$HOME/gcc-host-linux-x86/bin/aarch64-linux-gnu-
  make O=out $DEFCONFIGK ;
  make O=out -j$(nproc --all) | tee build-log.txt ;
fi

# Want custom kernel flags ?
# =========================
# KBUILD_KERNEL_CFLAGS: Here you can set custom compilation
# flags to turn off unwanted warnings, or even set a
# different optimization level.
# To see how it works, check the Makefile ... file,
# line 625 to 628, located in the root dir of this kernel.

# KBUILD_KERNEL_CFLAGS=-Wno-misleading-indentation -Wno-bool-compare -mtune=cortex-a53 -march=armv8-a+crc+simd+crypto -mcpu=cortex-a53 -O2
# KBUILD_KERNEL_CFLAGS=$KBUILD_KERNEL_CFLAGS ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE $MAKE_STATEMENT -j8

if [[ ! -f "${IMAGE_OUT}" ]]; then
    echo -e "\n\033[0;31m> $IMAGE_OUT not FOUND. build failed \033[0;0m\n";
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="Build failed !" -d chat_id=$CHAT_ID
    sendlog "build-log.txt";
    grep -iE 'crash|Crash|CRASH|error|Error|ERROR|fail|Fail|FAIL|fatal|Fatal|FATAL' "build-log.txt" &> "mini_log.txt";
    sendlog "mini_log.txt";
    success=false;
    exit 1;
else
    echo -e "\n\033[0;32m> $IMAGE_OUT FOUND. build successful \033[0;0m\n" ;
    success=true;
fi

# get current kernel makefile version
KERNEL_VERSION=$(head -n3 Makefile | sed -E 's/.*(^\w+\s[=]\s)//g' | xargs | sed -E 's/(\s)/./g')
echo -e "\033[0;36m> packing ${KERNEL_NAME}.${OSTYPE}.${OSVERSION}kernel v$KERNEL_VERSION  \033[0;0m\n"

end=$SECONDS
duration=$(( end - start ))
printf "\033[0;32m> $KERNEL_NAME kernel ci build completed in %dh:%dm:%ds \033[0;0m" $(($duration/3600)) $(($duration%3600/60)) $(($duration%60))
echo -e "\n\n\033[0;35m> ================== now, let's zip it ! ===================\033[0;0m\n"

cd $SEMAPHORE_PROJECT_DIR

# modules directory config
if [[ $GITBRANCH == miui ]]; then
export MODULES_DIR=${SEMAPHORE_PROJECT_DIR}/modules/system/lib/modules
export ZIPMODULES_DIR=${ZIP_DIR}/modules
  if [[ -d $MODULES_DIR ]]; then
    echo -e "\n cleaning old modules folder \n"
    rm -rf $MODULES_DIR
  else
    mkdir -p $MODULES_DIR
    echo -e "\n made new modules folder \n"
  fi
fi

# modules setup starts for miui
if [[ $GITBRANCH == miui ]]; then

  find -name "*.ko" -exec mv {} $MODULES_DIR \;

  sudo chmod -R 755 $MODULES_DIR/*

  "$CROSS_COMPILEK"strip --strip-unneeded $MODULES_DIR/* 2>/dev/null
  "$CROSS_COMPILEK"strip --strip-debug $MODULES_DIR/* 2>/dev/null

  mkdir -p $ZIPMODULES_DIR/system/lib/modules
  sudo chmod -R 755 $ZIPMODULES_DIR/*
  rm -r $ZIPMODULES_DIR/system/lib/modules*.ko
  rm -r $ZIPMODULES_DIR/system/lib/modules/pronto
  cp -f $MODULES_DIR/*.ko $ZIPMODULES_DIR/system/lib/modules
  mkdir -p $ZIPMODULES_DIR/system/lib/modules/pronto
  cp -f $ZIPMODULES_DIR/system/lib/modules/wlan.ko $ZIPMODULES_DIR/system/lib/modules/pronto/pronto_wlan.ko

fi

# make ZIP using anykernel
rm -rf $ZIP_DIR/zImage $ZIP_DIR/*.zip
mv $IMAGE_OUT $ZIP_DIR/zImage
cd $ZIP_DIR
zip -r9 ${FINAL_ZIP} *;
cd -;

# upload zip to transfer.sh
if [ -f "$FINAL_ZIP" ];
then
	echo -e "\n\033[0;32m> $ZIP_NAME can be found at $ZIP_DIR \033[0;0m\n" ;
if [[ ${success} == true ]];
then
    echo -e "\033[0;36m> uploading $ZIP_NAME to https://transfer.sh/ \033[0;0m\n" ;
    transfer "$FINAL_ZIP";

	# verify the toolchain - @infinity-plus
  if [[ $GITBRANCH == clang ]]; then
    export TC_TYPE=$CLANGVERSION
  else
    export TC_TYPE=$((sed '7q;d' out/include/generated/compile.h) | awk '{$1=""; $2=""; print $0}' | cut -d '"' -f 2)
  fi

# final push to telegram
curl -F chat_id=$CHAT_ID -F document=@"$FINAL_ZIP" -F caption="
name : $FINAL_NAME
$url" https://api.telegram.org/bot$BOT_API_KEY/sendDocument

curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="
⚙️ name : $KERNEL_NAME kernel
📕 branch : $BRANCH_NAME
🔰 linux-version : $KERNEL_VERSION
🕐 build-time : $(($duration%3600/60))m:$(($duration%60))s

toolchain :
$TC_TYPE

last commit :
$(git log --pretty=format:'%h | %s' -1)

" -d chat_id=$CHAT_ID

  curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="CAADBQADuQADLG6EE9HnR-_L0F2YAg" -d chat_id=$CHAT_ID
  rm -rf $ZIP_DIR/$ZIP_NAME
fi
else
	echo -e "\n\033[0;31m> zip creation failed \033[0;0m\n";
fi

echo -e "\n\n \033[0;35m> ======= aye, now go on, flash zip and brick yo device sur =======\033[0;0m\n"