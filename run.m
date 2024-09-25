#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <objc/runtime.h>
#include <objc/message.h>

extern int SBSLaunchApplicationWithIdentifier(CFStringRef identifier, Boolean suspended);
extern CFStringRef SBSApplicationLaunchingErrorString(int error);

CFStringRef GetBundleIdentifier(CFStringRef appName) {
    id workspace = ((id (*)(id, SEL))objc_msgSend)(objc_getClass("LSApplicationWorkspace"), sel_registerName("defaultWorkspace"));
    NSArray *apps = ((NSArray *(*)(id, SEL))objc_msgSend)(workspace, sel_registerName("allApplications"));

    for (id app in apps) {
        CFStringRef displayName = ((CFStringRef (*)(id, SEL))objc_msgSend)(app, sel_registerName("localizedName"));
        if (displayName && (CFStringCompare(displayName, appName, 0) == kCFCompareEqualTo || CFStringFind(displayName, appName, kCFCompareAnchored).location != kCFNotFound)) {
            return ((CFStringRef (*)(id, SEL))objc_msgSend)(app, sel_registerName("bundleIdentifier"));
        }
    }
    return NULL;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <com.application.identifier | Application Name>\n", argv[0]);
        return -1;
    }

    char combinedArgs[1024] = {0};
    for (int i = 1; i < argc; ++i) {
        strcat(combinedArgs, argv[i]);
        if (i < argc - 1) strcat(combinedArgs, " ");
    }

    CFStringRef input = CFStringCreateWithCString(NULL, combinedArgs, kCFStringEncodingUTF8);
    if (!input) {
        fprintf(stderr, "Failed to create CFStringRef\n");
        return -1;
    }

    int ret = SBSLaunchApplicationWithIdentifier(input, FALSE);
    if (ret != 0) {
        CFStringRef bundleID = GetBundleIdentifier(input);
        if (bundleID) {
            ret = SBSLaunchApplicationWithIdentifier(bundleID, FALSE);
            CFRelease(bundleID);
        }
    }

    if (ret != 0) {
        fprintf(stderr, "Couldn't open application: %s. Reason: %i, ", combinedArgs, ret);
        CFShow(SBSApplicationLaunchingErrorString(ret));
    }

    CFRelease(input);
    return ret;
}
