export TARGET = iphone:clang:16.5:17.0
export ARCHS  = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmazonDark AmazonDarkSB

AmazonDark_FILES   = src/Tweak.xm src/ADColor.m src/ADImageKey.m
AmazonDark_CFLAGS  = -fobjc-arc -fexceptions
AmazonDark_CFLAGS += -Wno-unused-variable -Wno-unused-function
AmazonDark_CFLAGS += -Wno-deprecated-declarations -Wno-error
AmazonDark_FRAMEWORKS = UIKit Foundation WebKit CoreGraphics QuartzCore CoreFoundation

# SpringBoard-side dark launch cover (injects ONLY into com.apple.springboard
# via AmazonDarkSB.plist). Defensive: every hook guarded, cover auto-removes.
AmazonDarkSB_FILES      = src/AmazonDarkSB.xm
AmazonDarkSB_CFLAGS     = -fobjc-arc -fexceptions -Wno-unused-variable -Wno-error
AmazonDarkSB_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

# Bundle the official Dark Reader UMD (resources/) alongside the dylib as
# AmazonDark.bundle so the tweak can read darkreader.js at runtime.
AmazonDark_BUNDLE_RESOURCE_DIRS = Resources


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
