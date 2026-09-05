export TARGET = iphone:clang:16.5:17.0
export ARCHS  = arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmazonDark AmazonDarkSB

AmazonDark_FILES      = src/Tweak.xm
AmazonDark_CFLAGS     = -fobjc-arc -fexceptions -Os -ffunction-sections -fdata-sections -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-error
AmazonDark_LDFLAGS    = -Wl,-dead_strip
AmazonDark_FRAMEWORKS = UIKit Foundation WebKit QuartzCore CoreFoundation

# SpringBoard launch cover / transition / custom artwork.
AmazonDarkSB_FILES      = src/AmazonDarkSB.xm
AmazonDarkSB_CFLAGS     = -fobjc-arc -fexceptions -Os -ffunction-sections -fdata-sections -Wno-unused-variable -Wno-error
AmazonDarkSB_LDFLAGS    = -Wl,-dead_strip
AmazonDarkSB_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
AmazonDarkSB_LIBRARIES  = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

# Exact v6.0.185 preference-bundle wiring retained.
BUNDLE_NAME = ADPrefs
ADPrefs_FILES         = prefs/ADPrefsController.xm
ADPrefs_INSTALL_PATH  = /Library/PreferenceBundles
ADPrefs_FRAMEWORKS    = UIKit Foundation CoreFoundation
ADPrefs_CFLAGS        = -fobjc-arc -Os -ffunction-sections -fdata-sections -Wno-error -Wno-unused-variable -Wno-unused-function
ADPrefs_LDFLAGS       = -Wl,-dead_strip
ADPrefs_RESOURCE_DIRS = prefs/Resources
include $(THEOS_MAKE_PATH)/bundle.mk

after-package::
	@ls -1t packages/*.deb 2>/dev/null | head -1 | xargs -I{} echo "package ready: {}"
