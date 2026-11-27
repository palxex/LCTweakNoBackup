// LCTweakNoBackup
//
// A LiveContainer "tweak to self" that marks LiveContainer's own Documents
// directory as excluded from iCloud/iTunes backup, so that re-installable
// guest app bundles stop eating the user's iCloud quota.
//
// Why this works: LCBootstrap dlopens Frameworks/TweakLoader.dylib into
// LiveContainer's own process when the "Load tweaks to self" setting is on,
// and TweakLoader then dlopens every dylib sitting in the global tweak folder
// (Documents/Tweaks). This library is one of those dylibs.
//
// Context discrimination follows LCTaskForPIDTweak's pattern: LCUtils only
// exists in LiveContainer's own process, so if it is missing we were injected
// into a guest app and must do nothing.
//
// Control:
//   Documents/turniCloudBackupOnAgain.flag   absent (default) -> backup OFF
//                                            present          -> backup ON
// The flag file only exists locally; it is never backed up, which is fine
// because it is a switch, not data.
//
// No app rebuild required. Drop the built dylib into Documents/Tweaks,
// sign tweaks from LiveContainer's Tweaks screen, enable "Load tweaks to self",
// then restart LiveContainer.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSString *const kLCTNBFlagName = @"turniCloudBackupOnAgain.flag";
static NSString *const kLCTNBLogPrefix = @"[LCTweakNoBackup]";

#pragma mark - context

/// LCUtils lives in LiveContainerSwiftUI.framework, which is only linked into
/// LiveContainer's own process. Guest apps never have it.
static BOOL LCTNBIsLiveContainerHost(void) {
    return NSClassFromString(@"LCUtils") != nil;
}

/// "Load tweaks to self" can also inject us into PlugIns/LiveProcess.appex,
/// whose NSDocumentDirectory is a different container. Don't touch anything there.
static BOOL LCTNBIsLiveProcessAppex(void) {
    return [NSBundle.mainBundle.bundlePath hasSuffix:@"PlugIns/LiveProcess.appex"];
}

static NSURL *LCTNBDocumentsURL(void) {
    return [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                inDomains:NSUserDomainMask].lastObject;
}

#pragma mark - xattr

static void LCTNBSetExcluded(NSURL *url, BOOL excluded) {
    if (url == nil) {
        return;
    }
    BOOL isDir = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&isDir]) {
        NSLog(@"%@ skip %@ (does not exist)", kLCTNBLogPrefix, url.path);
        return;
    }

    NSError *error = nil;
    if (![(NSURL *)url setResourceValue:@(excluded)
                                 forKey:NSURLIsExcludedFromBackupKey
                                  error:&error]) {
        NSLog(@"%@ FAILED %@ -> %@: %@", kLCTNBLogPrefix, url.path,
              excluded ? @"excluded" : @"included", error);
        return;
    }

    // read back so the log proves what actually landed on disk
    id value = nil;
    [(NSURL *)url getResourceValue:&value forKey:NSURLIsExcludedFromBackupKey error:nil];
    NSLog(@"%@ OK %@ -> excluded=%@ (readback=%@)", kLCTNBLogPrefix, url.path,
          excluded ? @"YES" : @"NO", value);
}

#pragma mark - entry point

__attribute__((constructor))
static void LCTweakNoBackupInit(void) {
    if (!LCTNBIsLiveContainerHost()) {
        // Injected into a guest app: this tweak has nothing to do here.
        NSLog(@"%@ guest context, standing down", kLCTNBLogPrefix);
        return;
    }

    if (LCTNBIsLiveProcessAppex()) {
        NSLog(@"%@ running inside LiveProcess.appex, standing down", kLCTNBLogPrefix);
        return;
    }

    NSURL *documentsURL = LCTNBDocumentsURL();
    if (documentsURL == nil) {
        NSLog(@"%@ cannot resolve Documents, giving up", kLCTNBLogPrefix);
        return;
    }

    NSURL *flagURL = [documentsURL URLByAppendingPathComponent:kLCTNBFlagName
                                                   isDirectory:NO];
    BOOL backupOn = [NSFileManager.defaultManager fileExistsAtPath:flagURL.path];

    NSLog(@"%@ host context, %@ %@ -> backup %@", kLCTNBLogPrefix,
          kLCTNBFlagName, backupOn ? @"present" : @"absent",
          backupOn ? @"ON" : @"OFF");

    // A single syscall on the directory covers the whole subtree; no need to
    // walk the 17k files LiveContainer typically holds.
    LCTNBSetExcluded(documentsURL, !backupOn);
}
