#!/bin/bash

#取绝对路径
tweakPath=$(cd "$(dirname "$0")";pwd)
buildPath="$(dirname "$tweakPath")/__build_roothide/$(basename "$tweakPath")"
echo "tweakPath: $tweakPath"
echo "buildPath: $buildPath"
cd $tweakPath
# make clean

versionFile=$(ls _version* | head -n 1)
versionSee=$(echo $versionFile | sed 's/_version_//g')

versionRSA="1.0.0-1"

if [ -d "$buildPath" ]; then
    rm -rf "$buildPath" || { echo "清理 buildPath 失败: $buildPath"; exit 1; }
fi
mkdir -p "$buildPath" || { echo "创建 buildPath 失败: $buildPath"; exit 1; }
cp -a . "$buildPath"/ || { echo "复制源文件到 buildPath 失败: $buildPath"; exit 1; }
cd "$buildPath" || { echo "切换到 buildPath 失败: $buildPath"; exit 1; }

# 如果还是原来的路径就退出
currentPath=$(pwd)
echo "currentPath: $currentPath"
if [ "$currentPath" == "$tweakPath" ]
then
    echo "当前路径未改变，退出脚本以防止覆盖原文件"
    exit 1
fi



##替换版本号
sed -i '' "s/^\(Version:\s*\).*/\1 ${versionSee}/" control
echo "编译版本号为${versionSee}"


if [ $1 -eq "0" ]
then
    export package FINALPACKAGE=1
	export THEOS_PACKAGE_SCHEME=rootless
	cp -af ./Headers/libSandyKayoko_rootless.plist ./layout/Library/libSandy/Kayoko.plist
	export THEOS_DEVICE_IP=192.168.31.158
	export THEOS_DEVICE_PORT=54322

	make do -j$(sysctl -n hw.physicalcpu)
	cp -f ./packages/*.deb $HOME/Documents/GitHub/myTweaks/roothide/
	exit
fi

if [ $1 -eq "10" ]
then
    export package FINALPACKAGE=1
	export THEOS_PACKAGE_SCHEME=roothide

	make do -j$(sysctl -n hw.physicalcpu)
	cp -f ./packages/*.deb $HOME/Documents/GitHub/myTweaks/roothide/
	exit
fi


if [ $1 -eq "1" ]
then
	export THEOS_PACKAGE_SCHEME=roothide
	make do 
	exit
fi


if [ $1 -eq "2" ]
then
	export package FINALPACKAGE=1
    export TWEAK_OBF=1
    export DEVELOPER_DIR="/Applications/Xcode-14.3.0.app/Contents/Developer"

	export THEOS_PACKAGE_SCHEME=roothide
    make package

	export THEOS_PACKAGE_SCHEME=rootless
	cp -af ./Headers/libSandyKayoko_rootless.plist ./layout/Library/libSandy/Kayoko.plist
    make package

	# cp -f ./packages/*.deb $tweakPath
	mv ./packages/*.deb $HOME/Documents/GitHub/myTweaks/rootless/
    exit
fi