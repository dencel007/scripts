#!/usr/bin/env bash
export TZ="Asia/Kolkata";

# make more room in the environment
sudo rm -rf ~/.rbenv ~/.phpbrew

# predefined variables - https://semaphoreci.com/docs/available-environment-variables.html
cd $SEMAPHORE_PROJECT_DIR

echo -e "\n\033[0;30m##################################################"
echo -e "\033[0;92m### semaphore ci v1.0 - kernel building script ###"
echo -e "\033[0;30m##################################################\033[0m\n"


# specific environment variables
export KBUILD_BUILD_USER="Dencel"
export KBUILD_BUILD_HOST="Zeus"

export DEVICE=HM4X;
export ARCH=arm64;
export SUBARCH=arm64;
export DEFCONFIG=santoni_defconfig;

# identify git branchname
if [[ $BRANCH_NAME == *clang* ]]; then
  export GITBRANCH=clang
  echo -e "\033[0;91m> current git branch = clang \033[0m\n"
elif [[ $BRANCH_NAME == *miui* ]]; then
  export GITBRANCH=miui
  echo -e "\033[0;91m> current git branch = MIUI \033[0m\n"
else
  export GITBRANCH=aosp
  echo -e "\033[0;91m> current git branch = AOSP \033[0m\n"
fi

# identify os type
if [[ $BRANCH_NAME == *pie* ]]; then
  export OSVERSION=P
  echo -e "\033[0;91m> building for android = P \033[0m\n"
elif [[ $BRANCH_NAME == *oreo* ]]; then
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
if [[ "$*" == *"-gcc8"* ]]; then
  export GCCDIR=${HOME}/gcc-arm-host-linux-x86
else
  export GCCDIR=${HOME}/prebuilts-gcc-host-linux-x86
fi

export CLANGDIR=${HOME}/prebuilts-clang-host-linux-x86
export ZIP_DIR=${SEMAPHORE_PROJECT_DIR}/AnyKernel2
export OUT_DIR=${SEMAPHORE_PROJECT_DIR}/out

# zip related stuff
export ZIP_NAME="${KERNEL_NAME}-${OSVERSION}-${MAKETYPE}-${DEVICE}-$(date +%Y%m%d-%H%M).zip";
export FINAL_ZIP=$ZIP_DIR/${ZIP_NAME}
export IMAGE_OUT=$OUT_DIR/arch/arm64/boot/Image.gz-dtb

# misc
export MAKE="make O=${OUT_DIR}";

# Want to use a different toolchain? (Linaro, UberTC, etc) - @bitrvmpd
# ==================================
# point CROSS_COMPILE to the folder of the desired toolchain
# don't forget to specify the prefix. Mine is: aarch64-linux-android-
export CC=$CLANGDIR/bin/clang
export CLANGTRIPLE=aarch64-linux-gnu-

if [[ "$*" == *-gcc8* ]]; then
  export TCPREFIX=aarch64-linux-gnu-
else
  export TCPREFIX=aarch64-linux-android-
fi

export PRECROSSCOMPILE=$GCCDIR/bin/$TCPREFIX

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
sudo apt-get install -y build-essential libncurses5-dev bzip2 bc ccache git-core

if [[ "$*" == *"-gcc8"* ]]; then
  if [[ -d $HOME/gcc-arm-host-linux-x86 ]]; then
    rm -rf $HOME/prebuilts-gcc-host-linux-x86
  fi
  git clone https://github.com/VRanger/aarch64-linux-gnu/ -b gnu-8.x $HOME/gcc-arm-host-linux-x86 --depth=1
else
  # get prebuilts google gcc compiler
  if [[ -d $HOME/prebuilts-gcc-host-linux-x86 ]]; then
  	rm -rf $HOME/prebuilts-gcc-host-linux-x86
  fi
  git clone https://github.com/dencel007/prebuilts-gcc-host-linux-x86 $HOME/prebuilts-gcc-host-linux-x86 --depth=1
fi

