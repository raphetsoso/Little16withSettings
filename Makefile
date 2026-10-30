FINALPACKAGE = 1
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Little16WithSettings
Little16WithSettings_FILES = Tweak.xm
Little16WithSettings_CFLAGS = -fobjc-arc

SUBPROJECTS += little16withsettingsprefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
