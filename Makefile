TARGET := iphone:clang:latest:7.0
THEOS_DEVICE_IP = 192.168.2.90
export ARCHS = armv7 arm64 arm64e

include $(THEOS)/makefiles/common.mk

TOOL_NAME = run
run_FILES = run.m
run_PRIVATE_FRAMEWORKS = SpringBoardServices
run_CODESIGN_FLAGS = -SEntitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
