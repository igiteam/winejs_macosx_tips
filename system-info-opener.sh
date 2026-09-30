#!/bin/bash
# AirdropOpener — menu-bar app. Click icon → Finder opens AirDrop.
# Uses the real app icon in the menu bar. No AppleScript — shells out to `open`.

set -e

APP_NAME="AirdropOpener"
BUNDLE_ID="com.igiteam.airdropopener"
SIGN_IDENTITY="MXFlowLocal"
LOG_FILE="$HOME/Library/Logs/AirdropOpener.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  AIRDROP OPENER — click menu bar icon → Finder opens AirDrop   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/src"
mkdir -p "$APP_NAME/public"
cd "$APP_NAME" || exit

# ===============================================
# ICON — used for BOTH the app icon AND the menu bar image
# ===============================================
echo -e "${CYAN}🎨 Getting icon...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ICON="$SCRIPT_DIR/airdrop-macbook.png"
ICON_URL="https://raw.githubusercontent.com/igiteam/winejs/refs/heads/main/images/airdrop-macbook.png"

if [ -f "$LOCAL_ICON" ] && [ -s "$LOCAL_ICON" ]; then
    echo "✅ Using local icon: $LOCAL_ICON"
    cp "$LOCAL_ICON" "public/app_icon.png"
else
    echo "   No local airdrop-macbook.png next to this script — downloading..."
    curl -f -s -L "$ICON_URL" -o "public/app_icon.png" || true
fi

ICON_OK=NO
if [ -f "public/app_icon.png" ] && [ -s "public/app_icon.png" ]; then
    if file "public/app_icon.png" | grep -qi "PNG image"; then
        ICON_OK=YES
    else
        echo -e "${YELLOW}⚠ Downloaded file is not a PNG (probably an error page). Discarding.${NC}"
        rm -f "public/app_icon.png"
    fi
fi

if [ "$ICON_OK" = "YES" ]; then
    ICONSET_DIR="public/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"; mkdir -p "$ICONSET_DIR"
    sips -z 16   16   "public/app_icon.png" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null 2>&1
    sips -z 32   32   "public/app_icon.png" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null 2>&1
    sips -z 32   32   "public/app_icon.png" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null 2>&1
    sips -z 64   64   "public/app_icon.png" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null 2>&1
    sips -z 128  128  "public/app_icon.png" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null 2>&1
    sips -z 256  256  "public/app_icon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256  256  "public/app_icon.png" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null 2>&1
    sips -z 512  512  "public/app_icon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512  512  "public/app_icon.png" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null 2>&1
    sips -z 1024 1024 "public/app_icon.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1
    if command -v iconutil &> /dev/null && \
       iconutil -c icns "$ICONSET_DIR" -o "public/app_icon.icns" 2>/dev/null; then
        echo "✅ .icns created"
    fi
    sips -z 44 44 "public/app_icon.png" --out "public/menubar@2x.png" >/dev/null 2>&1
    sips -z 22 22 "public/app_icon.png" --out "public/menubar.png"    >/dev/null 2>&1
    rm -rf "$ICONSET_DIR"
else
    echo -e "${YELLOW}⚠ No usable icon. Menu bar will show a colored dot as last resort.${NC}"
fi

# ===============================================
# SOURCE
# ===============================================

cat > "src/AirDropOpener.h" << 'EOF'
#import <Foundation/Foundation.h>
@interface AirDropOpener : NSObject
- (BOOL)openAirDropWithError:(NSString **)errorOut;
@end
EOF

cat > "src/AirDropOpener.m" << 'EOF'
#import "AirDropOpener.h"
#import <AppKit/AppKit.h>

@implementation AirDropOpener

- (BOOL)openAirDropWithError:(NSString **)errorOut {
    // Path to the AirDrop.app that lives inside Finder.app.
    // Launching it with /usr/bin/open is exactly what double-clicking it does.
    NSString *airdropPath =
        @"/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app";

    if (![[NSFileManager defaultManager] fileExistsAtPath:airdropPath]) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:
                @"AirDrop.app not found at expected path:\n%@", airdropPath];
        }
        return NO;
    }

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/open";
    task.arguments  = @[airdropPath];

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
EOF

cat > "src/AppDelegate.h" << 'EOF'
#import <Cocoa/Cocoa.h>
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end
EOF

