export TARGET = iphone:clang:16.5:17.0
export ARCHS  = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmazonDark

AmazonDark_FILES   = src/Tweak.xm
AmazonDark_CFLAGS  = -fobjc-arc -fexceptions
AmazonDark_CFLAGS += -Wno-unused-variable -Wno-unused-function
AmazonDark_CFLAGS += -Wno-deprecated-declarations -Wno-error
AmazonDark_FRAMEWORKS = UIKit Foundation WebKit CoreGraphics QuartzCore CoreFoundation




include $(THEOS_MAKE_PATH)/tweak.mk

# v6.0.0 backport: exact v5.446 preference-bundle build wiring.
BUNDLE_NAME = ADPrefs
ADPrefs_FILES         = prefs/ADPrefsController.xm
ADPrefs_INSTALL_PATH  = /Library/PreferenceBundles
ADPrefs_FRAMEWORKS    = UIKit Foundation CoreFoundation
ADPrefs_CFLAGS        = -fobjc-arc -Wno-error -Wno-unused-variable -Wno-unused-function
ADPrefs_RESOURCE_DIRS = prefs/Resources
include $(THEOS_MAKE_PATH)/bundle.mk

after-package::
	@ls -1t packages/*.deb 2>/dev/null | head -1 | xargs -I{} echo "package ready: {}"
