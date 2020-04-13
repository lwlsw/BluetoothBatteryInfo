ARCHS = arm64 arm64e
TARGET = iphone:clang:11.2:11.2

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BluetoothBatteryInfoPrefs
BluetoothBatteryInfoPrefs_FILES = BBIAppearanceSettings.m BBIRootHeaderView.mm BBIRootListController.xm
BluetoothBatteryInfoPrefs_INSTALL_PATH = /Library/PreferenceBundles
BluetoothBatteryInfoPrefs_FRAMEWORKS = UIKit
BluetoothBatteryInfoPrefs_PRIVATE_FRAMEWORKS = Preferences
BluetoothBatteryInfoPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
BluetoothBatteryInfoPrefs_EXTRA_FRAMEWORKS = Cephei CepheiPrefs

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/BluetoothBatteryInfoPrefs.plist$(ECHO_END)
