BUNDLE_NAME += KayokoPreferences

KayokoPreferences_FILES += $(wildcard Controllers/*.m Cells/*.m ../Manager/*.m)
KayokoPreferences_FILES += $(wildcard ../Utils/*.m)

KayokoPreferences_CFLAGS += -fobjc-arc
KayokoPreferences_CFLAGS += -DDISABLE_ROOTLESS_COMPAT_WARNING
KayokoPreferences_CFLAGS += -I../Manager
KayokoPreferences_CFLAGS += -I../Preferences
KayokoPreferences_CFLAGS += -I../Utils

KayokoPreferences_FRAMEWORKS += UIKit
KayokoPreferences_PRIVATE_FRAMEWORKS += Preferences
KayokoPreferences_LIBRARIES += sqlite3
KayokoPreferences_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk
