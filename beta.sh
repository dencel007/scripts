#!/usr/bin/env bash

# set your timezone here
export TZ="Asia/Kolkata"

# helpdesk
# =========
# predefined variables - https://semaphoreci.com/docs/available-environment-variables.html
# $SEMAPHORE_PROJECT_DIR = /home/runner/git-repo-name-here
# $KERNEL_WORKING_DIR = /home/runner

# make more room in the environment
# sudo rm -rf ~/.rbenv ~/.phpbrew

cd "$SEMAPHORE_PROJECT_DIR"

echo -e "\n\033[0;30m##################################################"
echo -e "\033[0;92m### semaphore ci v1.0 - kernel building script ###"
echo -e "\033[0;30m##################################################\033[0m\n"

# identify git branchname

if [[ $BRANCH_NAME == *clang* || "$*" == *"-clang"* ]]
then
  export GITBRANCH=clang
  echo -e "\033[0;91m> git branch = CLANG \033[0m\n"
elif [[ $BRANCH_NAME == *dtc* || "$*" == *"-dtc"* ]]
then
  export GITBRANCH=dtc
  echo -e "\033[0;91m> git branch = DTC CLANG \033[0m\n"
elif [[ $BRANCH_NAME == *miui* ]]
then
  export GITBRANCH=miui
  echo -e "\033[0;91m> git branch = MIUI \033[0m\n"
else
  export GITBRANCH=aosp
  echo -e "\033[0;91m> git branch = AOSP \033[0m\n"
fi

# identify os type and version

export OSTYPE=AOSP
if [[ $BRANCH_NAME == *pie* || $BRANCH_NAME == *p9x* ]]
then
  export OSVERSION=P
  echo -e "\033[0;91m> android version = P \033[0m\n"
elif [[ $BRANCH_NAME == *oreo* || $BRANCH_NAME == *o8x* ]]
then
  export OSVERSION=O
  echo -e "\033[0;91m> android version = O \033[0m\n"
elif [[ $BRANCH_NAME == *miui* ]]
then
  export OSTYPE=MIUI
  export OSVERSION=N
fi
echo -e "\033[0;91m> android type = ${OSTYPE} ${OSVERSION} \033[0m\n"


# identify branch is whether treble or not
if [[ $DEFCONFIGK == *treble* ]]
then
  export MAKETYPE=treble
  export ZIP_NAME="${KERNEL_NAME}.${OSTYPE}.${OSVERSION}.TR.$(date +%d%m%Y.%H%M).zip"
  echo -e "\033[0;91m> make type = treble \033[0m\n"
else
  export MAKETYPE=non-treble
  export ZIP_NAME="${KERNEL_NAME}.${OSTYPE}.${OSVERSION}.$(date +%d%m%Y.%H%M).zip"
  echo -e "\033[0;91m> make type = non-treble \033[0m\n"
fi


# directories - read n' understand the paths, u dumbass !
export GCCDIR=${HOME}/gcc-host-linux-x86
export CLANGDIR=${HOME}/clang-host-linux-x86
export GCC32DIR=${HOME}/gcc-host-linux

export ZIP_DIR=${SEMAPHORE_PROJECT_DIR}/AnyKernel2
export OUT_DIR=${SEMAPHORE_PROJECT_DIR}/out

# zip related stuff

export FINAL_NAME="${KERNEL_NAME}-${OSTYPE}-${OSVERSION}"
export FINAL_ZIP=$ZIP_DIR/${ZIP_NAME}
export IMAGE_OUT=$OUT_DIR/arch/arm64/boot/Image.gz-dtb

# functions - credits: @infinity-plus and @Vvr-RockStar
function SendDoc() {
	curl -F chat_id="$CHAT_ID" -F document=@"$1" -F caption="$2" https://api.telegram.org/bot"$BOT_API_KEY"/sendDocument 1> /dev/null
}

function SendMsg() {
	curl -s -X POST https://api.telegram.org/bot"$BOT_API_KEY"/sendMessage  -d "parse_mode=markdown" -d text="$1 " -d chat_id="$CHAT_ID" 1> /dev/null
}

