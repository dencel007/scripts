## [semaphoreci](https://semaphoreci.com/ "semaphoreci") v1.0 kernel build script 
by [@dencel007](https://github.com/dencel007 "@dencel007")

credits : [@bitrvmpd](https://github.com/bitrvmpd "@bitrvmpd"), [@infinity-plus](https://github.com/infinity-plus "@infinity-plus"), [@Vvr-RockStar](https://github.com/Vvr-RockStar "@Vvr-RockStar"), [@VRanger](https://github.com/VRanger "@VRanger") - thanks guys

credits : https://semaphoreci.com

at the moment its mainly optimised for my xiaomi santoni (arm64) kernel repo, by default git branches having "aosp/msm/master/nameitsomehowubitch" and "miui" in their name will be built with Google GCC 4.9 (GCC 4.9 will be replaced soon btw). 

script will also automatically identify the git branch which has "clang" in its branchname and then it will be built with Google Clang 9 and with GCC 4.9, that's the basic setup. you can also select between gcc4/gcc8 toolchains, but no other clangs are added right now (will expand later). 

semaphoreci.com v1.0 (semaphore 2.0 is another story) is the only host which support this ci kernel building setup, you guys can try on other ci's and share your experiences with me. and btw this is linked with telegram bot for sending updates,zip etc (more on this, later).

# basic setup :
- setup your semaphore account 
- fork my repo containing this script 
- do modifications in the "environment variables" and where ever you want 
- declare some environment variable in the build settings page of semaphore (https://semaphoreci.com/dencel007/android_kernel_xiaomi_santoni/settings)

> substitute my username and repository name with yours, dumbass !

# semaphore build setup :
`export KERNEL_NAME=whateveryoulike`

`curl rawfile_link_here > build.sh `(just get this raw script)

`bash build.sh `(execute it)

## extras :

add `-gcc8` in the bash command to change between the toolchains

- eg : `bash build.sh -gcc8`

add `-clang` in the bash command to manually build with clang toolchain

- eg : `bash build.sh -clang`

# basic requirements :
1. basic linux and kernel building knowledge
2. your kernel should contain enough clang commits