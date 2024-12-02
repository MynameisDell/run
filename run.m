#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <objc/runtime.h>
#include <objc/message.h>

extern int SBSLaunchApplicationWithIdentifier(CFStringRef identifier, Boolean suspended);
extern CFStringRef SBSApplicationLaunchingErrorString(int error);

typedef enum {
    SEARCH_EXACT_MATCH,
    SEARCH_PARTIAL_MATCH,
    SEARCH_CASE_INSENSITIVE
} SearchMode;

typedef struct {
    CFStringRef bundleIdentifier;
    CFStringRef displayName;
    CFStringRef path;
} ApplicationInfo;

CFArrayRef SearchApplications(CFStringRef searchTerm, SearchMode mode) {
    CFMutableArrayRef matchedApps = CFArrayCreateMutable(NULL, 0, NULL);
    
    id workspace = ((id (*)(id, SEL))objc_msgSend)(objc_getClass("LSApplicationWorkspace"), sel_registerName("defaultWorkspace"));
    NSArray *apps = ((NSArray *(*)(id, SEL))objc_msgSend)(workspace, sel_registerName("allApplications"));

    for (id app in apps) {
        CFStringRef displayName = ((CFStringRef (*)(id, SEL))objc_msgSend)(app, sel_registerName("localizedName"));
        CFStringRef bundleID = ((CFStringRef (*)(id, SEL))objc_msgSend)(app, sel_registerName("bundleIdentifier"));
        
        Boolean matchFound = false;
        
        switch(mode) {
            case SEARCH_EXACT_MATCH:
                matchFound = (CFStringCompare(displayName, searchTerm, 0) == kCFCompareEqualTo);
                break;
            
            case SEARCH_PARTIAL_MATCH:
                matchFound = (CFStringFind(displayName, searchTerm, kCFCompareAnchored).location != kCFNotFound);
                break;
            
            case SEARCH_CASE_INSENSITIVE:
                matchFound = (CFStringFindWithOptions(displayName, searchTerm, 
                                                      CFRangeMake(0, CFStringGetLength(displayName)), 
                                                      kCFCompareCaseInsensitive, 
                                                      NULL) != 0);
                break;
        }
        
        if (matchFound) {
            ApplicationInfo *appInfo = malloc(sizeof(ApplicationInfo));
            appInfo->bundleIdentifier = CFRetain(bundleID);
            appInfo->displayName = CFRetain(displayName);
            
            id url = ((id (*)(id, SEL))objc_msgSend)(app, sel_registerName("bundleURL"));
            CFStringRef path = ((CFStringRef (*)(id, SEL))objc_msgSend)(url, sel_registerName("path"));
            appInfo->path = CFRetain(path);
            
            CFArrayAppendValue(matchedApps, appInfo);
        }
    }
    
    return matchedApps;
}

void PrintApplicationResults(CFArrayRef results) {
    CFIndex count = CFArrayGetCount(results);
    printf("Found %ld applications:\n", count);
    
    for (CFIndex i = 0; i < count; i++) {
        ApplicationInfo *appInfo = (ApplicationInfo *)CFArrayGetValueAtIndex(results, i);
        
        char bundleIDStr[256], displayNameStr[256], pathStr[1024];
        CFStringGetCString(appInfo->bundleIdentifier, bundleIDStr, sizeof(bundleIDStr), kCFStringEncodingUTF8);
        CFStringGetCString(appInfo->displayName, displayNameStr, sizeof(displayNameStr), kCFStringEncodingUTF8);
        CFStringGetCString(appInfo->path, pathStr, sizeof(pathStr), kCFStringEncodingUTF8);
        
        printf("%ld. Name: %s\n   Bundle ID: %s\n   Path: %s\n\n",
               i+1, displayNameStr, bundleIDStr, pathStr);
    }
}

void CleanupSearchResults(CFArrayRef results) {
    CFIndex count = CFArrayGetCount(results);
    for (CFIndex i = 0; i < count; i++) {
        ApplicationInfo *appInfo = (ApplicationInfo *)CFArrayGetValueAtIndex(results, i);
        CFRelease(appInfo->bundleIdentifier);
        CFRelease(appInfo->displayName);
        CFRelease(appInfo->path);
        free(appInfo);
    }
    CFRelease(results);
}

