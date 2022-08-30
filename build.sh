#!/bin/bash

echo
echo "--------------------------------------"
echo "    Pixel Experience 12.1 Buildbot    "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

set -e

BL=$PWD/treble_build_pe
BD=/root/aosp/itzkaguya/builds
BRANCH=$1
export WITH_SU=false
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G
export BUILD_USER=crazyads69
export BUILD_HOST=crazyads69
export BUILD_USERNAME=crazyads69
export BUILD_HOSTNAME=crazyads69
export KBUILD_BUILD_USER=crazyads69
export KBUILD_BUILD_HOST=crazyads69

[ "$BRANCH" == "" ] && BRANCH="twelve"
[ "$BRANCH" == "twelve" ] && BUILD="PixelExperience" || BUILD="PixelExperience_Plus"
[ "$BRANCH" == "twelve" ] && PEMK="$BL/pe.mk" || PEMK="$BL/peplus.mk"

installRequiredDependency() {
    echo "---> Install Required Dependency"
    apt install -y bc bison build-essential curl flex g++-multilib gcc-multilib git gnupg gperf libxml2 \
                lib32z1-dev liblz4-tool libncurses5-dev libsdl1.2-dev libwxgtk3.0-gtk3-dev imagemagick git \
                lunzip lzop schedtool squashfs-tools xsltproc zip zlib1g-dev openjdk-8-jdk python2 perl  \
                xmlstarlet virtualenv xz-utils rr jq libncurses5 pngcrush lib32ncurses5-dev git-lfs libxml2 \
                openjdk-11-jdk-headless

    echo

    apt install -y openjdk-8-jdk apache2 bc bison build-essential ccache curl \
                flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev \
                lib32readline-dev lib32z1-dev liblz4-tool libncurses5-dev libsdl1.2-dev \
                libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
                schedtool squashfs-tools xsltproc zip zlib1g-dev git-core gnupg flex \
                bison gperf build-essential zip curl zlib1g-dev gcc-multilib g++-multilib \
                libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev ccache \
                libgl1-mesa-dev libxml2-utils xsltproc unzip python3 libncurses5

    echo

}

initRepos() {
    if [ ! -d .repo ]; then
        echo "--> Initializing PE workspace"
        repo init -u https://github.com/PixelExperience/manifest -b $BRANCH --groups=all,-notdefault,default,-device,-darwin,-x86,-mips,-exynos5,-mako,-lge,-coral,-goldfish,-qemu --depth=1
        echo

        echo "--> Preparing local manifest"
        mkdir -p .repo/local_manifests
        cp $BL/manifest.xml .repo/local_manifests/pixel.xml
        echo
    fi
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all) --optimized-fetch --prune
    echo
}

applyPatches() {
    echo "--> Applying prerequisite patches"
    bash $BL/apply-patches.sh $BL prerequisite $BRANCH
    echo

    echo "--> Applying PHH patches"
    cd device/phh/treble
    cp $PEMK .
    bash generate.sh $(echo $PEMK | sed "s#$BL/##;s#.mk##")
    cd ../../..
    bash $BL/apply-patches.sh $BL phh $BRANCH
    echo

    echo "--> Applying personal patches"
    bash $BL/apply-patches.sh $BL personal $BRANCH
    echo
}

setupEnv() {
    echo "--> Setting up build environment"
    source build/envsetup.sh &>/dev/null
    mkdir -p $BD
    echo
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    cp release/TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
}

buildVariant() {
    echo "--> Building treble_a64_bvN"
    lunch treble_a64_bvN-userdebug
    make installclean
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-treble_a64_bvN.img
    echo
}

buildSlimVariant() {
    echo "--> Building treble_a64_bvN-slim"
    wget https://gist.github.com/ponces/891139a70ee4fdaf1b1c3aed3a59534e/raw/slim.patch -O /tmp/slim.patch
    (cd vendor/gapps && git am /tmp/slim.patch && rm /tmp/slim.patch)
    make -j$(nproc --all) systemimage
    (cd vendor/gapps && git reset --hard HEAD~1)
    mv $OUT/system.img $BD/system-treble_a64_bvN-slim.img
    echo
}


generatePackages() {
    echo "--> Generating packages"
    xz -cv $BD/system-treble_a64_bvN.img -9 -T0 > $BD/"$BUILD"_a64-ab-12.1-$BUILD_DATE-UNOFFICIAL.img.xz
    xz -cv $BD/system-treble_a64_bvN-slim.img -9 -T0 > $BD/"$BUILD"_a64-ab-slim-12.1-$BUILD_DATE-UNOFFICIAL.img.xz
    rm -rf $BD/system-*.img
    echo
}

START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"

installRequiredDependency
initRepos
syncRepos
applyPatches
setupEnv
buildTrebleApp
buildVariant
buildSlimVariant
generatePackages

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
