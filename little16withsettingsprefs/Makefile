TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Little16WithSettingsPrefs

Little16WithSettingsPrefs_FILES = L16RootListController.m
Little16WithSettingsPrefs_FRAMEWORKS = UIKit
# Preferences is a private framework missing from the CI SDKs: resolve its symbols at runtime
Little16WithSettingsPrefs_LDFLAGS = -undefined dynamic_lookup
Little16WithSettingsPrefs_INSTALL_PATH = /Library/PreferenceBundles
Little16WithSettingsPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/Little16WithSettings.plist$(ECHO_END)
