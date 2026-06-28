TWEAK_NAME := KayokoHelper

KayokoHelper_FILES += KayokoHelper.m
KayokoHelper_FILES += KayokoHelperLogos.xm
KayokoHelper_FILES += KayokoMenu.m
KayokoHelper_FILES += $(wildcard ../../Manager/*.m ../../Utils/*.m)

KayokoHelper_CFLAGS += -fobjc-arc
KayokoHelper_CFLAGS += -DDISABLE_ROOTLESS_COMPAT_WARNING
KayokoHelper_CFLAGS += -I../../Headers
KayokoHelper_CFLAGS += -I../../Preferences
KayokoHelper_CFLAGS += -I../../Manager
KayokoHelper_CFLAGS += -I../../Utils

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
KayokoHelper_LDFLAGS += -L../../Libraries/_roothide
else
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
KayokoHelper_LDFLAGS += -L../../Libraries/_rootless
else
KayokoHelper_LDFLAGS += -L../../Libraries
endif
endif

KayokoHelper_FRAMEWORKS += UIKit
KayokoHelper_LIBRARIES += sandy sqlite3

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/tweak.mk
