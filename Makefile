export PACKAGE_VERSION := 4.3
export ARCHS := arm64e
export TARGET := iphone:clang:16.5:14.0

INSTALL_TARGET_PROCESSES := SpringBoard
INSTALL_TARGET_PROCESSES += Spotlight
INSTALL_TARGET_PROCESSES += druid
INSTALL_TARGET_PROCESSES += pasted
INSTALL_TARGET_PROCESSES += Preferences

SUBPROJECTS += Tweak/Core
SUBPROJECTS += Tweak/Helper
SUBPROJECTS += Preferences
SUBPROJECTS += Updater

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
