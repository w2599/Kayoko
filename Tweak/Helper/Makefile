TWEAK_NAME := KayokoHelper

KayokoHelper_FILES += KayokoHelper.m
KayokoHelper_FILES += KeyokoHelperLogos.xm
KayokoHelper_FILES += KayokoMenu.m
KayokoHelper_FILES += KayokoKeyboardShortcutSender.m
KayokoHelper_FILES += $(wildcard ../../Manager/*.m ../../Utils/*.m)


KayokoHelper_CFLAGS += -fobjc-arc
KayokoHelper_CFLAGS += -I../../Headers
KayokoHelper_CFLAGS += -I../../Preferences
KayokoHelper_CFLAGS += -I../../Manager
KayokoHelper_CFLAGS += -I../../Utils

KayokoHelper_FRAMEWORKS += UIKit IOKit
KayokoHelper_LIBRARIES += sandy sqlite3

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/tweak.mk