# get GCC version - @infinity-plus
export GCCVERSION=$($GCCDIR/bin/*-gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
echo -e "\033[0;31m\n$GCCVERSION ready to compile ! \033[0;0m\n"

# get google clang toolchain
if [[ $GITBRANCH == clang ]]; then
	if [[ -d $HOME/prebuilts-clang-host-linux-x86 ]]; then
		rm -rf $HOME/prebuilts-clang-host-linux-x86
	fi
	git clone https://github.com/dencel007/prebuilts-clang-host-linux-x86 $HOME/prebuilts-clang-host-linux-x86 --depth=1

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

# sets CCACHE path
echo 'export PATH="/usr/lib/ccache:$PATH"' | tee -a ~/.bashrc && source ~/.bashrc && echo $PATH

# CCACHE configuration - @bitrvmpd
# ==========================================
# If you want you can install ccache to speedup recompilation time.
# In ubuntu just run "sudo apt-get install ccache".
# By default CCACHE will use 6G, change the value of CCACHE_MAX_SIZE
# to meet your needs.
if [ -x "$(command -v ccache)" ]
then
  # If you want to clean the ccache
  # run this script with -clear-ccache
  if [[ "$*" == *"-clear-ccache"* ]]
  then
    echo -e "\n\033[0;31m> cleaning $KERNEL_WORKING_DIR/.ccache contents\033[0;0m"
    rm -rf "$KERNEL_WORKING_DIR/.ccache"
  fi
  # If you want to build *without* using ccache
  # run this script with -no-ccache flag
  if [[ "$*" != *"-no-ccache"* ]]
  then
    export USE_CCACHE=1
    export CCACHE_DIR="$KERNEL_WORKING_DIR/.ccache"
    export CCACHE_MAX_SIZE=6G
    echo -e "\n\033[0;32m> $(ccache -M $CCACHE_MAX_SIZE)\033[0;0m"
    echo -e "\n\033[0;32m> using ccache, to disable it run this script with -no-ccache\033[0;0m\n"
  else
    echo -e "\033[0;31m> NOT using ccache, to enable it run this script without -no-ccache\033[0;0m\n"
  fi
else
  echo -e "\033[0;33m> [Optional] ccache not installed. You can install it (in ubuntu) using 'sudo apt-get install ccache'\033[0;0m\n"
fi

# Are we using ccache?
if [ -n "$USE_CCACHE" ]
then
  export CROSS_COMPILE="ccache $PRECROSSCOMPILE"
fi

# build starts here
cd $SEMAPHORE_PROJECT_DIR

# out directory config - but why ?
# http://bit.ly/2UQv06H - read thoroughly
  rm -rf $OUT_DIR;
	mkdir -p $OUT_DIR;

# make your kernel
if [[ $GITBRANCH == clang ]]; then
  start=$SECONDS
  echo -e "\033[0;35m> starting CLANG kernel build with $CLANGVERSION toolchain \033[0;0m\n"
  $MAKE ARCH=$ARCH $DEFCONFIG | tee build-log.txt ;

  PATH="$CLANGDIR/bin:$GCCDIR/bin:${PATH}" \
  make -j$(nproc --all) O=$OUT_DIR \
                        ARCH=$ARCH \
                        SUBARCH=$SUBARCH \
                        CC=$CC \
                        CROSS_COMPILE=$CROSS_COMPILE \
                        CLANG_TRIPLE=$CLANGTRIPLE

elif [[ $GITBRANCH == miui ]]; then
  start=$SECONDS
  echo -e "\033[0;35m> starting MIUI kernel build with $GCCVERSION toolchain \033[0;0m\n"

  ARCH=$ARCH SUBARCH=$SUBARCH CROSS_COMPILE=$CROSS_COMPILE
  $MAKE $DEFCONFIG
  $MAKE -j$(nproc --all) | tee build-log.txt ;
  $MAKE modules
else
  start=$SECONDS
  echo -e "\033[0;35m> starting AOSP kernel build with $GCCVERSION toolchain \033[0;0m\n"

  ARCH=$ARCH SUBARCH=$SUBARCH CROSS_COMPILE=$CROSS_COMPILE
  $MAKE $DEFCONFIG
  $MAKE -j$(nproc --all) | tee build-log.txt ;
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
    grep -iE 'crash|error|fail|fatal' "build-log.txt" &> "mini_log.txt";
    sendlog "mini_log.txt";
    success=false;
    exit 1;
else
    echo -e "\n\033[0;32m> $IMAGE_OUT FOUND. build successful \033[0;0m\n" ;
    success=true;
fi

# get current kernel makefile version
KERNEL_VERSION=$(head -n3 Makefile | sed -E 's/.*(^\w+\s[=]\s)//g' | xargs | sed -E 's/(\s)/./g')
echo -e "\033[0;36m> packing kernel v$KERNEL_VERSION $ZIP_NAME \033[0;0m\n" 

end=$SECONDS
duration=$(( end - start ))
printf "\033[0;32m> $KERNEL_NAME ci build completed in %dh:%dm:%ds \033[0;0m" $(($duration/3600)) $(($duration%3600/60)) $(($duration%60))
echo -e "\n\n\033[0;35m> ================== now, let's zip it ! ===================\033[0;0m\n"

cd $SEMAPHORE_PROJECT_DIR

# modules directory config
if [[ $GITBRANCH == miui ]]; then
export MODULES_DIR=${SEMAPHORE_PROJECT_DIR}/modules
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

  find . -name '*.ko' -exec cp {} $MODULES_DIR/ \;

  sudo chmod 755 $MODULES_DIR/*

  "$CROSS_COMPILE"strip --strip-unneeded $MODULES_DIR/* 2>/dev/null
  "$CROSS_COMPILE"strip --strip-debug $MODULES_DIR/* 2>/dev/null

  mkdir -p $ZIP_DIR/modules
  rm -r $ZIP_DIR/modules/*.ko
  rm -r $ZIP_DIR/modules/pronto
  cp -f $MODULES_DIR/*.ko $ZIP_DIR/modules/
  mkdir -p $ZIP_DIR/modules/pronto
  cp -f $ZIP_DIR/modules/wlan.ko $ZIP_DIR/modules/pronto/pronto_wlan.ko

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
$url
$ZIP_NAME" https://api.telegram.org/bot$BOT_API_KEY/sendDocument 

curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="
⚙️ $KERNEL_NAME CI build successful 
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