cat > "src/AppDelegate.m" << 'EOF'
#import "AppDelegate.h"
#import "AirDropOpener.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) AirDropOpener *opener;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.opener = [[AirDropOpener alloc] init];

    self.statusItem = [[NSStatusBar systemStatusBar]
                       statusItemWithLength:NSVariableStatusItemLength];

    // Menu bar image: use the app icon, sized for the menu bar.
    NSImage *icon = [self menuBarIcon];
    if (icon) {
        icon.template = NO;                // keep original colors
        icon.size = NSMakeSize(22, 22);
        self.statusItem.button.image = icon;
        self.statusItem.button.imagePosition = NSImageOnly;
        self.statusItem.button.toolTip = @"Open AirDrop";
    } else {
        self.statusItem.button.title = @"🖱";  // last-resort fallback
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
    BOOL ok = [self.opener openAirDropWithError:&err];
    if (!ok) {
        NSLog(@"[AirDropOpener] %@", err);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *a = [[NSAlert alloc] init];
            a.messageText = @"Couldn't open AirDrop";
            a.informativeText = err ?: @"Unknown error.";
            [a addButtonWithTitle:@"OK"];
            [a runModal];
        });
    }
}

@end
EOF

cat > "src/main.m" << 'EOF'
#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
EOF

# ===============================================
# BUILD
# ===============================================

echo -e "${CYAN}🔨 Compiling...${NC}"

APP_BUNDLE="$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/"{MacOS,Resources}

cat > "Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>AirDrop Opener</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>app_icon</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
cp "Info.plist" "$APP_BUNDLE/Contents/"

[ -f "public/app_icon.icns" ] && cp "public/app_icon.icns" "$APP_BUNDLE/Contents/Resources/app_icon.icns" && echo "✅ App icon added"
[ -f "public/menubar.png"    ] && cp "public/menubar.png"    "$APP_BUNDLE/Contents/Resources/menubar.png"
[ -f "public/menubar@2x.png" ] && cp "public/menubar@2x.png" "$APP_BUNDLE/Contents/Resources/menubar@2x.png"

clang -framework Cocoa -framework Foundation -framework AppKit \
      -fobjc-arc -Wno-deprecated-declarations \
      -mmacosx-version-min=11.0 \
      -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" src/*.m 2> build_errors.log

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Compilation successful!${NC}"
    rm -f build_errors.log
else
    echo -e "${RED}❌ Compilation failed:${NC}"
    cat build_errors.log
    exit 1
fi

# ===============================================
# SIGN
# ===============================================
if security find-certificate -c "$SIGN_IDENTITY" >/dev/null 2>&1; then
    echo -e "${CYAN}🔏 Signing with $SIGN_IDENTITY${NC}"
    codesign --force --deep --sign "$SIGN_IDENTITY" \
             --identifier "$BUNDLE_ID" \
             --options runtime \
             "$APP_BUNDLE" 2>/dev/null || {
        echo -e "${YELLOW}⚠ Signing failed, falling back to ad-hoc${NC}"
        codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE" 2>/dev/null || true
    }
else
    echo -e "${YELLOW}⚠ Self-signed cert '$SIGN_IDENTITY' not found — using ad-hoc.${NC}"
    codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE" 2>/dev/null || true
fi
xattr -cr "$APP_BUNDLE"

# ===============================================
# INSTALL
# ===============================================
pkill -f "$HOME/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true

rm -rf "$HOME/Applications/$APP_BUNDLE"
mkdir -p "$HOME/Applications"
cp -R "$APP_BUNDLE" "$HOME/Applications/"

rm -f "$LOG_FILE"
touch "$LOG_FILE"

echo -e "\n${GREEN}✅ Built and installed to ~/Applications${NC}"
echo ""

open "$HOME/Applications/$APP_BUNDLE"

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                          HOW TO USE                            ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  1. Look at your MENU BAR (top right) for the AirDrop icon.   ║"
echo "║  2. Click it — LEFT or RIGHT, either works.                   ║"
echo "║  3. Finder opens its AirDrop window.                          ║"
echo "║                                                                ║"
echo "║  No permissions required — this just runs:                    ║"
echo "║    open /System/Library/CoreServices/Finder.app/…/AirDrop.app  ║"
echo "║                                                                ║"
echo "║  Log: cat $LOG_FILE"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"