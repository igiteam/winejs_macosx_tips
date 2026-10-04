#import "AppDelegate.h"
#import "SystemInfoOpener.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) SystemInfoOpener *opener;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.opener = [[SystemInfoOpener alloc] init];

    self.statusItem = [[NSStatusBar systemStatusBar]
                       statusItemWithLength:NSVariableStatusItemLength];

    // Menu bar image: use the app icon, sized for the menu bar.
    NSImage *icon = [self menuBarIcon];
    if (icon) {
        // icon.template = NO;                  // keep original colors
        icon.template = YES;   // let macOS adapt to light/dark menu bar
        icon.size = NSMakeSize(22, 22);
        self.statusItem.button.image = icon;
        self.statusItem.button.imagePosition = NSImageOnly;
        self.statusItem.button.toolTip = @"Open System Information";
    } else {
        self.statusItem.button.title = @"🖥";  // last-resort fallback
    }

    // Left click AND right click both fire the same action.
    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(statusItemClicked:);
    [self.statusItem.button sendActionOn:(NSEventMaskLeftMouseUp |
                                           NSEventMaskRightMouseUp)];
}

- (NSImage *)menuBarIcon {
    NSBundle *b = [NSBundle mainBundle];

    NSString *p2x = [b pathForResource:@"menubar@2x" ofType:@"png"];
    NSString *p1x = [b pathForResource:@"menubar"    ofType:@"png"];

    NSImage *img = nil;
    if (p2x) {
        img = [[NSImage alloc] initWithContentsOfFile:p2x];
        if (img) [img setSize:NSMakeSize(22, 22)];
    }
    if (!img && p1x) {
        img = [[NSImage alloc] initWithContentsOfFile:p1x];
        if (img) [img setSize:NSMakeSize(22, 22)];
    }
    return img;
}

- (void)statusItemClicked:(id)sender {
    NSString *err = nil;
    BOOL ok = [self.opener openSystemInfoWithError:&err];
    if (!ok) {
        NSLog(@"[SystemInfoOpener] %@", err);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *a = [[NSAlert alloc] init];
            a.messageText = @"Couldn't open System Information";
            a.informativeText = err ?: @"Unknown error.";
            [a addButtonWithTitle:@"OK"];
            [a runModal];
        });
    }
}

@end
