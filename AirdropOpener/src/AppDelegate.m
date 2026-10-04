#import "AppDelegate.h"
#import "AirDropOpener.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) AirDropOpener *opener;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSLog(@"[AirDropOpener] didFinishLaunching");

    self.opener = [[AirDropOpener alloc] init];

    self.statusItem = [[NSStatusBar systemStatusBar]
                       statusItemWithLength:NSSquareStatusItemLength];

    // ---- Menu bar image: use the app icon ----
    NSImage *icon = [self menuBarIcon];
    if (icon) {
        // icon.template = NO;                  // keep original colors
        icon.template = YES;   // let macOS adapt to light/dark menu bar
        icon.size = NSMakeSize(18, 18);      // square, fits menu bar height
        self.statusItem.button.image = icon;
        self.statusItem.button.imagePosition = NSImageOnly;
        NSLog(@"[AirDropOpener] using PNG icon, size=%.0fx%.0f",
              icon.size.width, icon.size.height);
    } else {
        self.statusItem.button.title = @"📡";
        NSLog(@"[AirDropOpener] icon missing — using glyph fallback");
    }

    self.statusItem.button.toolTip = @"Open AirDrop";
    self.statusItem.visible = YES;

    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(clicked:);
    [self.statusItem.button sendActionOn:(NSEventMaskLeftMouseUp |
                                           NSEventMaskRightMouseUp)];

    NSLog(@"[AirDropOpener] setup complete");
}

- (NSImage *)menuBarIcon {
    NSBundle *b = [NSBundle mainBundle];

    NSString *p2x = [b pathForResource:@"menubar@2x" ofType:@"png"];
    NSString *p1x = [b pathForResource:@"menubar"    ofType:@"png"];

    NSLog(@"[AirDropOpener] p2x=%s p1x=%s",
          p2x ? [p2x UTF8String] : "(nil)",
          p1x ? [p1x UTF8String] : "(nil)");

    NSImage *img = nil;
    if (p2x) {
        img = [[NSImage alloc] initWithContentsOfFile:p2x];
    }
    if (!img && p1x) {
        img = [[NSImage alloc] initWithContentsOfFile:p1x];
    }

    if (img && (img.size.width < 1 || img.size.height < 1)) {
        NSLog(@"[AirDropOpener] image loaded but zero-sized — discarding");
        img = nil;
    }
    return img;
}

- (void)clicked:(id)sender {
    NSLog(@"[AirDropOpener] clicked!");
    [self.opener openAirDrop];
}

@end
