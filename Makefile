TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FMSSuperMenu

FMSSuperMenu_FILES = Tweak.xm
FMSSuperMenu_FRAMEWORKS = UIKit CoreLocation AVFoundation CoreMedia CoreGraphics Photos MobileCoreServices
FMSSuperMenu_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/tweak.mk


