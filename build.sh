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
BD=/tmp/itzkaguya/builds
BRANCH=$1
export WITH_SU=false
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G
export BUILD_USER=ItzKaguya
export BUILD_HOST=SuzuNetwork-CI
export BUILD_USERNAME=ItzKaguya
export BUILD_HOSTNAME=SuzuNetwork-CI
export KBUILD_BUILD_USER=ItzKaguya
export KBUILD_BUILD_HOST=SuzuNetwork-CI

[ "$BRANCH" == "" ] && BRANCH="twelve"
[ "$BRANCH" == "twelve" ] && BUILD="PixelExperience" || BUILD="PixelExperience_Plus"
[ "$BRANCH" == "twelve" ] && PEMK="$BL/pe.mk" || PEMK="$BL/peplus.mk"

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

generatePackages() {
    echo "--> Generating packages"
    xz -cv $BD/system-treble_a64_bvN.img -9 -T0 > $BD/PixelExperience-Plus_a64-ab-12.1-ItzKaguyaGSI-UNOFFICIAL.img.xz
    curl bashupload.com -T $BD/PixelExperience-Plus_a64-ab-12.1-ItzKaguyaGSI-UNOFFICIAL.img.xz | tee pe-build.txt
    cat pe-build.txt
    rm -rf $BD/system-*.img
    echo
}

START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"

initRepos
syncRepos
applyPatches
setupEnv
buildTrebleApp
buildVariant
generatePackages

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
