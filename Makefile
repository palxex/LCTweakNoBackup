TARGET := iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = LCTweakNoBackup

LCTweakNoBackup_FILES = LCTweakNoBackup.m
LCTweakNoBackup_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
LCTweakNoBackup_FRAMEWORKS = Foundation UIKit
LCTweakNoBackup_INSTALL_PATH = /usr/local/lib

include $(THEOS_MAKE_PATH)/library.mk
