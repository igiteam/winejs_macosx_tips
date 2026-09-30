#import "SystemInfoOpener.h"
#import <AppKit/AppKit.h>

@implementation SystemInfoOpener

- (BOOL)openSystemInfoWithError:(NSString **)errorOut {
    // Path to System Information.app.
    // Launching it with /usr/bin/open is exactly what double-clicking it does.
    NSString *systemInfoPath =
        @"/System/Applications/Utilities/System Information.app";

    if (![[NSFileManager defaultManager] fileExistsAtPath:systemInfoPath]) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:
                @"System Information.app not found at expected path:\n%@", systemInfoPath];
        }
        return NO;
    }

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/open";
    task.arguments  = @[systemInfoPath];

    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        if (errorOut) *errorOut = [NSString stringWithFormat:
            @"Failed to launch /usr/bin/open: %@", e.reason];
        return NO;
    }

    if (task.terminationStatus != 0) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:
                @"/usr/bin/open exited with status %d", task.terminationStatus];
        }
        return NO;
    }
    return YES;
}

@end
