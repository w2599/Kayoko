export PACKAGE_VERSION := 2.8
export ARCHS := arm64 arm64e
export TARGET := iphone:clang:16.5:14.0
export GO_EASY_ON_ME := 1

INSTALL_TARGET_PROCESSES := SpringBoard Preferences druid pasted

SUBPROJECTS += Tweak/Core
SUBPROJECTS += Tweak/Helper
SUBPROJECTS += Preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk