#!/bin/bash

cd $(dirname $0);pwd
make clean
export  package FINALPACKAGE=1
export  THEOS_PACKAGE_SCHEME=rootless

if [ $1 -eq "1" ]
then
	make do
	echo -e "sbreload" | ssh root@192.168.31.158
	exit
fi


make package

mv ./packages/*.deb ~/Desktop/tweaks/debs/ && make clean


# clean::
	# rm -rf .theos/obj
	# rm -rf packages