function sendlog() {
    for BINARY in curl jq
    do
        command -v ${BINARY} &>/dev/null || {
            SendMsg "ERROR: ${BINARY} is not installed" >&2
            exit 1
        }
    done
    RESULT=$(curl -sf --data-binary @"${1:--}" https://del.dog/documents) || {
        SendMsg "ERROR: failed to post document, ca-certificates might need to be installed" >&2
        exit 1
    }
    SendMsg "Here's the [${1}](https://del.dog/$(jq -r .key <<< "${RESULT}"))"
}

function transfer() {
  zipname="$(echo "$1" | awk -F '/' '{print $NF}')"
  url="$(curl -# -T "$1" https://transfer.sh)"
  echo -e "\n\033[0;35m>download ${zipname} at ${url} \033[0;0m\n"
}

# Get kernel details from compile.h -credits: @nathanchance
function evv() {
    FILE="${OUT_DIR}"/include/generated/compile.h
    export "$(grep "${1}" "${FILE}" | cut -d'"' -f1 | awk '{print $2}')"="$(grep "${1}" "${FILE}" | cut -d'"' -f2)"
}

function checkVar() {
   if [[ -z ${$1} ]]
   then
     echo -e "Please set $1"
     exit 1
   fi
}

# Check necessary variables
checkVar CHAT_ID
checkVar BOT_API_KEY
checkVar KERNEL_NAME


# build environment setup
# sudo apt-get install -y build-essential libncurses5-dev bzip2 bc ccache git-core
install-package jq ccache bc libncurses5-dev git-core gnupg flex bison gperf build-essential zip curl libc6-dev ncurses-dev

# Want to use a different toolchain? (DTC, UberTC etc) - credits: @bitrvmpd
# ==================================
# point CROSS_COMPILE to the folder of the desired toolchain
# don't forget to specify the prefix. mine is: aarch64-linux-android-

# get gcc
export CROSS_COMPILE=$GCCDIR/bin/aarch64-linux-gnu-

if [[ "$*" == *"-gcc8"* ]]
 then
  git clone https://github.com/RaphielGang/aarch64-linux-gnu-8.x "$HOME"/gcc-host-linux-x86 --depth=1
elif [[ "$*" == *"-gcc9"* ]]
then
  git clone https://github.com/Haseo97/aarch64-elf-gcc -b master "$HOME"/gcc-host-linux-x86 --depth=1
  export CROSS_COMPILE=$GCCDIR/bin/aarch64-elf-
elif [[ "$*" == *"-linaro7"* ]]
then
  git clone https://github.com/teamfirangi/linaro-7.3 "$HOME"/gcc-host-linux-x86 --depth=1
else
  git clone https://github.com/ryan-andri/aarch64-linaro-linux-gnu-4.9 "$HOME"/gcc-host-linux-x86 --depth=1
fi

# get arm toochain
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 "$HOME"/gcc-host-linux --depth=1

