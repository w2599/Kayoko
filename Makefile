THEOS_DEVICE_IP = 192.168.31.158
export ARCHS = arm64e
export SYSROOT = $(THEOS)/sdks/iPhoneOS14.5.sdk

ifneq ($(THEOS_PACKAGE_SCHEME), rootless)
export TARGET = iphone:clang:14.5:13.0
export PREFIX = $(THEOS)/toolchain/Xcode.xctoolchain/usr/bin/
else
export TARGET = iphone:clang:14.5:15.0
endif

# INSTALL_TARGET_PROCESSES = SpringBoard
SUBPROJECTS = Tweak/Core Daemon Preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
stage::
	plutil -replace Program -string $(THEOS_PACKAGE_INSTALL_PREFIX)/usr/libexec/kayokod $(THEOS_STAGING_DIR)/Library/LaunchDaemons/dev.traurige.kayokod.plist
endif


clean::
	rm -rf .theos/obj
	rm -rf packages