CFStringRef GetBundleIdentifier(CFStringRef searchTerm) {
    CFArrayRef exactResults = SearchApplications(searchTerm, SEARCH_EXACT_MATCH);
    CFArrayRef partialResults = SearchApplications(searchTerm, SEARCH_PARTIAL_MATCH);
    CFArrayRef caseInsensitiveResults = SearchApplications(searchTerm, SEARCH_CASE_INSENSITIVE);
    
    CFStringRef bundleID = NULL;
    if (CFArrayGetCount(exactResults) > 0) {
        ApplicationInfo *appInfo = (ApplicationInfo *)CFArrayGetValueAtIndex(exactResults, 0);
        bundleID = CFRetain(appInfo->bundleIdentifier);
    }
    else if (CFArrayGetCount(partialResults) > 0) {
        ApplicationInfo *appInfo = (ApplicationInfo *)CFArrayGetValueAtIndex(partialResults, 0);
        bundleID = CFRetain(appInfo->bundleIdentifier);
    }
    else if (CFArrayGetCount(caseInsensitiveResults) > 0) {
        ApplicationInfo *appInfo = (ApplicationInfo *)CFArrayGetValueAtIndex(caseInsensitiveResults, 0);
        bundleID = CFRetain(appInfo->bundleIdentifier);
    }

    CleanupSearchResults(exactResults);
    CleanupSearchResults(partialResults);
    CleanupSearchResults(caseInsensitiveResults);
    
    return bundleID;
}

void ListAllApplications() {
    id workspace = ((id (*)(id, SEL))objc_msgSend)(objc_getClass("LSApplicationWorkspace"), sel_registerName("defaultWorkspace"));
    NSArray *apps = ((NSArray *(*)(id, SEL))objc_msgSend)(workspace, sel_registerName("allApplications"));

    printf("Installed applications:\n\n");
    CFIndex index = 1;
    for (id app in apps) {
        CFStringRef displayName = ((CFStringRef (*)(id, SEL))objc_msgSend)(app, sel_registerName("localizedName"));
        CFStringRef bundleID = ((CFStringRef (*)(id, SEL))objc_msgSend)(app, sel_registerName("bundleIdentifier"));
        id url = ((id (*)(id, SEL))objc_msgSend)(app, sel_registerName("bundleURL"));
        CFStringRef path = ((CFStringRef (*)(id, SEL))objc_msgSend)(url, sel_registerName("path"));

        char displayNameStr[256], bundleIDStr[256], pathStr[1024];
        CFStringGetCString(displayName, displayNameStr, sizeof(displayNameStr), kCFStringEncodingUTF8);
        CFStringGetCString(bundleID, bundleIDStr, sizeof(bundleIDStr), kCFStringEncodingUTF8);
        CFStringGetCString(path, pathStr, sizeof(pathStr), kCFStringEncodingUTF8);

        printf("%ld. Name: %s\n   Bundle ID: %s\n   Path: %s\n\n", 
               index++, displayNameStr, bundleIDStr, pathStr);
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <application name or bundle identifier> | -l\n", argv[0]);
        return -1;
    }

    if (strcmp(argv[1], "-l") == 0) {
        // Option to list all installed applications
        ListAllApplications();
        return 0;
    }

    char combinedArgs[1024] = {0};
    for (int i = 1; i < argc; ++i) {
        strcat(combinedArgs, argv[i]);
        if (i < argc - 1) strcat(combinedArgs, " ");
    }

    CFStringRef input = CFStringCreateWithCString(NULL, combinedArgs, kCFStringEncodingUTF8);
    if (!input) {
        fprintf(stderr, "Could not create CFStringRef\n");
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
        fprintf(stderr, "Could not open application: %s. Error code: %i, ", combinedArgs, ret);
        CFShow(SBSApplicationLaunchingErrorString(ret));
    }

    CFRelease(input);
    return ret;
}