# get gcc version - credits: @infinity-plus
export GCCVERSION=$("$GCCDIR"/bin/*-gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
echo -e "\033[0;31m\n$GCCVERSION ready to compile ! \033[0;0m\n"

# get clang
if [[ $GITBRANCH == dtc || "$*" == *"-dtc"* ]]
then
  git clone https://github.com/VRanger/dragontc "$HOME"/clang-host-linux-x86 --depth=1
elif [[ $GITBRANCH == clang || "$*" == *"-clang"* ]]
then
  git clone https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5484270 "$HOME"/clang-host-linux-x86 --depth=1
fi

if [[ -e $HOME/clang-host-linux-x86 ]]
then
  export CLANGVERSION=$("$CLANGDIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
  echo -e "\033[0;31m\n$CLANGVERSION ready to compile ! \033[0;0m\n"
fi

# get anykernel2
#Clean ZIP_DIR, if any
rm -rf "${ZIP_DIR}"

if [[ $DEVICE == santoni && $GITBRANCH == miui ]]
then
  git clone https://github.com/dencel007/AnyKernel -b santoni-modules "${ZIP_DIR}" --depth=1
elif [[ $DEVICE == santoni && $GITBRANCH != miui ]]
then
  git clone https://github.com/dencel007/AnyKernel -b santoni-main "${ZIP_DIR}" --depth=1
elif [[ $DEVICE == davinci && $GITBRANCH == miui ]]
then
  git clone https://github.com/dencel007/AnyKernel -b davinci-modules "${ZIP_DIR}" --depth=1
elif [[ $DEVICE == davinci && $GITBRANCH != miui ]]
then
  git clone https://github.com/dencel007/AnyKernel -b davinci-main "${ZIP_DIR}" --depth=1
fi

# prepend ccache into the PATH
echo 'export PATH="/usr/lib/ccache:$PATH"' | tee -a ~/.bashrc

# source bashrc to test the new PATH
source ~/.bashrc && echo "$PATH"

export USE_CCACHE=1
ccache -M 6G

cd "$SEMAPHORE_PROJECT_DIR"

# out directory config - why ?
# http://bit.ly/2UQv06H - read thoroughly
if [ -e "${OUT_DIR}" ]
then
  echo -e "\n\033[0;32m> out directory already exists ! deleting it.... \033[0;0m\n" 
  rm -rf "${OUT_DIR}"
else
  echo -e "\n\033[0;32m> out directory doesn't exist ! creating it.... \033[0;0m\n" 
  mkdir -pv "${OUT_DIR}"
fi
export MAKE="make O=out"
echo -e "\n\033[0;32m> executing make clean \033[0;0m\n"
make clean
echo -e "\n\033[0;32m> executing make O=out clean \033[0;0m\n"
${MAKE} clean

# main build commands starts here

export ARCH=arm64
export SUBARCH=arm64
$MAKE "$DEFCONFIGK"

# Want custom kernel flags ?
# =========================
# KBUILD_KERNEL_CFLAGS: Here you can set custom compilation
# flags to turn off unwanted warnings, or even set a
# different optimization level.
# To see how it works, check the Makefile ... file,
# line 625 to 628, located in the root dir of this kernel.

# KBUILD_KERNEL_CFLAGS=-Wno-misleading-indentation -Wno-bool-compare -mtune=cortex-a53 -march=armv8-a+crc+simd+crypto -mcpu=cortex-a53 -O2
# $MAKE -j$(nproc --all) ARCH=$ARCH SUBARCH=$SUBARCH CROSS_COMPILE=$CROSS_COMPILE KCFLAGS=$KBUILD_KERNEL_CFLAGS

# making modules for miui
if [[ $GITBRANCH == miui ]]
then
  echo -e "\n\033[0;35m> making modules for miui \033[0;0m\n"
  ${MAKE} modules
fi

# clang/dtc/gcc build commands
if [[ $GITBRANCH == clang || $GITBRANCH == dtc ]]
then
  start=$SECONDS
  echo -e "\n\033[0;35m> starting CLANG kernel build with $CLANGVERSION toolchain \033[0;0m\n"

  PATH="$HOME/clang-host-linux-x86/bin:$HOME/gcc-host-linux-x86/bin:${PATH}"
  ${MAKE} -j"$(nproc --all)" \
                         ARCH=$ARCH \
                         SUBARCH=$SUBARCH \
                         CC="$HOME"/clang-host-linux-x86/bin/clang \
                         CLANG_TRIPLE=aarch64-linux-gnu- \
                         CLANG_LD_PATH="${HOME}"/clang-host-linux-x86/clang/lib \
                         LLVM_DIS="${HOME}"/clang-host-linux-x86/bin/llvm-dis 2>&1 | tee build-log.txt
else
  start=$SECONDS
  echo -e "\033[0;35m> starting AOSP kernel build with $GCCVERSION toolchain \033[0;0m\n"

  export CROSS_COMPILE_ARM32=$HOME/gcc-host-linux/bin/arm-linux-androideabi-

  ${MAKE} -j"$(nproc --all)" \
                         ARCH="$ARCH" \
                         CROSS_COMPILE="$CROSS_COMPILE" \
                         CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
                         KCFLAGS="$KCFLAGS" 2>&1 | tee build-log.txt
fi

# checks if the Image.gz-dtb is built or not
if [[ ! -f "${IMAGE_OUT}" ]]
then
    echo -e "\n\033[0;31m> $IMAGE_OUT not FOUND. build failed \033[0;0m\n"
    SendMsg "Build failed !"
    sendlog "build-log.txt"
    grep -iE 'crash|Crash|CRASH|error|Error|ERROR|fail|Fail|FAIL|fatal|Fatal|FATAL' "build-log.txt" &> "mini_log.txt"
    sendlog "mini_log.txt"
    exit 1
else
    echo -e "\n\033[0;32m> $IMAGE_OUT FOUND. build successful \033[0;0m\n"
    end=$SECONDS
    duration=$(( end - start ))
    printf "\033[0;32m> $KERNEL_NAME kernel ci build completed in %dh:%dm:%ds \033[0;0m" $((duration/3600)) $((duration%3600/60)) $((duration%60))
fi

# get current kernel makefile version
KERNEL_VERSION=$(head -n3 Makefile | sed -E 's/.*(^\w+\s[=]\s)//g' | xargs | sed -E 's/(\s)/./g')
echo -e "\033[0;36m> packing ${KERNEL_NAME}.${OSTYPE}.${OSVERSION} kernel v$KERNEL_VERSION  \033[0;0m\n"
echo -e "\n\n\033[0;35m> ================== now, let's zip it ! ===================\033[0;0m\n"

cd "$SEMAPHORE_PROJECT_DIR"

# modules directory config
# modules strip starts for miui

if [[ $GITBRANCH == miui ]]
then
  export MODULES_DIR=${SEMAPHORE_PROJECT_DIR}/modules/system/lib/modules
  export ZIPMODULES_DIR=${ZIP_DIR}/modules
  if [[ -d $MODULES_DIR ]]
  then
    echo -e "\n cleaning old modules folder \n"
    rm -rf "$MODULES_DIR"
  else
    mkdir -pv "$MODULES_DIR"
    echo -e "\n made new modules folder \n"
  fi
  find . -name '*ko' -exec \ cp '{}' modules/ \;
  chmod 755 modules/*

 "$CROSS_COMPILE"strip --strip-unneeded "$MODULES_DIR"/* 2>/dev/null
 "$CROSS_COMPILE"strip --strip-debug "$MODULES_DIR"/* 2>/dev/null

 mkdir -pv "$ZIPMODULES_DIR"/system/lib/modules
 sudo chmod -R 755 "$ZIPMODULES_DIR"/*
 cp -f "$MODULES_DIR"/*.ko "$ZIPMODULES_DIR"/system/lib/modules
 mkdir -pv "$ZIPMODULES_DIR"/system/lib/modules/pronto
 cp -f "$ZIPMODULES_DIR"/system/lib/modules/wlan.ko "$ZIPMODULES_DIR"/system/lib/modules/pronto/pronto_wlan.ko
fi

# make flashable zip using anykernel
rm -rf "$ZIP_DIR"/zImage "$ZIP_DIR"/*.zip
mv "$IMAGE_OUT" "$ZIP_DIR"/zImage
cd "$ZIP_DIR"
zip -r9 "${FINAL_ZIP}" * -x .git README.md *placeholder
cd -

# upload zip to transfer.sh
if [ -f "$FINAL_ZIP" ]
then
  echo -e "\n\033[0;32m> $ZIP_NAME can be found at $ZIP_DIR \033[0;0m\n"
  echo -e "\033[0;36m> uploading $ZIP_NAME to https://transfer.sh/ \033[0;0m\n"
  transfer "$FINAL_ZIP"
fi

# Get TC version
evv LINUX_COMPILER

# final push to telegram
if [ -f "$FINAL_ZIP" ]
then
 caption="
 name : $FINAL_NAME
 type : $MAKETYPE
 $url" 
 
 text="
 ⚙️ name : $KERNEL_NAME kernel
 📕 branch : $BRANCH_NAME
 🔰 linux-version : $KERNEL_VERSION
 🕐 build-time : $((duration%3600/60))m:$((duration%60))s

 toolchain :
 $LINUX_COMPILER

 last commit :
 $(git log --pretty=format:'%h | %s' -1)
 " 
 SendDoc "$FINAL_ZIP" "$caption"
 SendMsg "$text"

 curl -s -X POST https://api.telegram.org/bot"$BOT_API_KEY"/sendSticker -d sticker="CAADBQADuQADLG6EE9HnR-_L0F2YAg" -d chat_id="$CHAT_ID"
 rm -rf "${ZIP_DIR:?}"/"$ZIP_NAME"
 echo -e "\n\n \033[0;35m> ======= aye, now go on, flash zip and brick yo device sur =======\033[0;0m\n"
else
echo -e "\n\033[0;31m> zip creation failed \033[0;0m\n"
fi
