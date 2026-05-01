#import <Cocoa/Cocoa.h>
#import <math.h>
#import <string.h>
#import <unistd.h>
#import <dlfcn.h>

typedef struct {
    CGFloat x;
    CGFloat y;
    CGFloat w;
    CGFloat h;
} Block;

typedef struct {
    BOOL exists;
    BOOL isHome;
    BOOL isFloor;
    CGFloat y;
    CGFloat minX;
    CGFloat maxX;
} Support;

static NSTimeInterval Now(void) {
    return [NSDate timeIntervalSinceReferenceDate];
}

static NSColor *Hex(NSString *hex) {
    NSString *text = [hex hasPrefix:@"#"] ? [hex substringFromIndex:1] : hex;
    unsigned int value = 0;
    [[NSScanner scannerWithString:text] scanHexInt:&value];
    return [NSColor colorWithCalibratedRed:((value >> 16) & 0xff) / 255.0
                                     green:((value >> 8) & 0xff) / 255.0
                                      blue:(value & 0xff) / 255.0
                                     alpha:1.0];
}

static NSColor *HexAlpha(NSString *hex, CGFloat alpha) {
    NSColor *base = Hex(hex);
    return [base colorWithAlphaComponent:alpha];
}

static CGFloat Clamp(CGFloat value, CGFloat min, CGFloat max) {
    return value < min ? min : (value > max ? max : value);
}

static CGFloat Lerp(CGFloat a, CGFloat b, CGFloat t) {
    return a + (b - a) * Clamp(t, 0, 1);
}

static CGFloat PartValue(CGFloat value, CGFloat min, CGFloat max) {
    return round(Lerp(min, max, Clamp(value, 0, 1)));
}

static NSColor *Blend(NSColor *a, NSColor *b, CGFloat t) {
    a = [a colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] ?: a;
    b = [b colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] ?: b;
    return [NSColor colorWithCalibratedRed:Lerp(a.redComponent, b.redComponent, t)
                                     green:Lerp(a.greenComponent, b.greenComponent, t)
                                      blue:Lerp(a.blueComponent, b.blueComponent, t)
                                     alpha:1.0];
}

static NSColor *HexOrFallback(NSString *hex, NSColor *fallback) {
    if (![hex isKindOfClass:NSString.class]) return fallback;
    NSString *text = [hex hasPrefix:@"#"] ? [hex substringFromIndex:1] : hex;
    if (text.length != 6) return fallback;
    unsigned int value = 0;
    if (![[NSScanner scannerWithString:text] scanHexInt:&value]) return fallback;
    return [NSColor colorWithCalibratedRed:((value >> 16) & 0xff) / 255.0
                                     green:((value >> 8) & 0xff) / 255.0
                                      blue:(value & 0xff) / 255.0
                                     alpha:1.0];
}

static NSString *HexStringFromColor(NSColor *color) {
    color = [color colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
    if (!color) return @"#FFFFFF";
    NSInteger r = (NSInteger)round(Clamp(color.redComponent, 0, 1) * 255.0);
    NSInteger g = (NSInteger)round(Clamp(color.greenComponent, 0, 1) * 255.0);
    NSInteger b = (NSInteger)round(Clamp(color.blueComponent, 0, 1) * 255.0);
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX", (long)r, (long)g, (long)b];
}

static NSString *HTMLEscape(NSString *string) {
    if (![string isKindOfClass:NSString.class]) return @"";
    NSMutableString *escaped = [string mutableCopy];
    [escaped replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"'" withString:@"&#39;" options:0 range:NSMakeRange(0, escaped.length)];
    return escaped;
}

@class DragonController;

@interface DragonWindow : NSWindow
@end

@implementation DragonWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

@interface FlippedControlsView : NSView
@end

@implementation FlippedControlsView
- (BOOL)isFlipped { return YES; }
@end

@interface DragonView : NSView
@property (nonatomic, weak) DragonController *controller;
- (void)drawShadow;
- (void)drawDragonWithBob:(CGFloat)bob run:(CGFloat)run mouthOpen:(BOOL)mouthOpen flying:(BOOL)flying moving:(BOOL)moving sitting:(BOOL)sitting;
@end

@interface HomeView : NSView
@property (nonatomic, weak) DragonController *controller;
@end

@interface HabitatView : NSView
@property (nonatomic, weak) DragonController *controller;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSSlider *> *creatorSliders;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSTextField *> *creatorValueLabels;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSPopUpButton *> *creatorPopups;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSColorWell *> *creatorColorWells;
@property (nonatomic, strong) NSScrollView *creatorScrollView;
@property (nonatomic, strong) FlippedControlsView *creatorContentView;
@property (nonatomic, strong) NSTextField *nameField;
@property (nonatomic, strong) NSPopUpButton *foodPopup;
@property (nonatomic, strong) NSPopUpButton *colorPopup;
@property (nonatomic, strong) NSPopUpButton *appPopup;
@property (nonatomic, strong) NSTextField *configNameField;
@property (nonatomic, strong) NSPopUpButton *configPopup;
@property NSInteger draggingCavePieceIndex;
@property NSInteger selectedCavePieceIndex;
@property NSPoint cavePieceDragOffset;
- (void)buildCreatorControls;
- (void)syncControlsFromController;
@end

@interface DragonController : NSObject
@property (nonatomic, strong) DragonWindow *window;
@property (nonatomic, strong) DragonView *view;
@property (nonatomic, strong) DragonWindow *homeWindow;
@property (nonatomic, strong) HomeView *homeView;
@property (nonatomic, strong) NSWindow *habitatWindow;
@property (nonatomic, strong) HabitatView *habitatView;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSTimer *timer;
@property CGFloat width;
@property CGFloat height;
@property CGFloat homeWidth;
@property CGFloat homeHeight;
@property CGFloat homeX;
@property CGFloat homeY;
@property CGFloat x;
@property CGFloat y;
@property CGFloat vx;
@property CGFloat vy;
@property CGFloat targetX;
@property CGFloat targetY;
@property CGFloat facing;
@property CGFloat phase;
@property CGFloat habitatX;
@property CGFloat habitatY;
@property CGFloat habitatVX;
@property CGFloat habitatVY;
@property CGFloat habitatTargetX;
@property CGFloat habitatTargetY;
@property CGFloat habitatFacing;
@property NSTimeInterval lastTick;
@property NSTimeInterval nextDecision;
@property NSTimeInterval nextChirp;
@property NSTimeInterval nextBoundsCheck;
@property NSTimeInterval habitatNextDecision;
@property NSTimeInterval habitatFlightUntil;
@property NSRect screenFrame;
@property (nonatomic, copy) NSString *bubbleText;
@property NSTimeInterval bubbleUntil;
@property NSTimeInterval mouthUntil;
@property CGFloat hunger;
@property CGFloat affection;
@property CGFloat energy;
@property CGFloat curiosity;
@property CGFloat confidence;
@property CGFloat levelProgress;
@property CGFloat warmExposure;
@property CGFloat coolExposure;
@property CGFloat natureExposure;
@property CGFloat darkExposure;
@property CGFloat creativeExposure;
@property CGFloat codeExposure;
@property CGFloat partBodyLength;
@property CGFloat partBodyHeight;
@property CGFloat partHeadSize;
@property CGFloat partSnoutLength;
@property CGFloat partHornLength;
@property CGFloat partWingSize;
@property CGFloat partTailLength;
@property CGFloat partLegLength;
@property CGFloat partNeckLength;
@property CGFloat partClawLength;
@property CGFloat partCrestSize;
@property CGFloat partEyeSize;
@property CGFloat partBellySize;
@property CGFloat partCheekSize;
@property CGFloat patternDensity;
@property CGFloat patternColorCount;
@property NSTimeInterval birthTime;
@property NSTimeInterval lastSaved;
@property NSTimeInterval nextSensorTick;
@property (nonatomic, copy) NSString *creatureName;
@property (nonatomic, copy) NSString *lifeStage;
@property (nonatomic, copy) NSString *personality;
@property (nonatomic, copy) NSString *favoriteFood;
@property (nonatomic, copy) NSString *favoriteColor;
@property (nonatomic, copy) NSString *lastAppName;
@property (nonatomic, copy) NSString *hornType;
@property (nonatomic, copy) NSString *eyeShape;
@property (nonatomic, copy) NSString *stance;
@property (nonatomic, copy) NSString *tailTipType;
@property (nonatomic, copy) NSString *wingType;
@property (nonatomic, copy) NSString *patternType;
@property (nonatomic, copy) NSString *colorOutline;
@property (nonatomic, copy) NSString *colorDeepOutline;
@property (nonatomic, copy) NSString *colorBody;
@property (nonatomic, copy) NSString *colorHighlight;
@property (nonatomic, copy) NSString *colorBelly;
@property (nonatomic, copy) NSString *colorWing;
@property (nonatomic, copy) NSString *colorHorn;
@property (nonatomic, copy) NSString *colorCrest;
@property (nonatomic, copy) NSString *colorEye;
@property (nonatomic, copy) NSString *colorCheek;
@property (nonatomic, copy) NSString *colorClaw;
@property (nonatomic, copy) NSString *colorPattern1;
@property (nonatomic, copy) NSString *colorPattern2;
@property (nonatomic, copy) NSString *colorPattern3;
@property (nonatomic, copy) NSString *colorFlameOuter;
@property (nonatomic, copy) NSString *colorFlameMid;
@property (nonatomic, copy) NSString *colorFlameCore;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *particles;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *cavePieces;
@property (nonatomic, strong) NSMutableArray<NSString *> *recentApps;
@property (nonatomic, strong) NSMutableArray<NSSound *> *activeSounds;
@property BOOL soundOn;
@property BOOL flying;
@property BOOL seekingHome;
@property BOOL dragging;
@property BOOL draggingHome;
@property BOOL hoveringDragon;
@property BOOL grabbingDragon;
@property BOOL insideHome;
@property BOOL homeWasDragged;
@property BOOL hasCustomHomePosition;
@property BOOL menuBarHome;
@property BOOL onboardingComplete;
@property BOOL habitatFlying;
@property BOOL sitting;
@property NSTimeInterval flightUntil;
@property NSTimeInterval sitUntil;
@property NSPoint dragStartMouse;
@property NSPoint dragStartOrigin;
@property NSPoint homeDragStartMouse;
@property NSPoint homeDragStartOrigin;
@property NSPoint hoverPoint;
@property BOOL wasDragged;
- (void)show;
- (void)showHome;
- (void)loadCreature;
- (void)saveCreature;
- (NSDictionary *)creatureSnapshot;
- (void)showOnboardingIfNeeded;
- (void)showOnboarding:(id)sender;
- (void)applyPaletteNamed:(NSString *)paletteName;
- (void)shareSnoot;
- (void)copyShareImage;
- (NSURL *)exportShareSnapshot;
- (NSURL *)exportShareImage;
- (BOOL)exportLandingSpritesToDirectory:(NSURL *)directoryURL;
- (CGFloat)ageDays;
- (void)updateDerivedTraits;
- (void)updateMenuBarBurrow;
- (void)toggleMenuBarBurrow;
- (NSRect)menuBarBurrowFrame;
- (void)startDragAt:(NSPoint)point;
- (void)dragTo:(NSPoint)point;
- (void)finishDragAt:(NSPoint)point;
- (void)pet;
- (void)sit;
- (void)feed;
- (void)feedBerry;
- (void)feedMeat;
- (void)feedGreens;
- (void)feedSweet;
- (void)bubble:(NSString *)text seconds:(NSTimeInterval)seconds;
- (NSMenu *)makeMenu;
- (NSMenu *)makeCreatorMenu;
- (void)startHomeDragAt:(NSPoint)point;
- (void)dragHomeTo:(NSPoint)point;
- (void)finishHomeDragAt:(NSPoint)point;
- (void)goHome;
- (void)openHabitat;
- (void)leaveHome;
- (void)toggleHomeDashboard;
- (void)syncHabitatControls;
- (CGFloat)creatorValueForKey:(NSString *)key;
- (void)setCreatorValue:(CGFloat)value forKey:(NSString *)key;
- (NSString *)creatorStringForKey:(NSString *)key;
- (void)setCreatorString:(NSString *)value forKey:(NSString *)key;
- (NSColor *)dragonColorForKey:(NSString *)key fallback:(NSColor *)fallback;
- (NSString *)dragonColorHexForKey:(NSString *)key;
- (void)setDragonColor:(NSColor *)color forKey:(NSString *)key;
- (void)resetDragonColors;
- (NSArray<NSString *> *)configurationNames;
- (void)saveCurrentConfigurationNamed:(NSString *)name;
- (void)loadConfigurationNamed:(NSString *)name;
- (void)resetCavePieces;
- (void)syncDesktopVisibilityForLocation;
- (BOOL)canFly;
- (Support)homeSupport;
- (CGFloat)footOffset;
- (Support)supportBelowFootWithMargin:(CGFloat)margin;
@end

@implementation DragonView

- (BOOL)isFlipped {
    return YES;
}

- (NSRect)dragonInteractionRect {
    return NSMakeRect(12, 18, self.bounds.size.width - 24, self.bounds.size.height - 32);
}

- (void)updateTrackingAreas {
    for (NSTrackingArea *area in self.trackingAreas.copy) {
        [self removeTrackingArea:area];
    }
    NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect;
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil]];
    [super updateTrackingAreas];
}

- (NSView *)hitTest:(NSPoint)point {
    DragonController *controller = self.controller;
    if (!controller) return nil;
    NSRect dragonRect = [self dragonInteractionRect];
    if (NSPointInRect(point, dragonRect)) {
        return self;
    }
    return nil;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor clearColor] setFill];
    NSRectFill(dirtyRect);

    DragonController *controller = self.controller;
    if (!controller) return;

    CGFloat bob = round(sin(controller.phase * 0.52) * 1.15);
    CGFloat run = sin(controller.phase * 0.52);
    BOOL mouthOpen = controller.mouthUntil > Now();
    BOOL moving = !controller.flying && !controller.sitting && hypot(controller.vx, controller.vy) > 0.22;

    [self drawDragonWithBob:bob run:run mouthOpen:mouthOpen flying:controller.flying moving:moving sitting:controller.sitting];
    [self drawParticles];

    if (controller.hoveringDragon || controller.grabbingDragon) {
        [self drawPixelHandAt:controller.hoverPoint grabbing:controller.grabbingDragon];
    }
}

- (void)mouseDown:(NSEvent *)event {
    if (event.clickCount >= 2) {
        [self.controller feed];
        return;
    }
    self.controller.grabbingDragon = YES;
    self.controller.hoverPoint = [self convertPoint:event.locationInWindow fromView:nil];
    self.needsDisplay = YES;
    [self.controller startDragAt:[NSEvent mouseLocation]];
}

- (void)mouseDragged:(NSEvent *)event {
    self.controller.hoverPoint = [self convertPoint:event.locationInWindow fromView:nil];
    self.needsDisplay = YES;
    [self.controller dragTo:[NSEvent mouseLocation]];
}

- (void)mouseUp:(NSEvent *)event {
    self.controller.grabbingDragon = NO;
    self.controller.hoverPoint = [self convertPoint:event.locationInWindow fromView:nil];
    self.needsDisplay = YES;
    [self.controller finishDragAt:[NSEvent mouseLocation]];
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    self.controller.hoverPoint = point;
    self.controller.hoveringDragon = NSPointInRect(point, [self dragonInteractionRect]);
    self.needsDisplay = YES;
}

- (void)mouseEntered:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    self.controller.hoverPoint = point;
    self.controller.hoveringDragon = NSPointInRect(point, [self dragonInteractionRect]);
    self.needsDisplay = YES;
}

- (void)mouseExited:(NSEvent *)event {
    self.controller.hoveringDragon = NO;
    self.controller.grabbingDragon = NO;
    self.needsDisplay = YES;
}

- (void)rightMouseDown:(NSEvent *)event {
    NSMenu *menu = [self.controller makeMenu];
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

- (void)keyDown:(NSEvent *)event {
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    if ([key isEqualToString:@"q"] || event.keyCode == 53) {
        [NSApp terminate:nil];
    } else if ([key isEqualToString:@"f"]) {
        [self.controller feed];
    } else if ([key isEqualToString:@"h"]) {
        [self.controller goHome];
    } else if ([key isEqualToString:@"p"]) {
        [self.controller pet];
    } else if ([key isEqualToString:@"s"]) {
        [self.controller sit];
    } else {
        [super keyDown:event];
    }
}

- (void)drawBlockX:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h color:(NSColor *)fill ox:(CGFloat)ox oy:(CGFloat)oy {
    CGFloat scale = 4.0;
    CGFloat drawX = self.controller.facing < 0
        ? self.bounds.size.width - (ox + (x + w) * scale)
        : ox + x * scale;
    NSRect rect = NSMakeRect(drawX, oy + y * scale, w * scale, h * scale);
    [fill setFill];
    NSRectFill(rect);
}

- (void)drawBlocks:(const Block *)blocks count:(NSUInteger)count color:(NSColor *)fill ox:(CGFloat)ox oy:(CGFloat)oy {
    for (NSUInteger i = 0; i < count; i++) {
        [self drawBlockX:blocks[i].x y:blocks[i].y w:blocks[i].w h:blocks[i].h color:fill ox:ox oy:oy];
    }
}

- (void)drawHandBlockX:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h color:(NSColor *)fill ox:(CGFloat)ox oy:(CGFloat)oy {
    CGFloat scale = 3.0;
    [fill setFill];
    NSRectFill(NSMakeRect(ox + x * scale, oy + y * scale, w * scale, h * scale));
}

- (void)drawPixelHandAt:(NSPoint)point grabbing:(BOOL)grabbing {
    CGFloat ox = Clamp(point.x - 10, 2, self.bounds.size.width - 40);
    CGFloat oy = Clamp(point.y - 8, 2, self.bounds.size.height - 42);
    NSColor *ink = Hex(@"#332f3a");
    NSColor *white = Hex(@"#ffffff");
    NSColor *shade = Hex(@"#dfe4ee");

    const Block openInk[] = {{1,0,3,8},{4,0,3,8},{7,1,3,7},{10,2,3,6},{0,6,14,9},{13,8,4,4},{3,15,8,3}};
    const Block openWhite[] = {{2,1,1,7},{5,1,1,7},{8,2,1,6},{11,3,1,5},{1,7,12,7},{14,9,2,2},{4,14,6,2}};
    const Block grabInk[] = {{2,2,3,6},{5,1,3,6},{8,2,3,6},{11,4,3,5},{0,7,15,8},{3,15,9,3}};
    const Block grabWhite[] = {{3,3,1,4},{6,2,1,4},{9,3,1,4},{12,5,1,3},{1,8,13,6},{4,14,7,2}};

    const Block *inkBlocks = grabbing ? grabInk : openInk;
    const Block *whiteBlocks = grabbing ? grabWhite : openWhite;
    NSUInteger inkCount = grabbing ? 6 : 7;
    NSUInteger whiteCount = grabbing ? 6 : 7;
    for (NSUInteger i = 0; i < inkCount; i++) {
        [self drawHandBlockX:inkBlocks[i].x y:inkBlocks[i].y w:inkBlocks[i].w h:inkBlocks[i].h color:ink ox:ox oy:oy];
    }
    for (NSUInteger i = 0; i < whiteCount; i++) {
        [self drawHandBlockX:whiteBlocks[i].x y:whiteBlocks[i].y w:whiteBlocks[i].w h:whiteBlocks[i].h color:white ox:ox oy:oy];
    }
    [self drawHandBlockX:2 y:11 w:10 h:1 color:shade ox:ox oy:oy];
    [self drawHandBlockX:4 y:15 w:6 h:1 color:shade ox:ox oy:oy];
    if (grabbing) {
        [self drawHandBlockX:2 y:10 w:11 h:1 color:shade ox:ox oy:oy];
    }
}

- (void)drawShadow {
    CGFloat groundY = self.bounds.size.height - ([self.controller footOffset] + 14.0);
    [HexAlpha(@"#52636b", 0.35) setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(82, groundY, 126, 13)] fill];
    [HexAlpha(@"#6f858c", 0.28) setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(108, groundY + 2, 74, 8)] fill];
}

- (void)drawDragonWithBob:(CGFloat)bob run:(CGFloat)run mouthOpen:(BOOL)mouthOpen flying:(BOOL)flying moving:(BOOL)moving sitting:(BOOL)sitting {
    CGFloat ox = 32;
    CGFloat oy = 42 + bob;
    BOOL hasWings = ![self.controller.wingType isEqualToString:@"no wings"];
    BOOL activeFlight = hasWings && flying;
    CGFloat flap = activeFlight ? round(sin(self.controller.phase * 7.8) * 4.0) : 0;
    CGFloat walkCycle = fmod(self.controller.phase * 0.075, 1.0);
    CGFloat maturity = Clamp([self.controller ageDays] / 60.0, 0, 1);
    BOOL biped = [self.controller.stance isEqualToString:@"two legs"];
    BOOL menacing = [self.controller.eyeShape isEqualToString:@"menacing"];
    BOOL neutralEye = [self.controller.eyeShape isEqualToString:@"neutral"];

    CGFloat bodyLong = PartValue(self.controller.partBodyLength, -2, 5);
    CGFloat bodyTall = PartValue(self.controller.partBodyHeight, -1, 4);
    CGFloat headGrow = PartValue(self.controller.partHeadSize, -1, 3);
    CGFloat snout = MAX(maturity > 0.35 ? 2 : 1, PartValue(self.controller.partSnoutLength, 1, 8));
    CGFloat hornLen = MAX(maturity > 0.18 ? 2 : 1, PartValue(self.controller.partHornLength, 1, 8));
    CGFloat neckLen = PartValue(self.controller.partNeckLength, 0, 5);
    CGFloat wingScale = PartValue(self.controller.partWingSize, 0, 4);
    CGFloat tailLen = PartValue(self.controller.partTailLength, 8, 18);
    CGFloat legLen = PartValue(self.controller.partLegLength, 4, 10);
    CGFloat clawLen = PartValue(self.controller.partClawLength, 1, 4);
    CGFloat crestCount = PartValue(self.controller.partCrestSize, 1, 7);
    CGFloat eyeSize = PartValue(self.controller.partEyeSize, 3, 6);
    CGFloat bellySize = PartValue(self.controller.partBellySize, 6, 13);
    CGFloat cheekSize = PartValue(self.controller.partCheekSize, 1, 5);
    CGFloat patternDensity = Clamp(self.controller.patternDensity, 0, 1);
    NSInteger patternColors = (NSInteger)round(Clamp(self.controller.patternColorCount, 1, 3));

    CGFloat bodyX = 16;
    CGFloat bodyY = biped ? 11 : 17;
    CGFloat bodyW = 19 + bodyLong;
    CGFloat bodyH = biped ? 18 + bodyTall : 12 + bodyTall;
    if (sitting && !biped) {
        bodyY += 4;
        bodyH += 1;
    }
    CGFloat shoulderX = bodyX + bodyW - 4;
    CGFloat shoulderY = bodyY + 3;
    CGFloat headX = bodyX + bodyW + 1 + neckLen * 0.62;
    CGFloat headY = 5 - headGrow - neckLen * 0.24;
    if (sitting && !biped) headY += 2;
    CGFloat headW = 15 + headGrow;
    CGFloat headH = 14 + headGrow;
    CGFloat tailStartX = bodyX + 2;
    CGFloat tailStartY = bodyY + bodyH - 6;

    NSColor *ink = [self.controller dragonColorForKey:@"outline" fallback:Hex(@"#171126")];
    NSColor *deepInk = [self.controller dragonColorForKey:@"deepOutline" fallback:Hex(@"#080710")];
    NSColor *base = [self.controller dragonColorForKey:@"body" fallback:Hex(@"#67d8f4")];
    CGFloat driftStrength = MIN(0.07, MAX(MAX(self.controller.warmExposure, self.controller.coolExposure), MAX(MAX(self.controller.natureExposure, self.controller.darkExposure), MAX(self.controller.creativeExposure, self.controller.codeExposure))) * 0.055);
    if (driftStrength > 0.01) {
        NSColor *drift = Hex(@"#67D8F4");
        CGFloat strongest = self.controller.coolExposure;
        if (self.controller.warmExposure > strongest) { strongest = self.controller.warmExposure; drift = Hex(@"#D51D2E"); }
        if (self.controller.natureExposure > strongest) { strongest = self.controller.natureExposure; drift = Hex(@"#63B86F"); }
        if (self.controller.darkExposure > strongest) { strongest = self.controller.darkExposure; drift = Hex(@"#4B315D"); }
        if (self.controller.creativeExposure > strongest) { strongest = self.controller.creativeExposure; drift = Hex(@"#D65CFF"); }
        if (self.controller.codeExposure > strongest) { strongest = self.controller.codeExposure; drift = Hex(@"#6CE0FF"); }
        base = Blend(base, drift, driftStrength);
    }
    NSColor *body = base;
    NSColor *bodyDark = Blend(Hex(@"#1b1530"), body, 0.42);
    NSColor *bodyMid = Blend(bodyDark, body, 0.55);
    NSColor *bodyLight = [self.controller dragonColorForKey:@"highlight" fallback:Blend(Hex(@"#f4a8ff"), body, 0.36)];
    NSColor *belly = [self.controller dragonColorForKey:@"belly" fallback:Hex(@"#ffdc75")];
    NSColor *bellyDark = Blend(Hex(@"#8d43c4"), belly, 0.35);
    NSColor *wing = [self.controller dragonColorForKey:@"wing" fallback:Hex(@"#43c2e7")];
    NSColor *wingLight = Blend(NSColor.whiteColor, wing, 0.54);
    NSColor *hornColor = [self.controller dragonColorForKey:@"horn" fallback:Hex(@"#ffdc75")];
    NSColor *hornTip = [self.controller dragonColorForKey:@"claw" fallback:Hex(@"#fff1b5")];
    NSColor *crest = [self.controller dragonColorForKey:@"crest" fallback:Hex(@"#ff686e")];
    NSColor *eyeIris = [self.controller dragonColorForKey:@"eye" fallback:Hex(@"#3cdfff")];
    NSColor *cheek = [self.controller dragonColorForKey:@"cheek" fallback:Hex(@"#ff9ab0")];
    NSColor *flameOuter = [self.controller dragonColorForKey:@"flameOuter" fallback:Hex(@"#7c2eff")];
    NSColor *flameMid = [self.controller dragonColorForKey:@"flameMid" fallback:Hex(@"#ff4bd6")];
    NSColor *flameCore = [self.controller dragonColorForKey:@"flameCore" fallback:Hex(@"#fff0a8")];
    NSArray<NSColor *> *patternPalette = @[
        [self.controller dragonColorForKey:@"pattern1" fallback:bodyLight],
        [self.controller dragonColorForKey:@"pattern2" fallback:crest],
        [self.controller dragonColorForKey:@"pattern3" fallback:belly]
    ];

    void (^p)(CGFloat, CGFloat, CGFloat, CGFloat, NSColor *) = ^(CGFloat x, CGFloat y, CGFloat w, CGFloat h, NSColor *color) {
        if (w <= 0 || h <= 0) return;
        [self drawBlockX:round(x) y:round(y) w:round(w) h:round(h) color:color ox:ox oy:oy];
    };
    NSColor *(^patternColor)(NSInteger) = ^NSColor *(NSInteger index) {
        NSInteger safeCount = MAX(1, MIN(3, patternColors));
        return patternPalette[(NSUInteger)(labs((long)index) % safeCount)];
    };
    CGFloat (^phaseForOffset)(CGFloat) = ^CGFloat(CGFloat offset) {
        CGFloat t = walkCycle - offset;
        while (t < 0) t += 1.0;
        while (t >= 1.0) t -= 1.0;
        return t;
    };
    void (^seg)(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, NSColor *) = ^(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat thickness, NSColor *color) {
        NSInteger steps = MAX(1, (NSInteger)ceil(MAX(fabs(x2 - x1), fabs(y2 - y1))));
        for (NSInteger i = 0; i <= steps; i++) {
            CGFloat t = (CGFloat)i / (CGFloat)steps;
            CGFloat x = Lerp(x1, x2, t);
            CGFloat y = Lerp(y1, y2, t);
            p(x - thickness * 0.5, y - thickness * 0.5, thickness, thickness, color);
        }
    };

    p(tailStartX - tailLen + 4, tailStartY + 1, tailLen - 2, 5, ink);
    p(tailStartX - tailLen + 1, tailStartY - 1, 9, 5, ink);
    p(tailStartX - tailLen - 1, tailStartY - 5, 6, 5, ink);
    p(tailStartX - tailLen + 6, tailStartY + 2, tailLen - 6, 3, bodyDark);
    p(tailStartX - tailLen + 3, tailStartY, 7, 3, bodyMid);
    p(tailStartX - tailLen, tailStartY - 3, 5, 3, bodyMid);
    p(tailStartX - 2, tailStartY + 3, 6, 3, bodyDark);
    if (tailLen > 13) {
        p(tailStartX - tailLen + 9, tailStartY - 2, 7, 2, ink);
        p(tailStartX - tailLen + 10, tailStartY - 1, 6, 1, bodyMid);
    }
    if ([self.controller.tailTipType isEqualToString:@"fire tip"]) {
        NSInteger flameFrame = ((NSInteger)floor(self.controller.phase * 2.8)) % 3;
        CGFloat flick = flameFrame == 0 ? -1 : (flameFrame == 1 ? 1 : 0);
        CGFloat flare = flameFrame == 2 ? 1 : 0;
        p(tailStartX - tailLen - 5 + flick, tailStartY - 8 - flare, 6, 8 + flare, flameOuter);
        p(tailStartX - tailLen - 3 - flick, tailStartY - 12 + flick, 4, 5 + flare, flameMid);
        p(tailStartX - tailLen - 2, tailStartY - 7 - flick, 4 + flare, 6, Blend(flameMid, flameCore, 0.48));
        p(tailStartX - tailLen - 1 + flick * 0.5, tailStartY - 8, 2, 4, flameCore);
        if (flameFrame != 1) {
            p(tailStartX - tailLen - 7, tailStartY - 5, 2, 3, flameOuter);
        }
        if (flameFrame == 1) {
            p(tailStartX - tailLen + 1, tailStartY - 10, 2, 3, flameMid);
        }
    } else if ([self.controller.tailTipType isEqualToString:@"horned tip"]) {
        p(tailStartX - tailLen - 3, tailStartY - 3, 5, 3, ink);
        p(tailStartX - tailLen - 2, tailStartY - 2, 4, 2, hornColor);
        p(tailStartX - tailLen - 4, tailStartY - 5, 2, 3, hornTip);
    } else {
        p(tailStartX - tailLen - 1, tailStartY - 2, 4, 3, ink);
        p(tailStartX - tailLen, tailStartY - 1, 3, 2, bodyMid);
    }

    void (^drawLeg)(CGFloat, CGFloat, BOOL, BOOL, BOOL, CGFloat) = ^(CGFloat hipX, CGFloat hipY, BOOL front, BOOL near, BOOL hind, CGFloat offset) {
        CGFloat t = phaseForOffset(offset);
        CGFloat duty = 0.70;
        CGFloat stride = hind ? 7.1 : 5.3;
        CGFloat liftHeight = hind ? 3.8 : 2.8;
        CGFloat groundY = bodyY + bodyH + legLen + (hind ? 5.2 : 3.8) + (near ? 0.4 : -0.7);
        CGFloat baseFootX = hipX + (front ? 1.7 : -3.1);
        CGFloat footX = baseFootX;
        CGFloat footY = groundY;
        BOOL swinging = t >= duty;
        CGFloat flightSway = sin(self.controller.phase * 2.45 + offset * M_PI * 2.0) * (near ? 1.0 : 0.65);
        if (sitting && !biped) {
            swinging = NO;
            footX = hipX + (hind ? -5.2 : 2.0) + (near ? 0.0 : -0.8);
            footY = groundY + (hind ? 2.2 : 0.8);
        } else if (activeFlight) {
            swinging = NO;
            CGFloat dangle = legLen + (hind ? 9.5 : 7.5) + (near ? 1.0 : 0.0);
            footX = hipX + (hind ? -3.0 : 2.1) + flightSway;
            footY = hipY + dangle + cos(self.controller.phase * 2.0 + offset * M_PI * 2.0) * 0.7;
        } else if (!moving) {
            swinging = NO;
            footX = baseFootX + (hind ? -1.4 : 1.2) + (near ? 0.0 : -0.5);
            footY = groundY;
        } else if (!swinging) {
            CGFloat u = t / duty;
            footX = baseFootX + Lerp(stride * 0.52, -stride * 0.56, u);
            footY = groundY;
        } else {
            CGFloat u = (t - duty) / (1.0 - duty);
            CGFloat eased = (1.0 - cos(u * M_PI)) * 0.5;
            footX = baseFootX + Lerp(-stride * 0.58, stride * 0.58, eased);
            footY = groundY - sin(u * M_PI) * liftHeight;
        }

        CGFloat jointSide = front ? -1.0 : 1.0;
        CGFloat hipDrop = near ? 0.0 : -0.4;
        CGFloat kneeX = Lerp(hipX, footX, 0.44) + jointSide * (hind ? 3.3 : 2.1) + (swinging ? -jointSide * 0.9 : 0.0);
        CGFloat kneeY = Lerp(hipY + hipDrop, footY, hind ? 0.43 : 0.48) - (swinging ? 1.1 : 0.0);
        CGFloat ankleX = Lerp(kneeX, footX, 0.63) - jointSide * (hind ? 1.0 : 0.3);
        CGFloat ankleY = Lerp(kneeY, footY, 0.68) + (swinging ? 0.2 : 0.0);
        if (sitting && !biped) {
            kneeX = hipX + (hind ? 2.2 : 0.2);
            kneeY = hipY + (hind ? 6.8 : 5.4);
            ankleX = hind ? footX + 2.2 : Lerp(kneeX, footX, 0.65);
            ankleY = footY - (hind ? 2.2 : 2.8);
        } else if (activeFlight) {
            kneeX = hipX + (hind ? 1.7 : -0.6) + flightSway * 0.35;
            kneeY = hipY + (hind ? 6.0 : 5.0);
            ankleX = Lerp(kneeX, footX, 0.68) + (hind ? -0.8 : 0.4);
            ankleY = Lerp(kneeY, footY, 0.62);
        }
        NSColor *legFill = near ? bodyMid : Blend(bodyDark, body, 0.18);
        NSColor *legLight = near ? bodyLight : Blend(bodyDark, body, 0.36);
        NSColor *jointFill = near ? Blend(bodyDark, body, 0.58) : bodyDark;
        CGFloat thighOutline = hind ? (near ? 5.0 : 4.0) : (near ? 3.6 : 2.9);
        CGFloat shinOutline = hind ? (near ? 4.3 : 3.4) : (near ? 3.0 : 2.3);

        if (hind) {
            CGFloat haunchW = near ? 10.0 : 8.0;
            CGFloat haunchH = near ? 8.0 : 6.0;
            p(hipX - 5, hipY - 4, haunchW, 3, ink);
            p(hipX - 6, hipY - 2, haunchW + 2, haunchH - 1, ink);
            p(hipX - 4, hipY + haunchH - 2, haunchW - 1, 3, ink);
            p(hipX - 4, hipY - 3, haunchW - 2, 2, legLight);
            p(hipX - 5, hipY - 1, haunchW, haunchH - 3, legFill);
            p(hipX - 3, hipY + haunchH - 3, haunchW - 4, 2, jointFill);
            p(hipX - 2, hipY + 2, haunchW - 5, 1, bodyDark);
        } else {
            p(hipX - 3, hipY - 3, near ? 8 : 6, near ? 7 : 5, ink);
            p(hipX - 2, hipY - 2, near ? 6 : 4, near ? 5 : 3, legFill);
            p(hipX - 1, hipY - 2, near ? 3 : 2, 1, legLight);
        }

        seg(hipX, hipY + 2, kneeX, kneeY, thighOutline, ink);
        seg(hipX, hipY + 2, kneeX, kneeY, MAX(1.4, thighOutline - 2.0), legFill);
        p(kneeX - 2, kneeY - 2, hind ? 7 : 5, hind ? 6 : 4, ink);
        p(kneeX - 1, kneeY - 1, hind ? 5 : 3, hind ? 4 : 2, jointFill);
        seg(kneeX + 1, kneeY + 1, ankleX, ankleY, shinOutline, ink);
        seg(kneeX + 1, kneeY + 1, ankleX, ankleY, MAX(1.2, shinOutline - 1.8), legFill);
        seg(ankleX, ankleY, footX, footY - 1, near ? 3.0 : 2.3, ink);
        seg(ankleX, ankleY, footX, footY - 1, near ? 1.7 : 1.2, legFill);

        CGFloat pawW = hind ? 8.8 + clawLen * 0.45 : 6.6 + clawLen * 0.35;
        if (activeFlight) pawW -= hind ? 0.8 : 0.5;
        CGFloat pawH = hind ? 5.0 : 4.0;
        CGFloat pawX = footX - (hind ? 4.6 : 2.6);
        p(pawX - 1, footY - 1, pawW + 1, 3, ink);
        p(pawX + 1, footY - 2, pawW - 4, 2, ink);
        p(pawX, footY + 1, pawW - 2, pawH - 1, ink);
        p(pawX + 1, footY, pawW - 4, 2, legFill);
        p(pawX + 2, footY + 2, pawW - 5, pawH - 2, legFill);
        p(pawX + 3, footY, MAX(1, pawW - 7), 1, legLight);
        for (NSInteger i = 0; i < 3; i++) {
            if (i >= 2 && clawLen < 2) continue;
            CGFloat toeX = pawX + pawW - 3 - i * (hind ? 2.5 : 2.1);
            CGFloat toeY = footY + pawH - 1 + (i % 2);
            p(toeX - 1, toeY - 1, hind ? 3 : 2, 2, ink);
            p(toeX - 0.5, toeY - 0.5, hind ? 2 : 1, 1, legLight);
            p(toeX + 1, toeY, 1.0 + clawLen * 0.55, 2, ink);
            p(toeX + 1.5, toeY, 1, 1, hornTip);
        }
    };

    if (!biped) {
        CGFloat farLegY = bodyY + bodyH - 2;
        drawLeg(bodyX + 5, farLegY, NO, NO, YES, 0.50);
        drawLeg(bodyX + bodyW - 2, farLegY - 1, YES, NO, NO, 0.75);
    }

    BOOL drawWings = hasWings;
    if (drawWings) {
        BOOL waterWings = [self.controller.wingType isEqualToString:@"water wings"];
        CGFloat bigWing = [self.controller.wingType isEqualToString:@"large wings"] ? 3 : 0;
        CGFloat wingLift = activeFlight ? flap : 0;
        CGFloat rootX = shoulderX - 7;
        CGFloat rootY = bodyY - 4 + wingLift * 0.25;
        if (waterWings) {
            CGFloat finX = rootX - 18 - wingScale;
            CGFloat finY = rootY - (activeFlight ? 10 : 4) - wingScale;
            if (activeFlight) {
                p(finX + 3, finY + 2, 17 + wingScale, 5, ink);
                p(finX, finY + 8, 21 + wingScale, 5, ink);
                p(finX + 2, finY + 14, 16 + wingScale, 5, ink);
                p(finX + 5, finY + 3, 12 + wingScale, 2, wingLight);
                p(finX + 2, finY + 9, 16 + wingScale, 2, wing);
                p(finX + 4, finY + 15, 10 + wingScale, 2, wing);
                seg(rootX, rootY, finX + 4, finY + 4, 3, ink);
                seg(rootX, rootY, finX + 2, finY + 11, 2.5, ink);
                seg(rootX, rootY, finX + 6, finY + 18, 2.2, ink);
            } else {
                p(finX + 8, finY + 2, 8 + wingScale, 4, ink);
                p(finX + 5, finY + 7, 14 + wingScale, 4, ink);
                p(finX + 3, finY + 12, 16 + wingScale, 4, ink);
                p(finX + 8, finY + 3, 6 + wingScale, 2, wingLight);
                p(finX + 6, finY + 8, 10 + wingScale, 2, wing);
                p(finX + 4, finY + 13, 11 + wingScale, 2, wing);
                seg(rootX, rootY, finX + 7, finY + 13, 3, ink);
                seg(rootX, rootY, finX + 8, finY + 13, 1.5, wingLight);
            }
        } else {
            CGFloat tipX = bodyX - 7 - wingScale - bigWing;
            CGFloat tipY = rootY - (activeFlight ? 20 : 8) - wingScale - bigWing + (activeFlight ? wingLift * 0.7 : 0);
            CGFloat span = 13 + wingScale + bigWing;
            if (activeFlight) {
                p(tipX - 1, tipY, 8, 3, ink);
                p(tipX + 1, tipY + 1, 5, 1, wingLight);
                p(tipX + 1, tipY + 4, span + 2, 4, ink);
                p(tipX + 3, tipY + 5, span - 1, 2, wingLight);
                p(tipX + 4, tipY + 9, span + 10, 6, ink);
                p(tipX + 6, tipY + 10, span + 5, 3, wing);
                p(tipX + 8, tipY + 16, span + 8, 7, ink);
                p(tipX + 10, tipY + 17, span + 2, 4, wing);
                p(tipX + 14, tipY + 24, span + 1, 5, ink);
                p(tipX + 15, tipY + 25, span - 4, 3, wing);
                p(tipX + 8, tipY + 11, 2, 2, wingLight);
                p(tipX + 13, tipY + 18, 2, 2, wingLight);
                p(tipX + 18, tipY + 25, 2, 2, wingLight);
                seg(rootX, rootY, tipX + 3, tipY + 1, 3, ink);
                seg(rootX, rootY, tipX + 3, tipY + 1, 1.4, wingLight);
                seg(rootX, rootY, tipX + 8, tipY + 12, 2.6, ink);
                seg(rootX, rootY, tipX + 9, tipY + 12, 1.2, wingLight);
                seg(rootX, rootY, tipX + 14, tipY + 23, 2.5, ink);
                seg(rootX, rootY, tipX + 15, tipY + 23, 1.1, wingLight);
            } else {
                p(tipX, tipY, 7, 3, ink);
                p(tipX + 2, tipY + 1, 4, 1, wingLight);
                p(tipX + 2, tipY + 4, span - 2, 3, ink);
                p(tipX + 4, tipY + 5, span - 5, 1, wingLight);
                p(tipX + 5, tipY + 7, span + 4, 4, ink);
                p(tipX + 7, tipY + 8, span, 2, wing);
                p(tipX + 9, tipY + 11, span + 2, 5, ink);
                p(tipX + 10, tipY + 12, span - 1, 3, wing);
                p(tipX + 14, tipY + 16, span - 5, 5, ink);
                p(tipX + 15, tipY + 17, span - 8, 3, wing);
                p(tipX + 8, tipY + 9, 2, 2, wingLight);
                p(tipX + 13, tipY + 13, 2, 2, wingLight);
                p(tipX + 17, tipY + 17, 2, 2, wingLight);
                seg(rootX, rootY, tipX + 3, tipY + 1, 3, ink);
                seg(rootX, rootY, tipX + 3, tipY + 1, 1.4, wingLight);
                seg(rootX, rootY, tipX + 9, tipY + 9, 2.4, ink);
                seg(rootX, rootY, tipX + 10, tipY + 9, 1.2, wingLight);
                seg(rootX, rootY, tipX + 15, tipY + 16, 2.4, ink);
                seg(rootX, rootY, tipX + 16, tipY + 16, 1.1, wingLight);
            }
        }
    }

    p(bodyX - 1, bodyY + 2, bodyW + 4, bodyH - 1, ink);
    p(bodyX + 1, bodyY, bodyW - 2, bodyH + 2, ink);
    p(bodyX + 4, bodyY - 3, bodyW - 8, 6, ink);
    p(bodyX, bodyY + bodyH - 2, bodyW + 1, 5, ink);
    p(bodyX + 1, bodyY + 3, bodyW + 1, bodyH - 3, body);
    p(bodyX + 4, bodyY, bodyW - 8, 5, bodyLight);
    p(bodyX + 1, bodyY + bodyH - 5, bodyW, 4, bodyDark);
    p(bodyX + bodyW - 5, bodyY + 4, 4, bodyH - 3, bodyDark);
    p(bodyX + 3, bodyY + 6, bellySize, bodyH - 4, belly);
    p(bodyX + 5, bodyY + 9, bellySize - 3, 1, bellyDark);
    p(bodyX + 5, bodyY + 13, bellySize - 2, 1, bellyDark);
    if (bellySize > 10) p(bodyX + 5, bodyY + 17, bellySize - 5, 1, bellyDark);
    p(shoulderX - 1, shoulderY, 7, 7, ink);
    p(shoulderX, shoulderY + 1, 5, 5, bodyMid);
    p(shoulderX + 1, shoulderY + 1, 3, 1, bodyLight);

    if (drawWings) {
        BOOL waterWings = [self.controller.wingType isEqualToString:@"water wings"];
        CGFloat rootX = shoulderX - 8;
        CGFloat rootY = bodyY - 3 + (activeFlight ? flap * 0.25 : 0);
        p(rootX + 4, rootY, 7, 9 + wingScale, ink);
        p(rootX + 5, rootY + 1, 4, 7 + wingScale, bodyDark);
        if (waterWings) {
            if (activeFlight) {
                p(rootX - 16 - wingScale, rootY - 6, 19 + wingScale, 4, ink);
                p(rootX - 15 - wingScale, rootY - 5, 14 + wingScale, 2, wingLight);
                p(rootX - 19 - wingScale, rootY + 1, 21 + wingScale, 4, ink);
                p(rootX - 18 - wingScale, rootY + 2, 16 + wingScale, 2, wing);
                p(rootX - 16 - wingScale, rootY + 8, 15 + wingScale, 4, ink);
                p(rootX - 15 - wingScale, rootY + 9, 10 + wingScale, 2, wing);
            } else {
                p(rootX - 11 - wingScale, rootY + 1, 15 + wingScale, 3, ink);
                p(rootX - 10 - wingScale, rootY + 2, 12 + wingScale, 1, wingLight);
                p(rootX - 14 - wingScale, rootY + 6, 16 + wingScale, 3, ink);
                p(rootX - 13 - wingScale, rootY + 7, 12 + wingScale, 1, wing);
            }
        } else {
            if (activeFlight) {
                p(rootX - 18 - wingScale, rootY - 14, 10 + wingScale, 3, ink);
                p(rootX - 17 - wingScale, rootY - 13, 7 + wingScale, 1, wingLight);
                p(rootX - 17 - wingScale, rootY - 9, 20 + wingScale, 5, ink);
                p(rootX - 15 - wingScale, rootY - 8, 15 + wingScale, 2, wing);
                p(rootX - 13 - wingScale, rootY - 2, 20 + wingScale, 5, ink);
                p(rootX - 12 - wingScale, rootY - 1, 14 + wingScale, 3, wing);
                p(rootX - 9 - wingScale, rootY + 5, 16 + wingScale, 5, ink);
                p(rootX - 8 - wingScale, rootY + 6, 10 + wingScale, 3, wing);
                seg(rootX + 4, rootY + 2, rootX - 16 - wingScale, rootY - 13, 2.5, ink);
                seg(rootX + 4, rootY + 2, rootX - 16 - wingScale, rootY - 13, 1.1, wingLight);
                seg(rootX + 4, rootY + 2, rootX - 13 - wingScale, rootY - 1, 2.3, ink);
                seg(rootX + 4, rootY + 2, rootX - 8 - wingScale, rootY + 8, 2.0, ink);
            } else {
                p(rootX - 13 - wingScale, rootY - 6, 8 + wingScale, 3, ink);
                p(rootX - 12 - wingScale, rootY - 5, 5 + wingScale, 1, wingLight);
                p(rootX - 12 - wingScale, rootY - 2, 15 + wingScale, 3, ink);
                p(rootX - 10 - wingScale, rootY - 1, 11 + wingScale, 1, wing);
                p(rootX - 9 - wingScale, rootY + 3, 14 + wingScale, 4, ink);
                p(rootX - 8 - wingScale, rootY + 4, 10 + wingScale, 2, wing);
                seg(rootX + 4, rootY + 2, rootX - 12 - wingScale, rootY - 5, 2.3, ink);
                seg(rootX + 4, rootY + 2, rootX - 12 - wingScale, rootY - 5, 1.1, wingLight);
                seg(rootX + 4, rootY + 2, rootX - 8 - wingScale, rootY + 6, 2.1, ink);
                seg(rootX + 4, rootY + 2, rootX - 8 - wingScale, rootY + 6, 1.0, wingLight);
            }
        }
        p(rootX + 2, rootY + 6, 9, 5, ink);
        p(rootX + 3, rootY + 7, 6, 3, bodyMid);
    }

    if ([self.controller.patternType isEqualToString:@"dots"] || [self.controller.patternType isEqualToString:@"freckles"]) {
        NSInteger dotCount = [self.controller.patternType isEqualToString:@"freckles"] ? 5 + patternDensity * 12 : 3 + patternDensity * 8;
        const CGFloat dots[15][2] = {{20,20},{25,18},{30,22},{22,26},{32,27},{37,15},{42,12},{45,18},{13,24},{9,22},{27,13},{35,25},{17,29},{40,21},{48,16}};
        for (NSInteger i = 0; i < dotCount && i < 15; i++) {
            p(dots[i][0], dots[i][1], i % 3 == 0 ? 2 : 1, i % 4 == 0 ? 2 : 1, patternColor(i));
        }
    } else if ([self.controller.patternType isEqualToString:@"stripes"]) {
        NSInteger stripeCount = 2 + patternDensity * 5;
        for (NSInteger i = 0; i < stripeCount; i++) {
            p(bodyX + 5 + i * 4, bodyY + 2 + (i % 2), 2, bodyH - 4, patternColor(i));
        }
        p(headX + 3, headY + 4, 2, 8, patternColor(8));
        p(headX + 7, headY + 3, 2, 7, patternColor(9));
    } else if ([self.controller.patternType isEqualToString:@"bands"]) {
        NSInteger bandCount = 2 + patternDensity * 4;
        for (NSInteger i = 0; i < bandCount; i++) {
            p(tailStartX - tailLen + 4 + i * 4, tailStartY + 1, 2, 4, patternColor(i));
        }
        p(bodyX + 4, bodyY + 7, bellySize, 2, patternColor(5));
        p(bodyX + 4, bodyY + 13, bellySize - 1, 2, patternColor(6));
    } else if ([self.controller.patternType isEqualToString:@"skull mark"]) {
        p(bodyX + bodyW - 8, bodyY + 8, 6, 6, Hex(@"#fff1dc"));
        p(bodyX + bodyW - 7, bodyY + 10, 1, 1, ink);
        p(bodyX + bodyW - 4, bodyY + 10, 1, 1, ink);
        p(bodyX + bodyW - 6, bodyY + 13, 3, 1, ink);
        p(bodyX + bodyW - 7, bodyY + 7, 2, 1, patternColor(1));
    }

    CGFloat neckX = bodyX + bodyW - 1;
    CGFloat neckY = bodyY - neckLen;
    p(neckX - 1, neckY + 4, 7 + neckLen * 0.35, 11 + neckLen, ink);
    p(neckX + 3, neckY + 1, 5 + neckLen * 0.45, 12 + neckLen, ink);
    p(neckX, neckY + 5, 6 + neckLen * 0.35, 9 + neckLen, body);
    p(neckX + 3, neckY + 2, 4 + neckLen * 0.45, 7 + neckLen, bodyLight);
    p(neckX - 1, neckY + 12 + neckLen, 5, 3, bodyDark);

    p(headX - 4, headY + 8, 6, 9, ink);
    p(headX - 2, headY + 5, headW + 5, headH + 3, ink);
    p(headX, headY + 2, headW + 1, headH + 3, ink);
    p(headX + 4, headY, headW - 2, 6, ink);
    p(headX + headW - 2, headY + 9, 6 + snout, 8, ink);
    p(headX + headW + snout + 2, headY + 11, 3, 5, ink);
    p(headX + 2, headY + headH + 4, headW - 3, 4, ink);
    p(headX - 1, headY + 6, headW + 2, headH - 1, body);
    p(headX + 1, headY + 3, headW, 6, bodyLight);
    p(headX, headY + 13, headW - 1, 5, bodyDark);
    p(headX + headW - 1, headY + 10, 5 + snout, 6, body);
    p(headX + headW, headY + 11, 4 + snout, 2, bodyLight);
    p(headX + headW + snout + 3, headY + 13, 1, 1, deepInk);
    p(headX - 2, headY + 11, 4, 6, bodyDark);
    p(headX + 4, headY + 4, 5, 1, HexAlpha(@"#fff6ff", 0.44));
    p(headX + 9, headY + 5, 4, 1, HexAlpha(@"#fff6ff", 0.30));
    p(headX + 2, headY + 8, 3, 2, bodyMid);

    CGFloat hornBaseX = headX + 4;
    CGFloat hornBaseY = headY + 1;
    if ([self.controller.hornType isEqualToString:@"very straight"]) {
        p(hornBaseX, hornBaseY - hornLen, 3, hornLen + 2, ink);
        p(hornBaseX + 8, hornBaseY - hornLen + 1, 3, hornLen + 1, ink);
        p(hornBaseX + 1, hornBaseY - hornLen + 1, 1, hornLen, hornColor);
        p(hornBaseX + 9, hornBaseY - hornLen + 2, 1, hornLen - 1, hornColor);
        p(hornBaseX + 1, hornBaseY - hornLen, 2, 2, hornTip);
        p(hornBaseX + 9, hornBaseY - hornLen + 1, 2, 2, hornTip);
    } else if ([self.controller.hornType isEqualToString:@"corkscrew"]) {
        for (NSInteger i = 0; i < hornLen; i++) {
            CGFloat wiggle = i % 2 == 0 ? 0 : 1;
            p(hornBaseX + wiggle, hornBaseY - i, 4, 2, ink);
            p(hornBaseX + 1 + wiggle, hornBaseY - i, 2, 1, i % 2 == 0 ? hornColor : crest);
            p(hornBaseX + 8 - wiggle, hornBaseY - i + 1, 4, 2, ink);
            p(hornBaseX + 9 - wiggle, hornBaseY - i + 1, 2, 1, i % 2 == 0 ? hornColor : crest);
        }
    } else {
        for (NSInteger i = 0; i < hornLen; i++) {
            p(hornBaseX + i * 0.55, hornBaseY - i - 1, 4, 2, ink);
            p(hornBaseX + 1 + i * 0.55, hornBaseY - i - 1, 2, 1, i > hornLen - 3 ? hornTip : hornColor);
            p(hornBaseX + 9 + i * 0.45, hornBaseY - i, 4, 2, ink);
            p(hornBaseX + 10 + i * 0.45, hornBaseY - i, 2, 1, i > hornLen - 3 ? hornTip : hornColor);
        }
    }

    for (NSInteger i = 0; i < crestCount; i++) {
        CGFloat sx = headX - 1 - i * 3.5;
        CGFloat sy = headY + 5 + i * 2.3;
        p(sx, sy, 3, 3, ink);
        p(sx + 1, sy, 1, 2, crest);
    }
    if (crestCount > 4) {
        p(bodyX + bodyW - 4, bodyY - 2, 3, 4, ink);
        p(bodyX + bodyW - 3, bodyY - 1, 1, 2, crest);
        p(bodyX + bodyW - 8, bodyY - 1, 3, 4, ink);
        p(bodyX + bodyW - 7, bodyY, 1, 2, crest);
    }

    CGFloat eyeX = headX + 6;
    CGFloat eyeY = headY + 8;
    if (sin(self.controller.phase * 0.7) > 0.985) {
        p(eyeX, eyeY + 2, eyeSize + 1, 1, deepInk);
    } else if (menacing) {
        p(eyeX - 2, eyeY, eyeSize + 4, eyeSize, deepInk);
        p(eyeX, eyeY + 1, eyeSize + 1, eyeSize - 1, NSColor.whiteColor);
        p(eyeX + eyeSize - 1, eyeY + 1, 2, eyeSize - 1, eyeIris);
        p(eyeX, eyeY, eyeSize + 2, 1, ink);
        p(eyeX + 1, eyeY + eyeSize - 1, eyeSize + 1, 1, ink);
        p(eyeX + eyeSize, eyeY + 2, 1, 2, deepInk);
        p(eyeX + 1, eyeY + 1, 1, 1, NSColor.whiteColor);
    } else if (neutralEye) {
        p(eyeX, eyeY + 1, eyeSize + 1, eyeSize - 1, deepInk);
        p(eyeX + 1, eyeY + 2, eyeSize - 1, eyeSize - 2, eyeIris);
        p(eyeX + 1, eyeY + 1, 1, 1, NSColor.whiteColor);
    } else {
        p(eyeX - 2, eyeY, eyeSize + 4, eyeSize + 2, deepInk);
        p(eyeX - 1, eyeY + 1, eyeSize + 3, eyeSize, NSColor.whiteColor);
        p(eyeX + eyeSize - 1, eyeY + 2, 2, eyeSize - 1, eyeIris);
        p(eyeX + eyeSize, eyeY + 3, 1, eyeSize - 2, deepInk);
        p(eyeX + 1, eyeY + 1, 1, 1, NSColor.whiteColor);
    }

    p(headX + 2, headY + 16, cheekSize, 1, cheek);
    if (mouthOpen) {
        p(headX + headW - 1, headY + 17, 5 + snout * 0.5, 2, deepInk);
        p(headX + headW + 1, headY + 18, 3, 1, Hex(@"#ff8fb1"));
    } else {
        p(headX + headW - 1, headY + 17, 4 + snout * 0.45, 1, deepInk);
    }
    p(headX + headW - 2, headY + 19, 2, 2, NSColor.whiteColor);

    if (biped) {
        CGFloat legY = bodyY + bodyH - 2;
        drawLeg(bodyX + 3, legY, NO, YES, YES, 0.00);
        drawLeg(bodyX + bodyW - 4, legY, YES, YES, NO, 0.50);
        p(bodyX + 3, bodyY + 7, 4, 9, ink);
        p(bodyX + bodyW - 2, bodyY + 8, 4, 8, ink);
        p(bodyX + 4, bodyY + 8, 2, 7, bodyDark);
        p(bodyX + bodyW - 1, bodyY + 9, 2, 6, bodyDark);
    } else {
        CGFloat legY = bodyY + bodyH - 1;
        drawLeg(bodyX + 6, legY, NO, YES, YES, 0.00);
        drawLeg(bodyX + bodyW + 1, legY - 1, YES, YES, NO, 0.25);
    }
}

- (void)drawParticles {
    for (NSDictionary *particle in self.controller.particles) {
        CGFloat x = [particle[@"x"] doubleValue];
        CGFloat y = [particle[@"y"] doubleValue];
        CGFloat life = [particle[@"life"] doubleValue];
        CGFloat size = [particle[@"size"] doubleValue] * MAX(0.35, MIN(1.0, life));
        NSString *kind = particle[@"kind"];
        NSColor *fill = particle[@"color"];
        [fill setFill];
        if ([kind isEqualToString:@"heart"]) {
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x - size, y - size, size, size)] fill];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, y - size, size, size)] fill];
            NSBezierPath *path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(x - size, y - size * 0.35)];
            [path lineToPoint:NSMakePoint(x + size, y - size * 0.35)];
            [path lineToPoint:NSMakePoint(x, y + size * 1.1)];
            [path closePath];
            [path fill];
        } else if ([kind isEqualToString:@"crumb"]) {
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x - size, y - size * 0.7, size * 2, size * 1.4)] fill];
        } else {
            NSBezierPath *path = [NSBezierPath bezierPath];
            for (NSUInteger i = 0; i < 10; i++) {
                CGFloat radius = i % 2 == 0 ? size : size * 0.45;
                CGFloat angle = -M_PI_2 + i * M_PI / 5.0;
                NSPoint point = NSMakePoint(x + cos(angle) * radius, y + sin(angle) * radius);
                i == 0 ? [path moveToPoint:point] : [path lineToPoint:point];
            }
            [path closePath];
            [path fill];
        }
    }
}

@end

@implementation HomeView

- (BOOL)isFlipped {
    return YES;
}

- (NSView *)hitTest:(NSPoint)point {
    NSRect homeRect = NSMakeRect(10, 8, self.bounds.size.width - 20, self.bounds.size.height - 18);
    return NSPointInRect(point, homeRect) ? self : nil;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor clearColor] setFill];
    NSRectFill(dirtyRect);

    CGFloat w = self.bounds.size.width;
    NSColor *ink = Hex(@"#4b3a3f");
    NSColor *soil = HexAlpha(@"#6e5044", 0.98);
    NSColor *soilMid = Hex(@"#8a5a44");
    NSColor *soilDark = Hex(@"#2b2226");
    NSColor *soilLight = Hex(@"#c88762");
    NSColor *moss = Hex(@"#67c083");
    NSColor *mossLight = Hex(@"#a8e88a");
    NSColor *stone = Hex(@"#8a7c78");
    NSColor *glow = HexAlpha(@"#ffdca8", 0.34);

    CGFloat cx = w / 2;
    void (^rect)(CGFloat, CGFloat, CGFloat, CGFloat, NSColor *) = ^(CGFloat x, CGFloat y, CGFloat rw, CGFloat rh, NSColor *color) {
        [color setFill];
        NSRectFill(NSMakeRect(round(x), round(y), round(rw), round(rh)));
    };

    rect(cx - 102, 150, 204, 16, HexAlpha(@"#171126", 0.26));
    rect(cx - 74, 166, 148, 12, HexAlpha(@"#171126", 0.18));

    rect(cx - 54, 72, 108, 12, ink);
    rect(cx - 82, 84, 164, 18, ink);
    rect(cx - 112, 102, 224, 34, ink);
    rect(cx - 126, 132, 252, 34, ink);
    rect(cx - 96, 164, 192, 14, ink);

    rect(cx - 48, 78, 96, 8, soilLight);
    rect(cx - 76, 90, 152, 18, soilMid);
    rect(cx - 104, 108, 208, 30, soil);
    rect(cx - 116, 136, 232, 24, soilMid);
    rect(cx - 82, 164, 164, 8, soilLight);

    rect(cx - 58, 100, 116, 12, ink);
    rect(cx - 82, 112, 164, 42, ink);
    rect(cx - 62, 154, 124, 12, ink);
    rect(cx - 48, 112, 96, 9, soilDark);
    rect(cx - 66, 122, 132, 30, soilDark);
    rect(cx - 42, 152, 84, 8, soilDark);
    rect(cx - 36, 128, 72, 8, glow);

    rect(cx - 116, 118, 30, 22, stone);
    rect(cx - 104, 108, 18, 10, Hex(@"#a79a92"));
    rect(cx + 84, 122, 32, 28, stone);
    rect(cx + 90, 116, 16, 10, Hex(@"#a79a92"));
    rect(cx - 92, 94, 42, 8, moss);
    rect(cx - 72, 86, 22, 8, mossLight);
    rect(cx + 48, 96, 52, 8, moss);
    rect(cx + 62, 88, 18, 8, mossLight);
    rect(cx - 8, 80, 12, 20, ink);
    rect(cx - 5, 82, 6, 15, Hex(@"#6b5360"));
    rect(cx + 18, 84, 10, 16, ink);
    rect(cx + 21, 86, 5, 12, Hex(@"#6b5360"));

    if (self.controller.insideHome && !self.controller.habitatWindow.isVisible) {
        NSColor *body = [self.controller dragonColorForKey:@"body" fallback:Hex(@"#67d8f4")];
        rect(cx - 24, 130, 52, 18, ink);
        rect(cx - 20, 134, 44, 12, body);
        rect(cx + 12, 124, 18, 12, ink);
        rect(cx + 14, 126, 14, 8, body);
        rect(cx + 24, 126, 10, 4, ink);
        rect(cx + 18, 122, 6, 6, Hex(@"#ffdc75"));
        rect(cx + 18, 128, 6, 6, Hex(@"#33272d"));
    }

}

- (void)mouseDown:(NSEvent *)event {
    [self.controller startHomeDragAt:[NSEvent mouseLocation]];
}

- (void)mouseDragged:(NSEvent *)event {
    [self.controller dragHomeTo:[NSEvent mouseLocation]];
}

- (void)mouseUp:(NSEvent *)event {
    [self.controller finishHomeDragAt:[NSEvent mouseLocation]];
}

@end

@implementation HabitatView

- (BOOL)isFlipped {
    return YES;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizesSubviews = NO;
        _draggingCavePieceIndex = -1;
        _selectedCavePieceIndex = -1;
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)drawPixelRect:(NSRect)rect color:(NSColor *)color {
    [color setFill];
    NSRectFill(rect);
}

- (NSRect)sceneRect {
    CGFloat panelWidth = 338;
    CGFloat margin = 22;
    return NSMakeRect(margin, 28, self.bounds.size.width - panelWidth - margin * 2, self.bounds.size.height - 56);
}

- (NSRect)nestRect {
    NSRect scene = [self sceneRect];
    return NSMakeRect(scene.origin.x + 34, NSMaxY(scene) - 126, 176, 46);
}

- (NSSize)cavePieceSizeForKind:(NSString *)kind {
    if ([kind isEqualToString:@"crystal"]) return NSMakeSize(46, 68);
    if ([kind isEqualToString:@"moss"]) return NSMakeSize(76, 20);
    if ([kind isEqualToString:@"stalagmite"]) return NSMakeSize(54, 58);
    if ([kind isEqualToString:@"stalactite"]) return NSMakeSize(58, 66);
    if ([kind isEqualToString:@"boulder"]) return NSMakeSize(88, 48);
    if ([kind isEqualToString:@"pebbles"]) return NSMakeSize(76, 28);
    if ([kind isEqualToString:@"slab"]) return NSMakeSize(108, 28);
    if ([kind isEqualToString:@"geode"]) return NSMakeSize(64, 54);
    return NSMakeSize(66, 34);
}

- (NSRect)cavePieceRectAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.controller.cavePieces.count) return NSZeroRect;
    NSDictionary *piece = self.controller.cavePieces[(NSUInteger)index];
    NSRect scene = [self sceneRect];
    NSSize size = [self cavePieceSizeForKind:piece[@"kind"] ?: @"rock"];
    CGFloat x = [piece[@"x"] doubleValue];
    CGFloat y = [piece[@"y"] doubleValue];
    return NSMakeRect(scene.origin.x + x, scene.origin.y + y, size.width, size.height);
}

- (NSInteger)cavePieceIndexAtPoint:(NSPoint)point {
    for (NSInteger i = (NSInteger)self.controller.cavePieces.count - 1; i >= 0; i--) {
        if (NSPointInRect(point, NSInsetRect([self cavePieceRectAtIndex:i], -6, -6))) {
            return i;
        }
    }
    return -1;
}

- (void)drawCavePieceAtIndex:(NSInteger)index rect:(void (^)(CGFloat, CGFloat, CGFloat, CGFloat, NSColor *))rect {
    if (index < 0 || index >= (NSInteger)self.controller.cavePieces.count) return;
    NSDictionary *piece = self.controller.cavePieces[(NSUInteger)index];
    NSString *kind = piece[@"kind"] ?: @"rock";
    NSRect r = [self cavePieceRectAtIndex:index];
    NSColor *ink = Hex(@"#171126");
    NSColor *stone = Hex(@"#625969");
    NSColor *stoneLight = Hex(@"#8b8294");
    NSColor *stoneDark = Hex(@"#393241");
    if ([kind isEqualToString:@"crystal"]) {
        NSColor *crystal = Hex(@"#7df6d2");
        NSColor *crystalLight = Hex(@"#d2fff3");
        rect(r.origin.x + 18, r.origin.y + 2, 14, 8, ink);
        rect(r.origin.x + 12, r.origin.y + 10, 26, 14, ink);
        rect(r.origin.x + 8, r.origin.y + 24, 32, 30, ink);
        rect(r.origin.x + 16, r.origin.y + 8, 12, 12, crystalLight);
        rect(r.origin.x + 12, r.origin.y + 20, 22, 28, crystal);
        rect(r.origin.x + 24, r.origin.y + 26, 8, 24, Hex(@"#42bfc0"));
        rect(r.origin.x + 6, r.origin.y + 50, 40, 10, ink);
        rect(r.origin.x + 10, r.origin.y + 52, 30, 6, stoneDark);
    } else if ([kind isEqualToString:@"moss"]) {
        rect(r.origin.x + 2, r.origin.y + 8, 70, 8, ink);
        rect(r.origin.x + 8, r.origin.y + 4, 20, 7, Hex(@"#9ee477"));
        rect(r.origin.x + 26, r.origin.y + 2, 26, 9, Hex(@"#63b86f"));
        rect(r.origin.x + 50, r.origin.y + 6, 20, 7, Hex(@"#a8e88a"));
        rect(r.origin.x + 10, r.origin.y + 12, 58, 4, Hex(@"#426c50"));
    } else if ([kind isEqualToString:@"stalagmite"]) {
        rect(r.origin.x + 20, r.origin.y + 4, 12, 10, ink);
        rect(r.origin.x + 15, r.origin.y + 14, 22, 15, ink);
        rect(r.origin.x + 9, r.origin.y + 29, 34, 20, ink);
        rect(r.origin.x + 22, r.origin.y + 8, 8, 12, stoneLight);
        rect(r.origin.x + 17, r.origin.y + 20, 17, 24, stone);
        rect(r.origin.x + 25, r.origin.y + 24, 12, 22, stoneDark);
        rect(r.origin.x + 5, r.origin.y + 48, 44, 8, ink);
        rect(r.origin.x + 9, r.origin.y + 50, 34, 5, stoneDark);
    } else if ([kind isEqualToString:@"stalactite"]) {
        rect(r.origin.x + 6, r.origin.y + 0, 46, 9, ink);
        rect(r.origin.x + 12, r.origin.y + 8, 34, 15, ink);
        rect(r.origin.x + 18, r.origin.y + 22, 24, 16, ink);
        rect(r.origin.x + 24, r.origin.y + 38, 13, 20, ink);
        rect(r.origin.x + 11, r.origin.y + 2, 34, 7, stoneDark);
        rect(r.origin.x + 16, r.origin.y + 10, 24, 17, stone);
        rect(r.origin.x + 22, r.origin.y + 26, 14, 26, stoneLight);
        rect(r.origin.x + 30, r.origin.y + 30, 8, 25, stoneDark);
    } else if ([kind isEqualToString:@"pebbles"]) {
        rect(r.origin.x + 5, r.origin.y + 15, 20, 9, ink);
        rect(r.origin.x + 26, r.origin.y + 10, 24, 14, ink);
        rect(r.origin.x + 50, r.origin.y + 16, 18, 8, ink);
        rect(r.origin.x + 8, r.origin.y + 16, 15, 6, stone);
        rect(r.origin.x + 30, r.origin.y + 12, 17, 10, stoneLight);
        rect(r.origin.x + 52, r.origin.y + 17, 14, 5, stoneDark);
    } else if ([kind isEqualToString:@"slab"]) {
        rect(r.origin.x + 4, r.origin.y + 8, 96, 18, ink);
        rect(r.origin.x + 10, r.origin.y + 4, 78, 9, ink);
        rect(r.origin.x + 12, r.origin.y + 7, 74, 8, stoneLight);
        rect(r.origin.x + 7, r.origin.y + 15, 90, 8, stone);
        rect(r.origin.x + 66, r.origin.y + 18, 28, 5, stoneDark);
        rect(r.origin.x + 24, r.origin.y + 20, 34, 4, stoneDark);
    } else if ([kind isEqualToString:@"geode"]) {
        rect(r.origin.x + 10, r.origin.y + 16, 44, 30, ink);
        rect(r.origin.x + 16, r.origin.y + 9, 30, 12, ink);
        rect(r.origin.x + 14, r.origin.y + 18, 38, 24, stoneDark);
        rect(r.origin.x + 22, r.origin.y + 16, 22, 22, Hex(@"#4b315d"));
        rect(r.origin.x + 26, r.origin.y + 18, 8, 8, Hex(@"#d58bff"));
        rect(r.origin.x + 36, r.origin.y + 24, 8, 12, Hex(@"#8b47c9"));
        rect(r.origin.x + 18, r.origin.y + 34, 32, 8, stone);
    } else {
        BOOL boulder = [kind isEqualToString:@"boulder"];
        CGFloat w = boulder ? 86 : 64;
        CGFloat h = boulder ? 44 : 30;
        rect(r.origin.x + 8, r.origin.y + 6, w - 16, 8, ink);
        rect(r.origin.x + 2, r.origin.y + 14, w - 4, h - 14, ink);
        rect(r.origin.x + 12, r.origin.y + 8, w - 24, 10, stoneLight);
        rect(r.origin.x + 5, r.origin.y + 17, w - 10, h - 20, stone);
        rect(r.origin.x + w - 30, r.origin.y + 20, 22, h - 24, stoneDark);
        rect(r.origin.x + 16, r.origin.y + h - 9, w - 28, 5, stoneDark);
    }
    if (index == self.draggingCavePieceIndex || index == self.selectedCavePieceIndex) {
        NSColor *outline = index == self.draggingCavePieceIndex ? Hex(@"#ffdc75") : Hex(@"#7df6d2");
        rect(r.origin.x - 3, r.origin.y - 3, r.size.width + 6, 3, outline);
        rect(r.origin.x - 3, r.origin.y + r.size.height, r.size.width + 6, 3, outline);
        rect(r.origin.x - 3, r.origin.y, 3, r.size.height, outline);
        rect(r.origin.x + r.size.width, r.origin.y, 3, r.size.height, outline);
    }
}

- (void)drawMiniDragonAt:(NSPoint)p {
    if (!self.controller.view) return;
    CGFloat run = sin(self.controller.phase * 0.52);
    CGFloat bob = round(sin(self.controller.phase * 0.52) * 1.15);
    BOOL moving = !self.controller.habitatFlying && hypot(self.controller.habitatVX, self.controller.habitatVY) > 0.18 && !self.controller.sitting;
    CGFloat savedFacing = self.controller.facing;
    self.controller.facing = self.controller.habitatFacing;

    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:p.x yBy:p.y];
    [transform concat];
    [self.controller.view drawDragonWithBob:bob run:run mouthOpen:self.controller.mouthUntil > Now() flying:self.controller.habitatFlying moving:moving sitting:self.controller.sitting];
    [NSGraphicsContext restoreGraphicsState];

    self.controller.facing = savedFacing;
}

- (NSTextField *)labelWithText:(NSString *)text frame:(NSRect)frame bold:(BOOL)bold {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.selectable = NO;
    label.bordered = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.font = bold ? ([NSFont fontWithName:@"Avenir Next Heavy" size:12] ?: [NSFont boldSystemFontOfSize:12])
                      : ([NSFont fontWithName:@"Avenir Next" size:12] ?: [NSFont systemFontOfSize:12]);
    label.textColor = Hex(@"#4b3a3f");
    return label;
}

- (NSView *)creatorHost {
    return self.creatorContentView ?: self;
}

- (NSAppearance *)creatorLightAppearance {
    return [NSAppearance appearanceNamed:NSAppearanceNameAqua];
}

- (void)stylePanelButton:(NSButton *)button {
    button.appearance = [self creatorLightAppearance];
    button.font = [NSFont fontWithName:@"Avenir Next Demi Bold" size:12] ?: [NSFont boldSystemFontOfSize:12];
    NSDictionary *attrs = @{
        NSFontAttributeName: button.font,
        NSForegroundColorAttributeName: Hex(@"#4b3a3f")
    };
    button.attributedTitle = [[NSAttributedString alloc] initWithString:button.title ?: @"" attributes:attrs];
    if ([button respondsToSelector:@selector(setContentTintColor:)]) {
        [(id)button setContentTintColor:Hex(@"#4b3a3f")];
    }
}

- (void)stylePanelTextField:(NSTextField *)field {
    field.appearance = [self creatorLightAppearance];
    field.textColor = Hex(@"#4b3a3f");
    if (field.editable || field.bezeled || field.bordered) {
        field.backgroundColor = Hex(@"#fffaf2");
    }
}

- (void)applyCreatorLightAppearanceToView:(NSView *)view {
    view.appearance = [self creatorLightAppearance];
    if ([view isKindOfClass:NSTextField.class]) {
        [self stylePanelTextField:(NSTextField *)view];
    } else if ([view isKindOfClass:NSButton.class]) {
        [self stylePanelButton:(NSButton *)view];
    } else if ([view isKindOfClass:NSControl.class]) {
        ((NSControl *)view).appearance = [self creatorLightAppearance];
    }
    for (NSView *subview in view.subviews) {
        [self applyCreatorLightAppearanceToView:subview];
    }
}

- (NSString *)formatValueForKey:(NSString *)key value:(CGFloat)value {
    if ([key isEqualToString:@"ageDays"]) {
        return [NSString stringWithFormat:@"%.0fd", value];
    }
    if ([key hasPrefix:@"exposure."] || [key hasPrefix:@"parts."]) {
        if ([key isEqualToString:@"parts.patternColorCount"]) {
            return [NSString stringWithFormat:@"%.0f", value];
        }
        return [NSString stringWithFormat:@"%.2f", value];
    }
    return [NSString stringWithFormat:@"%.0f", value];
}

- (void)addSliderForKey:(NSString *)key label:(NSString *)label min:(CGFloat)min max:(CGFloat)max y:(CGFloat)y {
    NSView *host = [self creatorHost];
    CGFloat x = 8;
    NSTextField *title = [self labelWithText:label frame:NSMakeRect(x, y, 86, 18) bold:NO];
    [host addSubview:title];

    NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(x + 86, y - 1, 148, 22)];
    slider.minValue = min;
    slider.maxValue = max;
    slider.continuous = YES;
    slider.identifier = key;
    slider.target = self;
    slider.action = @selector(sliderChanged:);
    [host addSubview:slider];

    NSTextField *value = [self labelWithText:@"" frame:NSMakeRect(x + 238, y, 42, 18) bold:YES];
    value.alignment = NSTextAlignmentRight;
    [host addSubview:value];

    self.creatorSliders[key] = slider;
    self.creatorValueLabels[key] = value;
}

- (NSPopUpButton *)addPopupForKey:(NSString *)key label:(NSString *)label values:(NSArray<NSString *> *)values y:(CGFloat)y {
    NSView *host = [self creatorHost];
    CGFloat x = 8;
    NSTextField *title = [self labelWithText:label frame:NSMakeRect(x, y, 86, 18) bold:NO];
    [host addSubview:title];

    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(x + 88, y - 4, 192, 26)];
    [popup addItemsWithTitles:values];
    popup.identifier = key;
    popup.target = self;
    popup.action = @selector(popupChanged:);
    [host addSubview:popup];
    if (self.creatorPopups) {
        self.creatorPopups[key] = popup;
    }
    return popup;
}

- (void)addColorWellForKey:(NSString *)key label:(NSString *)label y:(CGFloat)y {
    NSView *host = [self creatorHost];
    CGFloat x = 8;
    NSTextField *title = [self labelWithText:label frame:NSMakeRect(x, y + 3, 92, 18) bold:NO];
    [host addSubview:title];

    NSColorWell *well = [[NSColorWell alloc] initWithFrame:NSMakeRect(x + 104, y, 54, 24)];
    well.identifier = key;
    well.continuous = YES;
    well.target = self;
    well.action = @selector(colorWellChanged:);
    well.color = [self.controller dragonColorForKey:key fallback:Hex(@"#67d8f4")];
    [host addSubview:well];
    self.creatorColorWells[key] = well;

    NSTextField *value = [self labelWithText:[self.controller dragonColorHexForKey:key] frame:NSMakeRect(x + 168, y + 3, 78, 18) bold:YES];
    value.identifier = [NSString stringWithFormat:@"hex.%@", key];
    [host addSubview:value];
    self.creatorValueLabels[[NSString stringWithFormat:@"color.%@", key]] = value;
}

- (void)buildCreatorControls {
    if (self.creatorSliders) return;
    self.appearance = [self creatorLightAppearance];
    self.creatorSliders = [NSMutableDictionary dictionary];
    self.creatorValueLabels = [NSMutableDictionary dictionary];
    self.creatorPopups = [NSMutableDictionary dictionary];
    self.creatorColorWells = [NSMutableDictionary dictionary];

    CGFloat panelX = self.bounds.size.width - 338;
    CGFloat scrollHeight = MAX(460, self.bounds.size.height - 92);
    self.creatorContentView = [[FlippedControlsView alloc] initWithFrame:NSMakeRect(0, 0, 296, 1010)];
    self.creatorScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(panelX + 10, 42, 296, scrollHeight)];
    self.creatorScrollView.documentView = self.creatorContentView;
    self.creatorScrollView.hasVerticalScroller = YES;
    self.creatorScrollView.hasHorizontalScroller = NO;
    self.creatorScrollView.autohidesScrollers = YES;
    self.creatorScrollView.borderType = NSNoBorder;
    self.creatorScrollView.drawsBackground = NO;
    self.creatorScrollView.appearance = [self creatorLightAppearance];
    [self addSubview:self.creatorScrollView];
    self.creatorContentView.appearance = [self creatorLightAppearance];

    NSView *host = [self creatorHost];
    CGFloat x = 8;
    [host addSubview:[self labelWithText:@"Customize Snoot" frame:NSMakeRect(x, 0, 200, 22) bold:YES]];

    self.nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(x, 30, 280, 24)];
    self.nameField.font = [NSFont fontWithName:@"Avenir Next" size:13] ?: [NSFont systemFontOfSize:13];
    [self stylePanelTextField:self.nameField];
    self.nameField.target = self;
    self.nameField.action = @selector(nameChanged:);
    [host addSubview:self.nameField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nameChanged:) name:NSControlTextDidChangeNotification object:self.nameField];

    CGFloat y = 66;
    [self addSliderForKey:@"ageDays" label:@"age" min:0 max:180 y:y]; y += 29;
    [self addSliderForKey:@"hunger" label:@"hunger" min:0 max:100 y:y]; y += 29;
    [self addSliderForKey:@"affection" label:@"affection" min:0 max:100 y:y]; y += 29;
    [self addSliderForKey:@"energy" label:@"energy" min:0 max:100 y:y]; y += 29;
    [self addSliderForKey:@"curiosity" label:@"curiosity" min:0 max:100 y:y]; y += 29;
    [self addSliderForKey:@"confidence" label:@"confidence" min:0 max:100 y:y]; y += 35;

    [host addSubview:[self labelWithText:@"Growth Inputs" frame:NSMakeRect(x, y, 200, 20) bold:YES]];
    y += 28;
    [self addSliderForKey:@"exposure.warm" label:@"warm" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"exposure.cool" label:@"cool" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"exposure.nature" label:@"nature" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"exposure.dark" label:@"dark" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"exposure.creative" label:@"creative" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"exposure.code" label:@"code" min:0 max:1 y:y]; y += 37;

    [host addSubview:[self labelWithText:@"Colors" frame:NSMakeRect(x, y, 200, 20) bold:YES]];
    y += 28;
    NSArray<NSDictionary *> *colorControls = @[
        @{@"label": @"outline", @"key": @"outline"},
        @{@"label": @"deep line", @"key": @"deepOutline"},
        @{@"label": @"body", @"key": @"body"},
        @{@"label": @"highlight", @"key": @"highlight"},
        @{@"label": @"belly", @"key": @"belly"},
        @{@"label": @"wings", @"key": @"wing"},
        @{@"label": @"horns", @"key": @"horn"},
        @{@"label": @"crest", @"key": @"crest"},
        @{@"label": @"eyes", @"key": @"eye"},
        @{@"label": @"cheeks", @"key": @"cheek"},
        @{@"label": @"claws", @"key": @"claw"},
        @{@"label": @"pattern 1", @"key": @"pattern1"},
        @{@"label": @"pattern 2", @"key": @"pattern2"},
        @{@"label": @"pattern 3", @"key": @"pattern3"},
        @{@"label": @"flame edge", @"key": @"flameOuter"},
        @{@"label": @"flame mid", @"key": @"flameMid"},
        @{@"label": @"flame core", @"key": @"flameCore"}
    ];
    for (NSDictionary *info in colorControls) {
        [self addColorWellForKey:info[@"key"] label:info[@"label"] y:y];
        y += 29;
    }
    y += 8;

    [host addSubview:[self labelWithText:@"Body Parts" frame:NSMakeRect(x, y, 200, 20) bold:YES]];
    y += 28;
    [self addPopupForKey:@"style.hornType" label:@"horn type" values:@[@"natural", @"very straight", @"corkscrew"] y:y]; y += 31;
    [self addPopupForKey:@"style.eyeShape" label:@"eye mood" values:@[@"friendly", @"neutral", @"menacing"] y:y]; y += 31;
    [self addPopupForKey:@"style.stance" label:@"stance" values:@[@"four legs", @"two legs"] y:y]; y += 31;
    [self addPopupForKey:@"style.tailTip" label:@"tail tip" values:@[@"neutral tip", @"fire tip", @"horned tip"] y:y]; y += 31;
    [self addPopupForKey:@"style.wingType" label:@"wings" values:@[@"no wings", @"normal wings", @"large wings", @"water wings"] y:y]; y += 31;
    [self addPopupForKey:@"style.patternType" label:@"pattern" values:@[@"dots", @"stripes", @"bands", @"freckles", @"skull mark"] y:y]; y += 35;
    [self addSliderForKey:@"parts.bodyLength" label:@"body len" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.bodyHeight" label:@"body ht" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.headSize" label:@"head" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.snoutLength" label:@"snout" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.hornLength" label:@"horns" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.neckLength" label:@"neck" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.wingSize" label:@"wings" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.tailLength" label:@"tail" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.legLength" label:@"legs" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.clawLength" label:@"claws" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.crestSize" label:@"crest" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.eyeSize" label:@"eyes" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.bellySize" label:@"belly" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.cheekSize" label:@"cheeks" min:0 max:1 y:y]; y += 37;
    [self addSliderForKey:@"parts.patternDensity" label:@"pattern amt" min:0 max:1 y:y]; y += 29;
    [self addSliderForKey:@"parts.patternColorCount" label:@"pat colors" min:1 max:3 y:y]; y += 37;

    self.foodPopup = [self addPopupForKey:@"favoriteFood" label:@"food" values:@[@"meteor berries", @"smoked sun-meat", @"crunchy fern sprouts", @"moon sugar", @"starfruit cubes"] y:y]; y += 31;
    self.colorPopup = [self addPopupForKey:@"favoriteColor" label:@"palette" values:@[@"sky blue", @"ember coral", @"moss green", @"moonlit violet", @"carnival bright"] y:y]; y += 31;
    self.appPopup = [self addPopupForKey:@"lastAppName" label:@"app" values:@[@"Desktop", @"Cursor", @"Figma", @"Terminal", @"Safari", @"BambuStudio", @"Notes"] y:y]; y += 40;

    [host addSubview:[self labelWithText:@"Cave Pieces" frame:NSMakeRect(x, y, 200, 20) bold:YES]];
    y += 27;
    NSArray<NSDictionary *> *pieceButtons = @[
        @{@"title": @"Rock", @"kind": @"rock"},
        @{@"title": @"Boulder", @"kind": @"boulder"},
        @{@"title": @"Pebbles", @"kind": @"pebbles"},
        @{@"title": @"Slab", @"kind": @"slab"},
        @{@"title": @"Geode", @"kind": @"geode"},
        @{@"title": @"Crystal", @"kind": @"crystal"},
        @{@"title": @"Spike", @"kind": @"stalagmite"},
        @{@"title": @"Ceiling", @"kind": @"stalactite"},
        @{@"title": @"Moss", @"kind": @"moss"}
    ];
    for (NSInteger i = 0; i < (NSInteger)pieceButtons.count; i++) {
        NSDictionary *info = pieceButtons[(NSUInteger)i];
        NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(x + (i % 3) * 94, y + (i / 3) * 28, 86, 24)];
        button.title = info[@"title"];
        button.identifier = info[@"kind"];
        button.bezelStyle = NSBezelStyleRounded;
        button.target = self;
        button.action = @selector(addCavePieceClicked:);
        [self stylePanelButton:button];
        [host addSubview:button];
    }
    y += 90;
    NSButton *deleteCave = [[NSButton alloc] initWithFrame:NSMakeRect(x, y, 132, 26)];
    deleteCave.title = @"Delete selected";
    deleteCave.bezelStyle = NSBezelStyleRounded;
    deleteCave.target = self;
    deleteCave.action = @selector(deleteSelectedCavePieceClicked:);
    [self stylePanelButton:deleteCave];
    [host addSubview:deleteCave];

    NSButton *resetCave = [[NSButton alloc] initWithFrame:NSMakeRect(x + 148, y, 132, 26)];
    resetCave.title = @"Reset cave";
    resetCave.bezelStyle = NSBezelStyleRounded;
    resetCave.target = self;
    resetCave.action = @selector(resetCaveClicked:);
    [self stylePanelButton:resetCave];
    [host addSubview:resetCave];
    y += 42;

    self.configNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, 134, 24)];
    self.configNameField.stringValue = @"favorite-build";
    self.configNameField.font = [NSFont fontWithName:@"Avenir Next" size:12] ?: [NSFont systemFontOfSize:12];
    [self stylePanelTextField:self.configNameField];
    [host addSubview:self.configNameField];

    NSButton *saveConfig = [[NSButton alloc] initWithFrame:NSMakeRect(x + 142, y - 1, 66, 26)];
    saveConfig.title = @"Save";
    saveConfig.bezelStyle = NSBezelStyleRounded;
    saveConfig.target = self;
    saveConfig.action = @selector(saveConfigClicked:);
    [self stylePanelButton:saveConfig];
    [host addSubview:saveConfig];

    NSButton *saveLive = [[NSButton alloc] initWithFrame:NSMakeRect(x + 214, y - 1, 66, 26)];
    saveLive.title = @"Apply";
    saveLive.bezelStyle = NSBezelStyleRounded;
    saveLive.target = self;
    saveLive.action = @selector(saveLiveClicked:);
    [self stylePanelButton:saveLive];
    [host addSubview:saveLive];
    y += 34;

    self.configPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(x, y - 4, 206, 26)];
    [host addSubview:self.configPopup];
    NSButton *loadConfig = [[NSButton alloc] initWithFrame:NSMakeRect(x + 214, y - 1, 66, 26)];
    loadConfig.title = @"Load";
    loadConfig.bezelStyle = NSBezelStyleRounded;
    loadConfig.target = self;
    loadConfig.action = @selector(loadConfigClicked:);
    [self stylePanelButton:loadConfig];
    [host addSubview:loadConfig];

    self.creatorContentView.frame = NSMakeRect(0, 0, 296, y + 40);
    [self applyCreatorLightAppearanceToView:self.creatorScrollView];

    [self refreshConfigPopup];
    [self syncControlsFromController];
}

- (void)refreshConfigPopup {
    [self.configPopup removeAllItems];
    NSArray<NSString *> *names = [self.controller configurationNames];
    if (names.count == 0) {
        [self.configPopup addItemWithTitle:@"No saved configs"];
        self.configPopup.enabled = NO;
    } else {
        [self.configPopup addItemsWithTitles:names];
        self.configPopup.enabled = YES;
    }
}

- (void)syncControlsFromController {
    if (!self.creatorSliders || !self.controller) return;
    self.nameField.stringValue = self.controller.creatureName ?: @"Pebble";
    for (NSString *key in self.creatorSliders) {
        CGFloat value = [self.controller creatorValueForKey:key];
        NSSlider *slider = self.creatorSliders[key];
        slider.doubleValue = value;
        self.creatorValueLabels[key].stringValue = [self formatValueForKey:key value:value];
    }
    [self.foodPopup selectItemWithTitle:self.controller.favoriteFood ?: @"meteor berries"];
    [self.colorPopup selectItemWithTitle:self.controller.favoriteColor ?: @"sky blue"];
    NSString *app = self.controller.lastAppName.length ? self.controller.lastAppName : @"Desktop";
    [self.appPopup selectItemWithTitle:app];
    for (NSString *key in self.creatorPopups) {
        NSString *value = [self.controller creatorStringForKey:key];
        if (value.length > 0) {
            [self.creatorPopups[key] selectItemWithTitle:value];
        }
    }
    for (NSString *key in self.creatorColorWells) {
        NSColor *color = [self.controller dragonColorForKey:key fallback:Hex(@"#67d8f4")];
        self.creatorColorWells[key].color = color;
        self.creatorValueLabels[[NSString stringWithFormat:@"color.%@", key]].stringValue = [self.controller dragonColorHexForKey:key];
    }
    [self setNeedsDisplay:YES];
}

- (void)sliderChanged:(NSSlider *)sender {
    NSString *key = sender.identifier;
    [self.controller setCreatorValue:sender.doubleValue forKey:key];
    self.creatorValueLabels[key].stringValue = [self formatValueForKey:key value:[self.controller creatorValueForKey:key]];
    [self syncControlsFromController];
}

- (void)popupChanged:(NSPopUpButton *)sender {
    NSString *value = sender.titleOfSelectedItem;
    if ([value isEqualToString:@"Desktop"]) value = @"";
    [self.controller setCreatorString:value forKey:sender.identifier];
    [self syncControlsFromController];
}

- (void)colorWellChanged:(NSColorWell *)sender {
    [self.controller setDragonColor:sender.color forKey:sender.identifier];
    self.creatorValueLabels[[NSString stringWithFormat:@"color.%@", sender.identifier]].stringValue = [self.controller dragonColorHexForKey:sender.identifier];
}

- (void)nameChanged:(id)sender {
    if (self.nameField.stringValue.length > 0) {
        [self.controller setCreatorString:self.nameField.stringValue forKey:@"name"];
    }
}

- (void)saveLiveClicked:(id)sender {
    [self.controller saveCreature];
    [self.controller bubble:@"saved" seconds:1.4];
}

- (void)saveConfigClicked:(id)sender {
    NSString *name = self.configNameField.stringValue.length ? self.configNameField.stringValue : @"favorite-build";
    [self.controller saveCurrentConfigurationNamed:name];
    [self refreshConfigPopup];
    [self.configPopup selectItemWithTitle:name];
}

- (void)loadConfigClicked:(id)sender {
    if (!self.configPopup.enabled) return;
    [self.controller loadConfigurationNamed:self.configPopup.titleOfSelectedItem];
    [self syncControlsFromController];
}

- (void)addCavePieceClicked:(NSButton *)sender {
    NSString *kind = sender.identifier.length ? sender.identifier : @"rock";
    NSRect scene = [self sceneRect];
    NSSize size = [self cavePieceSizeForKind:kind];
    CGFloat floorY = NSMaxY(scene) - 86;
    CGFloat maxX = MAX(1, scene.size.width - size.width - 36);
    CGFloat x = 18 + arc4random_uniform((uint32_t)maxX);
    CGFloat y = floorY - scene.origin.y - size.height + arc4random_uniform(24);
    if ([kind isEqualToString:@"stalactite"]) {
        y = 16 + arc4random_uniform(52);
    } else if ([kind isEqualToString:@"slab"]) {
        y = floorY - scene.origin.y - size.height + 8 + arc4random_uniform(28);
    } else if ([kind isEqualToString:@"crystal"] || [kind isEqualToString:@"geode"]) {
        y = floorY - scene.origin.y - size.height - 2 + arc4random_uniform(30);
    }
    y = Clamp(y, 0, scene.size.height - size.height);
    NSMutableDictionary *piece = [@{@"kind": kind, @"x": @(x), @"y": @(y)} mutableCopy];
    [self.controller.cavePieces addObject:piece];
    self.selectedCavePieceIndex = (NSInteger)self.controller.cavePieces.count - 1;
    self.draggingCavePieceIndex = -1;
    [self.controller saveCreature];
    [self setNeedsDisplay:YES];
}

- (void)deleteSelectedCavePieceClicked:(id)sender {
    NSInteger index = self.selectedCavePieceIndex;
    if (index < 0) index = self.draggingCavePieceIndex;
    if (index < 0 || index >= (NSInteger)self.controller.cavePieces.count) return;
    [self.controller.cavePieces removeObjectAtIndex:(NSUInteger)index];
    self.draggingCavePieceIndex = -1;
    self.selectedCavePieceIndex = MIN(index, (NSInteger)self.controller.cavePieces.count - 1);
    [self.controller saveCreature];
    [self setNeedsDisplay:YES];
}

- (void)resetCaveClicked:(id)sender {
    [self.controller resetCavePieces];
    self.selectedCavePieceIndex = -1;
    self.draggingCavePieceIndex = -1;
    [self.controller saveCreature];
    [self setNeedsDisplay:YES];
}

- (void)drawStatLabel:(NSString *)label value:(NSString *)value y:(CGFloat)y {
    NSColor *ink = Hex(@"#4b3a3f");
    NSMutableParagraphStyle *left = [[NSMutableParagraphStyle alloc] init];
    left.alignment = NSTextAlignmentLeft;
    NSDictionary *labelAttrs = @{
        NSFontAttributeName: [NSFont fontWithName:@"Avenir Next Heavy" size:12] ?: [NSFont boldSystemFontOfSize:12],
        NSForegroundColorAttributeName: ink,
        NSParagraphStyleAttributeName: left
    };
    NSDictionary *valueAttrs = @{
        NSFontAttributeName: [NSFont fontWithName:@"Avenir Next" size:12] ?: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: ink,
        NSParagraphStyleAttributeName: left
    };
    [label drawInRect:NSMakeRect(224, y, 92, 18) withAttributes:labelAttrs];
    [value drawInRect:NSMakeRect(310, y, 160, 18) withAttributes:valueAttrs];
}

- (void)drawBarAtY:(CGFloat)y value:(CGFloat)value color:(NSColor *)color {
    NSColor *ink = Hex(@"#4b3a3f");
    NSRect frame = NSMakeRect(224, y, 186, 12);
    [Hex(@"#fffaf2") setFill];
    NSRectFill(frame);
    [color setFill];
    NSRectFill(NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width * Clamp(value / 100.0, 0, 1), frame.size.height));
    [ink setStroke];
    NSFrameRectWithWidth(frame, 2);
}

- (void)drawRect:(NSRect)dirtyRect {
    [Hex(@"#2b2226") setFill];
    NSRectFill(dirtyRect);

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    NSColor *ink = Hex(@"#4b3a3f");

    NSRect scene = [self sceneRect];
    NSRect panel = NSMakeRect(w - 338, 28, 316, h - 56);
    void (^rect)(CGFloat, CGFloat, CGFloat, CGFloat, NSColor *) = ^(CGFloat x, CGFloat y, CGFloat rw, CGFloat rh, NSColor *color) {
        [color setFill];
        NSRectFill(NSMakeRect(round(x), round(y), round(rw), round(rh)));
    };

    NSColor *caveInk = Hex(@"#15101a");
    NSColor *deep = Hex(@"#18131f");
    NSColor *wall = Hex(@"#2c2632");
    NSColor *wallMid = Hex(@"#3f3542");
    NSColor *wallLight = Hex(@"#5f5360");
    NSColor *floor = Hex(@"#38323b");
    NSColor *floorLight = Hex(@"#5e535a");
    NSColor *glow = HexAlpha(@"#7df6d2", self.controller.insideHome ? 0.20 : 0.08);

    rect(scene.origin.x - 5, scene.origin.y - 5, scene.size.width + 10, scene.size.height + 10, caveInk);
    rect(scene.origin.x, scene.origin.y, scene.size.width, scene.size.height, deep);
    rect(scene.origin.x + 8, scene.origin.y + 8, scene.size.width - 16, scene.size.height - 16, wall);

    CGFloat backX = scene.origin.x + scene.size.width * 0.58;
    CGFloat backY = scene.origin.y + scene.size.height * 0.30;
    rect(backX - 72, backY - 26, 154, 28, caveInk);
    rect(backX - 96, backY + 2, 202, 64, caveInk);
    rect(backX - 72, backY + 66, 154, 28, caveInk);
    rect(backX - 58, backY + 4, 126, 72, Hex(@"#120d17"));
    rect(backX - 36, backY + 18, 88, 44, HexAlpha(@"#7df6d2", 0.08));

    for (NSInteger i = 0; i < 12; i++) {
        CGFloat x0 = scene.origin.x + 18 + i * 58;
        CGFloat y0 = scene.origin.y + 24 + (i % 4) * 18;
        rect(x0, y0, 42 + (i % 3) * 12, 8, HexAlpha(@"#8d8190", 0.22));
        rect(x0 + 12, y0 + 22, 64, 7, HexAlpha(@"#17101a", 0.24));
    }

    rect(scene.origin.x, scene.origin.y, scene.size.width, 18, caveInk);
    for (NSInteger i = 0; i < 10; i++) {
        CGFloat x0 = scene.origin.x + 24 + i * 74;
        CGFloat h0 = 28 + (i % 4) * 15;
        rect(x0, scene.origin.y + 8, 20, h0, caveInk);
        rect(x0 + 4, scene.origin.y + 9, 12, h0 - 7, wallMid);
        rect(x0 + 34, scene.origin.y + 6, 26, h0 + 18, caveInk);
        rect(x0 + 40, scene.origin.y + 7, 14, h0 + 8, wallLight);
    }

    CGFloat floorY = NSMaxY(scene) - 86;
    rect(scene.origin.x, floorY - 12, scene.size.width, 12, caveInk);
    rect(scene.origin.x, floorY, scene.size.width, NSMaxY(scene) - floorY, floor);
    for (NSInteger i = 0; i < 14; i++) {
        CGFloat x0 = scene.origin.x + i * 54;
        CGFloat step = (i % 4) * 5;
        rect(x0, floorY - step, 62, 8 + step, caveInk);
        rect(x0 + 8, floorY + 10 + (i % 2) * 18, 44, 6, floorLight);
        rect(x0 + 28, floorY + 44 - (i % 3) * 8, 28, 5, Hex(@"#211a24"));
    }

    NSRect nestRect = [self nestRect];
    rect(nestRect.origin.x - 30, nestRect.origin.y - 18, nestRect.size.width + 60, 22, caveInk);
    rect(nestRect.origin.x - 44, nestRect.origin.y + 4, nestRect.size.width + 88, 34, caveInk);
    rect(nestRect.origin.x - 18, nestRect.origin.y + 38, nestRect.size.width + 36, 20, caveInk);
    rect(nestRect.origin.x - 18, nestRect.origin.y - 6, nestRect.size.width + 36, 18, wallMid);
    rect(nestRect.origin.x - 30, nestRect.origin.y + 12, nestRect.size.width + 60, 20, wallLight);
    rect(nestRect.origin.x - 6, nestRect.origin.y + 30, nestRect.size.width + 12, 18, wallMid);
    rect(nestRect.origin.x + 14, nestRect.origin.y + 12, nestRect.size.width - 28, 34, Hex(@"#0f0a12"));
    rect(nestRect.origin.x + 32, nestRect.origin.y + 20, nestRect.size.width - 64, 10, glow);
    rect(nestRect.origin.x - 36, nestRect.origin.y + 34, 34, 18, wallLight);
    rect(nestRect.origin.x + nestRect.size.width + 2, nestRect.origin.y + 30, 38, 22, wallMid);

    for (NSInteger i = 0; i < (NSInteger)self.controller.cavePieces.count; i++) {
        [self drawCavePieceAtIndex:i rect:rect];
    }

    if (self.controller.insideHome) {
        [self drawMiniDragonAt:NSMakePoint(self.controller.habitatX, self.controller.habitatY)];
    }

    rect(panel.origin.x - 4, panel.origin.y - 4, panel.size.width + 8, panel.size.height + 8, ink);
    rect(panel.origin.x, panel.origin.y, panel.size.width, panel.size.height, HexAlpha(@"#fffaf2", 0.96));
    rect(panel.origin.x, panel.origin.y, panel.size.width, 12, Hex(@"#67d8f4"));
    rect(panel.origin.x + panel.size.width - 52, panel.origin.y, 52, 12, Hex(@"#ffdc75"));
}

- (void)mouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger pieceIndex = [self cavePieceIndexAtPoint:point];
    if (pieceIndex >= 0) {
        self.draggingCavePieceIndex = pieceIndex;
        self.selectedCavePieceIndex = pieceIndex;
        NSRect pieceRect = [self cavePieceRectAtIndex:pieceIndex];
        self.cavePieceDragOffset = NSMakePoint(point.x - pieceRect.origin.x, point.y - pieceRect.origin.y);
        self.needsDisplay = YES;
        return;
    }
    NSRect spriteRect = NSMakeRect(self.controller.habitatX, self.controller.habitatY, self.controller.width, self.controller.height);
    if (self.controller.insideHome && NSPointInRect(point, spriteRect)) {
        [self.controller pet];
        return;
    }
    if (NSPointInRect(point, [self nestRect])) {
        if (self.controller.insideHome) {
            [self.controller leaveHome];
        } else {
            [self.controller goHome];
        }
    }
    self.selectedCavePieceIndex = -1;
    self.needsDisplay = YES;
}

- (void)mouseDragged:(NSEvent *)event {
    if (self.draggingCavePieceIndex < 0 || self.draggingCavePieceIndex >= (NSInteger)self.controller.cavePieces.count) return;
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSMutableDictionary *piece = self.controller.cavePieces[(NSUInteger)self.draggingCavePieceIndex];
    NSRect scene = [self sceneRect];
    NSSize size = [self cavePieceSizeForKind:piece[@"kind"] ?: @"rock"];
    CGFloat x = Clamp(point.x - self.cavePieceDragOffset.x - scene.origin.x, 0, scene.size.width - size.width);
    CGFloat y = Clamp(point.y - self.cavePieceDragOffset.y - scene.origin.y, 0, scene.size.height - size.height);
    piece[@"x"] = @(x);
    piece[@"y"] = @(y);
    self.needsDisplay = YES;
}

- (void)mouseUp:(NSEvent *)event {
    if (self.draggingCavePieceIndex >= 0) {
        self.draggingCavePieceIndex = -1;
        [self.controller saveCreature];
        self.needsDisplay = YES;
    }
}

- (void)keyDown:(NSEvent *)event {
    NSString *chars = event.charactersIgnoringModifiers ?: @"";
    if (chars.length > 0) {
        unichar key = [chars characterAtIndex:0];
        if (key == NSDeleteCharacter || key == NSBackspaceCharacter || key == NSDeleteFunctionKey) {
            [self deleteSelectedCavePieceClicked:nil];
            return;
        }
    }
    [super keyDown:event];
}

@end

@implementation DragonController

- (instancetype)init {
    self = [super init];
    if (self) {
        _width = 340;
        _height = 300;
        _homeWidth = 280;
        _homeHeight = 220;
        _homeX = 0;
        _homeY = 0;
        _vx = 1.8;
        _facing = 1;
        _habitatX = 92;
        _habitatY = 400;
        _habitatVX = 1.4;
        _habitatVY = 0;
        _habitatTargetX = 260;
        _habitatTargetY = 400;
        _habitatFacing = 1;
        _lastTick = Now();
        _nextDecision = Now();
        _habitatNextDecision = Now();
        _nextChirp = Now() + 12 + arc4random_uniform(1000) / 1000.0 * 10;
        _birthTime = Now();
        _creatureName = @"Pebble";
        _lifeStage = @"Hatchling";
        _personality = @"curious";
        _favoriteFood = @"Meteor berries";
        _favoriteColor = @"sky blue";
        _lastAppName = @"";
        _bubbleText = @"";
        _bubbleUntil = 0;
        _hunger = 18;
        _affection = 76;
        _energy = 82;
        _curiosity = 58;
        _confidence = 34;
        _levelProgress = 0;
        _warmExposure = 0;
        _coolExposure = 0.35;
        _natureExposure = 0;
        _darkExposure = 0;
        _creativeExposure = 0;
        _codeExposure = 0;
        _partBodyLength = 0.50;
        _partBodyHeight = 0.50;
        _partHeadSize = 0.50;
        _partSnoutLength = 0.35;
        _partHornLength = 0.35;
        _partWingSize = 0.50;
        _partTailLength = 0.50;
        _partLegLength = 0.50;
        _partNeckLength = 0.45;
        _partClawLength = 0.45;
        _partCrestSize = 0.50;
        _partEyeSize = 0.50;
        _partBellySize = 0.50;
        _partCheekSize = 0.50;
        _patternDensity = 0.35;
        _patternColorCount = 2;
        _hornType = @"natural";
        _eyeShape = @"friendly";
        _stance = @"four legs";
        _tailTipType = @"fire tip";
        _wingType = @"normal wings";
        _patternType = @"dots";
        [self resetDragonColors];
        _soundOn = YES;
        _flying = NO;
        _seekingHome = NO;
        _dragging = NO;
        _draggingHome = NO;
        _hoveringDragon = NO;
        _grabbingDragon = NO;
        _insideHome = NO;
        _homeWasDragged = NO;
        _hasCustomHomePosition = NO;
        _menuBarHome = NO;
        _onboardingComplete = NO;
        _habitatFlying = NO;
        _sitting = NO;
        _sitUntil = 0;
        _particles = [NSMutableArray array];
        _cavePieces = [NSMutableArray array];
        _recentApps = [NSMutableArray array];
        [self resetCavePieces];
        _activeSounds = [NSMutableArray array];
        NSScreen *screen = NSScreen.mainScreen;
        _screenFrame = screen ? screen.visibleFrame : NSMakeRect(0, 0, 1200, 800);
        [self loadCreature];
        [self updateDerivedTraits];
    }
    return self;
}

- (CGFloat)randomBetween:(CGFloat)min max:(CGFloat)max {
    if (max <= min) return min;
    return min + (max - min) * (arc4random_uniform(100000) / 100000.0);
}

- (NSString *)randomString:(NSArray<NSString *> *)choices {
    return choices[arc4random_uniform((uint32_t)choices.count)];
}

- (NSURL *)supportDirectoryURL {
    NSURL *base = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [base URLByAppendingPathComponent:@"Snoot" isDirectory:YES];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];

    NSURL *legacyDir = [base URLByAppendingPathComponent:@"Pocket Dragon" isDirectory:YES];
    NSURL *newSave = [dir URLByAppendingPathComponent:@"creature.json"];
    NSURL *legacySave = [legacyDir URLByAppendingPathComponent:@"creature.json"];
    if (![fm fileExistsAtPath:newSave.path] && [fm fileExistsAtPath:legacySave.path]) {
        [fm copyItemAtURL:legacySave toURL:newSave error:nil];
    }

    NSURL *newConfigs = [dir URLByAppendingPathComponent:@"configs" isDirectory:YES];
    NSURL *legacyConfigs = [legacyDir URLByAppendingPathComponent:@"configs" isDirectory:YES];
    BOOL newConfigsIsDir = NO;
    BOOL legacyConfigsIsDir = NO;
    if (![fm fileExistsAtPath:newConfigs.path isDirectory:&newConfigsIsDir] &&
        [fm fileExistsAtPath:legacyConfigs.path isDirectory:&legacyConfigsIsDir] &&
        legacyConfigsIsDir) {
        [fm createDirectoryAtURL:newConfigs withIntermediateDirectories:YES attributes:nil error:nil];
        NSArray<NSURL *> *files = [fm contentsOfDirectoryAtURL:legacyConfigs includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil] ?: @[];
        for (NSURL *file in files) {
            if (![file.pathExtension.lowercaseString isEqualToString:@"json"]) continue;
            NSURL *destination = [newConfigs URLByAppendingPathComponent:file.lastPathComponent];
            if (![fm fileExistsAtPath:destination.path]) {
                [fm copyItemAtURL:file toURL:destination error:nil];
            }
        }
    }
    return dir;
}

- (NSURL *)saveFileURL {
    return [[self supportDirectoryURL] URLByAppendingPathComponent:@"creature.json"];
}

- (NSURL *)configurationDirectoryURL {
    NSURL *dir = [[self supportDirectoryURL] URLByAppendingPathComponent:@"configs" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (NSString *)safeConfigurationName:(NSString *)name {
    NSString *trimmed = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) trimmed = @"favorite-build";
    NSMutableString *safe = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ "];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        [safe appendString:[allowed characterIsMember:c] ? [NSString stringWithCharacters:&c length:1] : @"-"];
    }
    return safe.length ? safe : @"favorite-build";
}

- (NSURL *)configurationURLForName:(NSString *)name {
    NSString *safe = [self safeConfigurationName:name];
    return [[self configurationDirectoryURL] URLByAppendingPathComponent:[safe stringByAppendingPathExtension:@"json"]];
}

- (CGFloat)ageDays {
    return MAX(0, (Now() - self.birthTime) / 86400.0);
}

- (CGFloat)dominantExposure {
    return MAX(MAX(self.warmExposure, self.coolExposure), MAX(self.natureExposure, self.darkExposure));
}

- (void)updateDerivedTraits {
    CGFloat days = [self ageDays];
    if (days < 4) {
        self.lifeStage = @"Hatchling";
    } else if (days < 15) {
        self.lifeStage = @"Juvenile";
    } else if (days < 31) {
        self.lifeStage = @"Adolescent";
    } else if (days < 61) {
        self.lifeStage = @"Adult";
    } else {
        self.lifeStage = @"Elder";
    }

    CGFloat maxExposure = [self dominantExposure];
    if (maxExposure == self.warmExposure && maxExposure > 0.08) {
        self.favoriteColor = @"ember coral";
    } else if (maxExposure == self.natureExposure && maxExposure > 0.08) {
        self.favoriteColor = @"moss green";
    } else if (maxExposure == self.darkExposure && maxExposure > 0.08) {
        self.favoriteColor = @"moonlit violet";
    } else {
        self.favoriteColor = @"sky blue";
    }

    if (self.favoriteFood.length == 0) {
        self.favoriteFood = @"meteor berries";
    }

    self.levelProgress = Clamp(days / 60.0 + (self.affection + self.curiosity + self.confidence) / 900.0, 0, 1);
}

- (void)resetDragonColors {
    self.colorOutline = @"#171126";
    self.colorDeepOutline = @"#080710";
    self.colorBody = @"#67D8F4";
    self.colorHighlight = @"#DDA7FD";
    self.colorBelly = @"#FFDC75";
    self.colorWing = @"#43C2E7";
    self.colorHorn = @"#FFDC75";
    self.colorCrest = @"#FF686E";
    self.colorEye = @"#3CDFFF";
    self.colorCheek = @"#FF9AB0";
    self.colorClaw = @"#FFF1B5";
    self.colorPattern1 = @"#F4A8FF";
    self.colorPattern2 = @"#FF686E";
    self.colorPattern3 = @"#FFDC75";
    self.colorFlameOuter = @"#7C2EFF";
    self.colorFlameMid = @"#FF4BD6";
    self.colorFlameCore = @"#FFF0A8";
}

- (void)applyPaletteNamed:(NSString *)paletteName {
    NSString *name = paletteName ?: @"Carbon Cardinal";
    if ([name isEqualToString:@"Carbon Cardinal"]) {
        self.colorOutline = @"#1A0709";
        self.colorDeepOutline = @"#050304";
        self.colorBody = @"#161316";
        self.colorHighlight = @"#7A1F2A";
        self.colorBelly = @"#F2ECE4";
        self.colorWing = @"#AA1422";
        self.colorHorn = @"#F3F0E8";
        self.colorCrest = @"#D51D2E";
        self.colorEye = @"#F04B5D";
        self.colorCheek = @"#8C1826";
        self.colorClaw = @"#F8E7D2";
        self.colorPattern1 = @"#D51D2E";
        self.colorPattern2 = @"#F2ECE4";
        self.colorPattern3 = @"#5A0F19";
        self.colorFlameOuter = @"#A10E1C";
        self.colorFlameMid = @"#F22C3D";
        self.colorFlameCore = @"#FFE8B8";
        self.favoriteColor = @"carbon cardinal";
    } else if ([name isEqualToString:@"Black Cherry"]) {
        self.colorOutline = @"#130609";
        self.colorDeepOutline = @"#020103";
        self.colorBody = @"#0E0B10";
        self.colorHighlight = @"#74223C";
        self.colorBelly = @"#D9D0C7";
        self.colorWing = @"#731021";
        self.colorHorn = @"#E9DFD3";
        self.colorCrest = @"#C31631";
        self.colorEye = @"#FF6C8B";
        self.colorCheek = @"#A61A35";
        self.colorClaw = @"#E8D4C0";
        self.colorPattern1 = @"#B41127";
        self.colorPattern2 = @"#B7A7A0";
        self.colorPattern3 = @"#3B0A11";
        self.colorFlameOuter = @"#5D0D18";
        self.colorFlameMid = @"#D91F3E";
        self.colorFlameCore = @"#FFD1C9";
        self.favoriteColor = @"black cherry";
    } else if ([name isEqualToString:@"Ash Rose"]) {
        self.colorOutline = @"#201719";
        self.colorDeepOutline = @"#0A0708";
        self.colorBody = @"#242126";
        self.colorHighlight = @"#B86A73";
        self.colorBelly = @"#E8E1D8";
        self.colorWing = @"#A43B4E";
        self.colorHorn = @"#F3EEE3";
        self.colorCrest = @"#C94859";
        self.colorEye = @"#F7A0A7";
        self.colorCheek = @"#E36E7A";
        self.colorClaw = @"#F4E4CD";
        self.colorPattern1 = @"#D54A5E";
        self.colorPattern2 = @"#E8E1D8";
        self.colorPattern3 = @"#68404C";
        self.colorFlameOuter = @"#8E2435";
        self.colorFlameMid = @"#F06069";
        self.colorFlameCore = @"#FFF0C8";
        self.favoriteColor = @"ash rose";
    } else if ([name isEqualToString:@"Glacier"]) {
        self.colorOutline = @"#171126";
        self.colorDeepOutline = @"#080710";
        self.colorBody = @"#67D8F4";
        self.colorHighlight = @"#DDA7FD";
        self.colorBelly = @"#FFDC75";
        self.colorWing = @"#43C2E7";
        self.colorHorn = @"#FFDC75";
        self.colorCrest = @"#FF686E";
        self.colorEye = @"#3CDFFF";
        self.colorCheek = @"#FF9AB0";
        self.colorClaw = @"#FFF1B5";
        self.colorPattern1 = @"#F4A8FF";
        self.colorPattern2 = @"#FF686E";
        self.colorPattern3 = @"#FFDC75";
        self.colorFlameOuter = @"#7C2EFF";
        self.colorFlameMid = @"#FF4BD6";
        self.colorFlameCore = @"#FFF0A8";
        self.favoriteColor = @"sky blue";
    } else if ([name isEqualToString:@"Moss"]) {
        self.colorOutline = @"#172317";
        self.colorDeepOutline = @"#071007";
        self.colorBody = @"#3D7A4D";
        self.colorHighlight = @"#9EE477";
        self.colorBelly = @"#E8D87B";
        self.colorWing = @"#5AA86E";
        self.colorHorn = @"#EFDCA0";
        self.colorCrest = @"#72C977";
        self.colorEye = @"#B9F2A3";
        self.colorCheek = @"#F0A07C";
        self.colorClaw = @"#FFF1B5";
        self.colorPattern1 = @"#BDE783";
        self.colorPattern2 = @"#69C07A";
        self.colorPattern3 = @"#F0D47A";
        self.colorFlameOuter = @"#438F64";
        self.colorFlameMid = @"#9EE477";
        self.colorFlameCore = @"#FFF2A6";
        self.favoriteColor = @"moss green";
    }
    [self redrawCreatureSurfaces];
}

- (NSString *)dragonColorHexForKey:(NSString *)key {
    if ([key isEqualToString:@"outline"]) return self.colorOutline ?: @"#171126";
    if ([key isEqualToString:@"deepOutline"]) return self.colorDeepOutline ?: @"#080710";
    if ([key isEqualToString:@"body"]) return self.colorBody ?: @"#67D8F4";
    if ([key isEqualToString:@"highlight"]) return self.colorHighlight ?: @"#DDA7FD";
    if ([key isEqualToString:@"belly"]) return self.colorBelly ?: @"#FFDC75";
    if ([key isEqualToString:@"wing"]) return self.colorWing ?: @"#43C2E7";
    if ([key isEqualToString:@"horn"]) return self.colorHorn ?: @"#FFDC75";
    if ([key isEqualToString:@"crest"]) return self.colorCrest ?: @"#FF686E";
    if ([key isEqualToString:@"eye"]) return self.colorEye ?: @"#3CDFFF";
    if ([key isEqualToString:@"cheek"]) return self.colorCheek ?: @"#FF9AB0";
    if ([key isEqualToString:@"claw"]) return self.colorClaw ?: @"#FFF1B5";
    if ([key isEqualToString:@"pattern1"]) return self.colorPattern1 ?: @"#F4A8FF";
    if ([key isEqualToString:@"pattern2"]) return self.colorPattern2 ?: @"#FF686E";
    if ([key isEqualToString:@"pattern3"]) return self.colorPattern3 ?: @"#FFDC75";
    if ([key isEqualToString:@"flameOuter"]) return self.colorFlameOuter ?: @"#7C2EFF";
    if ([key isEqualToString:@"flameMid"]) return self.colorFlameMid ?: @"#FF4BD6";
    if ([key isEqualToString:@"flameCore"]) return self.colorFlameCore ?: @"#FFF0A8";
    return @"#67D8F4";
}

- (NSColor *)dragonColorForKey:(NSString *)key fallback:(NSColor *)fallback {
    return HexOrFallback([self dragonColorHexForKey:key], fallback);
}

- (void)setDragonColor:(NSColor *)color forKey:(NSString *)key {
    NSString *hex = HexStringFromColor(color);
    if ([key isEqualToString:@"outline"]) self.colorOutline = hex;
    else if ([key isEqualToString:@"deepOutline"]) self.colorDeepOutline = hex;
    else if ([key isEqualToString:@"body"]) self.colorBody = hex;
    else if ([key isEqualToString:@"highlight"]) self.colorHighlight = hex;
    else if ([key isEqualToString:@"belly"]) self.colorBelly = hex;
    else if ([key isEqualToString:@"wing"]) self.colorWing = hex;
    else if ([key isEqualToString:@"horn"]) self.colorHorn = hex;
    else if ([key isEqualToString:@"crest"]) self.colorCrest = hex;
    else if ([key isEqualToString:@"eye"]) self.colorEye = hex;
    else if ([key isEqualToString:@"cheek"]) self.colorCheek = hex;
    else if ([key isEqualToString:@"claw"]) self.colorClaw = hex;
    else if ([key isEqualToString:@"pattern1"]) self.colorPattern1 = hex;
    else if ([key isEqualToString:@"pattern2"]) self.colorPattern2 = hex;
    else if ([key isEqualToString:@"pattern3"]) self.colorPattern3 = hex;
    else if ([key isEqualToString:@"flameOuter"]) self.colorFlameOuter = hex;
    else if ([key isEqualToString:@"flameMid"]) self.colorFlameMid = hex;
    else if ([key isEqualToString:@"flameCore"]) self.colorFlameCore = hex;
    [self redrawCreatureSurfaces];
    [self saveCreature];
}

- (NSDictionary *)creatureSnapshot {
    [self updateDerivedTraits];
    return @{
        @"schema": @1,
        @"name": self.creatureName ?: @"Pebble",
        @"species": @"dragon",
        @"birthTime": @(self.birthTime),
        @"lifeStage": self.lifeStage ?: @"Hatchling",
        @"personality": self.personality ?: @"curious",
        @"onboardingComplete": @(self.onboardingComplete),
        @"favoriteFood": self.favoriteFood ?: @"meteor berries",
        @"favoriteColor": self.favoriteColor ?: @"sky blue",
        @"lastAppName": self.lastAppName ?: @"",
        @"recentApps": self.recentApps ?: @[],
        @"hunger": @(self.hunger),
        @"affection": @(self.affection),
        @"energy": @(self.energy),
        @"curiosity": @(self.curiosity),
        @"confidence": @(self.confidence),
        @"levelProgress": @(self.levelProgress),
        @"exposure": @{
            @"warm": @(self.warmExposure),
            @"cool": @(self.coolExposure),
            @"nature": @(self.natureExposure),
            @"dark": @(self.darkExposure),
            @"creative": @(self.creativeExposure),
            @"code": @(self.codeExposure)
        },
        @"parts": @{
            @"bodyLength": @(self.partBodyLength),
            @"bodyHeight": @(self.partBodyHeight),
            @"headSize": @(self.partHeadSize),
            @"snoutLength": @(self.partSnoutLength),
            @"hornLength": @(self.partHornLength),
            @"wingSize": @(self.partWingSize),
            @"tailLength": @(self.partTailLength),
            @"legLength": @(self.partLegLength),
            @"neckLength": @(self.partNeckLength),
            @"clawLength": @(self.partClawLength),
            @"crestSize": @(self.partCrestSize),
            @"eyeSize": @(self.partEyeSize),
            @"bellySize": @(self.partBellySize),
            @"cheekSize": @(self.partCheekSize),
            @"patternDensity": @(self.patternDensity),
            @"patternColorCount": @(round(Clamp(self.patternColorCount, 1, 3)))
        },
        @"style": @{
            @"hornType": self.hornType ?: @"natural",
            @"eyeShape": self.eyeShape ?: @"friendly",
            @"stance": self.stance ?: @"four legs",
            @"tailTip": self.tailTipType ?: @"fire tip",
            @"wingType": self.wingType ?: @"normal wings",
            @"patternType": self.patternType ?: @"dots"
        },
        @"colors": @{
            @"outline": [self dragonColorHexForKey:@"outline"],
            @"deepOutline": [self dragonColorHexForKey:@"deepOutline"],
            @"body": [self dragonColorHexForKey:@"body"],
            @"highlight": [self dragonColorHexForKey:@"highlight"],
            @"belly": [self dragonColorHexForKey:@"belly"],
            @"wing": [self dragonColorHexForKey:@"wing"],
            @"horn": [self dragonColorHexForKey:@"horn"],
            @"crest": [self dragonColorHexForKey:@"crest"],
            @"eye": [self dragonColorHexForKey:@"eye"],
            @"cheek": [self dragonColorHexForKey:@"cheek"],
            @"claw": [self dragonColorHexForKey:@"claw"],
            @"pattern1": [self dragonColorHexForKey:@"pattern1"],
            @"pattern2": [self dragonColorHexForKey:@"pattern2"],
            @"pattern3": [self dragonColorHexForKey:@"pattern3"],
            @"flameOuter": [self dragonColorHexForKey:@"flameOuter"],
            @"flameMid": [self dragonColorHexForKey:@"flameMid"],
            @"flameCore": [self dragonColorHexForKey:@"flameCore"]
        },
        @"location": @{
            @"insideHome": @(self.insideHome),
            @"habitatX": @(self.habitatX),
            @"habitatY": @(self.habitatY),
            @"habitatFacing": @(self.habitatFacing)
        },
        @"cavePieces": self.cavePieces ?: @[],
        @"home": @{
            @"x": @(self.homeX),
            @"y": @(self.homeY),
            @"custom": @(self.hasCustomHomePosition),
            @"menuBar": @(self.menuBarHome)
        }
    };
}

- (void)applyCreatureDictionary:(NSDictionary *)json {
    if (![json isKindOfClass:NSDictionary.class]) return;
    self.creatureName = json[@"name"] ?: self.creatureName;
    self.birthTime = [json[@"birthTime"] doubleValue] ?: self.birthTime;
    self.lifeStage = json[@"lifeStage"] ?: self.lifeStage;
    self.personality = json[@"personality"] ?: self.personality;
    self.onboardingComplete = json[@"onboardingComplete"] ? [json[@"onboardingComplete"] boolValue] : self.onboardingComplete;
    self.favoriteFood = json[@"favoriteFood"] ?: self.favoriteFood;
    self.favoriteColor = json[@"favoriteColor"] ?: self.favoriteColor;
    self.lastAppName = json[@"lastAppName"] ?: self.lastAppName;
    NSArray *recent = json[@"recentApps"];
    if ([recent isKindOfClass:NSArray.class]) {
        [self.recentApps removeAllObjects];
        for (NSString *app in recent) {
            if (![app isKindOfClass:NSString.class] || app.length == 0) continue;
            if (![self.recentApps containsObject:app]) {
                [self.recentApps addObject:app];
            }
            if (self.recentApps.count >= 6) break;
        }
    }
    self.hunger = json[@"hunger"] ? [json[@"hunger"] doubleValue] : self.hunger;
    self.affection = json[@"affection"] ? [json[@"affection"] doubleValue] : self.affection;
    self.energy = json[@"energy"] ? [json[@"energy"] doubleValue] : self.energy;
    self.curiosity = json[@"curiosity"] ? [json[@"curiosity"] doubleValue] : self.curiosity;
    self.confidence = json[@"confidence"] ? [json[@"confidence"] doubleValue] : self.confidence;
    self.levelProgress = json[@"levelProgress"] ? [json[@"levelProgress"] doubleValue] : self.levelProgress;

    NSDictionary *exposure = json[@"exposure"];
    if ([exposure isKindOfClass:NSDictionary.class]) {
        self.warmExposure = exposure[@"warm"] ? [exposure[@"warm"] doubleValue] : self.warmExposure;
        self.coolExposure = exposure[@"cool"] ? [exposure[@"cool"] doubleValue] : self.coolExposure;
        self.natureExposure = exposure[@"nature"] ? [exposure[@"nature"] doubleValue] : self.natureExposure;
        self.darkExposure = exposure[@"dark"] ? [exposure[@"dark"] doubleValue] : self.darkExposure;
        self.creativeExposure = exposure[@"creative"] ? [exposure[@"creative"] doubleValue] : self.creativeExposure;
        self.codeExposure = exposure[@"code"] ? [exposure[@"code"] doubleValue] : self.codeExposure;
    }

    NSDictionary *parts = json[@"parts"];
    if ([parts isKindOfClass:NSDictionary.class]) {
        self.partBodyLength = parts[@"bodyLength"] ? Clamp([parts[@"bodyLength"] doubleValue], 0, 1) : self.partBodyLength;
        self.partBodyHeight = parts[@"bodyHeight"] ? Clamp([parts[@"bodyHeight"] doubleValue], 0, 1) : self.partBodyHeight;
        self.partHeadSize = parts[@"headSize"] ? Clamp([parts[@"headSize"] doubleValue], 0, 1) : self.partHeadSize;
        self.partSnoutLength = parts[@"snoutLength"] ? Clamp([parts[@"snoutLength"] doubleValue], 0, 1) : self.partSnoutLength;
        self.partHornLength = parts[@"hornLength"] ? Clamp([parts[@"hornLength"] doubleValue], 0, 1) : self.partHornLength;
        self.partWingSize = parts[@"wingSize"] ? Clamp([parts[@"wingSize"] doubleValue], 0, 1) : self.partWingSize;
        self.partTailLength = parts[@"tailLength"] ? Clamp([parts[@"tailLength"] doubleValue], 0, 1) : self.partTailLength;
        self.partLegLength = parts[@"legLength"] ? Clamp([parts[@"legLength"] doubleValue], 0, 1) : self.partLegLength;
        self.partNeckLength = parts[@"neckLength"] ? Clamp([parts[@"neckLength"] doubleValue], 0, 1) : self.partNeckLength;
        self.partClawLength = parts[@"clawLength"] ? Clamp([parts[@"clawLength"] doubleValue], 0, 1) : self.partClawLength;
        self.partCrestSize = parts[@"crestSize"] ? Clamp([parts[@"crestSize"] doubleValue], 0, 1) : self.partCrestSize;
        self.partEyeSize = parts[@"eyeSize"] ? Clamp([parts[@"eyeSize"] doubleValue], 0, 1) : self.partEyeSize;
        self.partBellySize = parts[@"bellySize"] ? Clamp([parts[@"bellySize"] doubleValue], 0, 1) : self.partBellySize;
        self.partCheekSize = parts[@"cheekSize"] ? Clamp([parts[@"cheekSize"] doubleValue], 0, 1) : self.partCheekSize;
        self.patternDensity = parts[@"patternDensity"] ? Clamp([parts[@"patternDensity"] doubleValue], 0, 1) : self.patternDensity;
        self.patternColorCount = parts[@"patternColorCount"] ? Clamp([parts[@"patternColorCount"] doubleValue], 1, 3) : self.patternColorCount;
    }

    NSDictionary *style = json[@"style"];
    if ([style isKindOfClass:NSDictionary.class]) {
        self.hornType = style[@"hornType"] ?: self.hornType;
        self.eyeShape = style[@"eyeShape"] ?: self.eyeShape;
        self.stance = style[@"stance"] ?: self.stance;
        self.tailTipType = style[@"tailTip"] ?: self.tailTipType;
        self.wingType = style[@"wingType"] ?: self.wingType;
        self.patternType = style[@"patternType"] ?: self.patternType;
    }

    NSDictionary *colors = json[@"colors"];
    if ([colors isKindOfClass:NSDictionary.class]) {
        if ([colors[@"outline"] isKindOfClass:NSString.class]) self.colorOutline = colors[@"outline"];
        if ([colors[@"deepOutline"] isKindOfClass:NSString.class]) self.colorDeepOutline = colors[@"deepOutline"];
        if ([colors[@"body"] isKindOfClass:NSString.class]) self.colorBody = colors[@"body"];
        if ([colors[@"highlight"] isKindOfClass:NSString.class]) self.colorHighlight = colors[@"highlight"];
        if ([colors[@"belly"] isKindOfClass:NSString.class]) self.colorBelly = colors[@"belly"];
        if ([colors[@"wing"] isKindOfClass:NSString.class]) self.colorWing = colors[@"wing"];
        if ([colors[@"horn"] isKindOfClass:NSString.class]) self.colorHorn = colors[@"horn"];
        if ([colors[@"crest"] isKindOfClass:NSString.class]) self.colorCrest = colors[@"crest"];
        if ([colors[@"eye"] isKindOfClass:NSString.class]) self.colorEye = colors[@"eye"];
        if ([colors[@"cheek"] isKindOfClass:NSString.class]) self.colorCheek = colors[@"cheek"];
        if ([colors[@"claw"] isKindOfClass:NSString.class]) self.colorClaw = colors[@"claw"];
        if ([colors[@"pattern1"] isKindOfClass:NSString.class]) self.colorPattern1 = colors[@"pattern1"];
        if ([colors[@"pattern2"] isKindOfClass:NSString.class]) self.colorPattern2 = colors[@"pattern2"];
        if ([colors[@"pattern3"] isKindOfClass:NSString.class]) self.colorPattern3 = colors[@"pattern3"];
        if ([colors[@"flameOuter"] isKindOfClass:NSString.class]) self.colorFlameOuter = colors[@"flameOuter"];
        if ([colors[@"flameMid"] isKindOfClass:NSString.class]) self.colorFlameMid = colors[@"flameMid"];
        if ([colors[@"flameCore"] isKindOfClass:NSString.class]) self.colorFlameCore = colors[@"flameCore"];
    }

    NSDictionary *location = json[@"location"];
    if ([location isKindOfClass:NSDictionary.class]) {
        self.insideHome = location[@"insideHome"] ? [location[@"insideHome"] boolValue] : self.insideHome;
        if (location[@"habitatX"]) self.habitatX = [location[@"habitatX"] doubleValue];
        if (location[@"habitatY"]) self.habitatY = [location[@"habitatY"] doubleValue];
        if (location[@"habitatFacing"]) self.habitatFacing = [location[@"habitatFacing"] doubleValue] >= 0 ? 1 : -1;
    }

    NSDictionary *home = json[@"home"];
    if ([home isKindOfClass:NSDictionary.class]) {
        if (home[@"x"]) self.homeX = [home[@"x"] doubleValue];
        if (home[@"y"]) self.homeY = [home[@"y"] doubleValue];
        self.hasCustomHomePosition = home[@"custom"] ? [home[@"custom"] boolValue] : self.hasCustomHomePosition;
        self.menuBarHome = home[@"menuBar"] ? [home[@"menuBar"] boolValue] : self.menuBarHome;
    }
    NSArray *pieces = json[@"cavePieces"];
    if ([pieces isKindOfClass:NSArray.class]) {
        [self.cavePieces removeAllObjects];
        for (NSDictionary *piece in pieces) {
            if (![piece isKindOfClass:NSDictionary.class]) continue;
            NSString *kind = [piece[@"kind"] isKindOfClass:NSString.class] ? piece[@"kind"] : @"rock";
            NSNumber *x = [piece[@"x"] isKindOfClass:NSNumber.class] ? piece[@"x"] : @80;
            NSNumber *y = [piece[@"y"] isKindOfClass:NSNumber.class] ? piece[@"y"] : @330;
            [self.cavePieces addObject:[@{@"kind": kind, @"x": x, @"y": y} mutableCopy]];
        }
    }
    if (self.cavePieces.count == 0) {
        [self resetCavePieces];
    }
    [self updateDerivedTraits];
}

- (void)resetCavePieces {
    [self.cavePieces removeAllObjects];
    NSArray<NSDictionary *> *defaults = @[
        @{@"kind": @"stalactite", @"x": @70, @"y": @22},
        @{@"kind": @"boulder", @"x": @58, @"y": @356},
        @{@"kind": @"pebbles", @"x": @182, @"y": @398},
        @{@"kind": @"slab", @"x": @284, @"y": @408},
        @{@"kind": @"crystal", @"x": @420, @"y": @326},
        @{@"kind": @"geode", @"x": @510, @"y": @364},
        @{@"kind": @"moss", @"x": @318, @"y": @424},
        @{@"kind": @"stalagmite", @"x": @474, @"y": @342}
    ];
    for (NSDictionary *piece in defaults) {
        [self.cavePieces addObject:[piece mutableCopy]];
    }
    [self.habitatView setNeedsDisplay:YES];
}

- (void)loadCreature {
    NSData *data = [NSData dataWithContentsOfURL:[self saveFileURL]];
    if (!data) {
        [self saveCreature];
        return;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    [self applyCreatureDictionary:json];
}

- (void)saveCreature {
    NSDictionary *snapshot = [self creatureSnapshot];
    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [data writeToURL:[self saveFileURL] atomically:YES];
        self.lastSaved = Now();
    }
}

- (void)syncDesktopVisibilityForLocation {
    if (self.insideHome) {
        [self.window orderOut:nil];
    } else if (self.window) {
        [self.window orderFrontRegardless];
    }
    [self updateMenuBarBurrow];
    [self.homeView setNeedsDisplay:YES];
    [self.habitatView setNeedsDisplay:YES];
}

- (void)show {
    NSScreen *screen = NSScreen.mainScreen;
    self.screenFrame = screen ? screen.visibleFrame : self.screenFrame;
    [self showHome];
    self.x = [self randomBetween:NSMinX(self.screenFrame) + 30 max:MAX(NSMinX(self.screenFrame) + 31, NSMaxX(self.screenFrame) - self.width - 30)];
    self.y = NSMinY(self.screenFrame) - [self footOffset];
    self.targetX = self.x;
    self.targetY = self.y;

    self.window = [[DragonWindow alloc] initWithContentRect:NSMakeRect(self.x, self.y, self.width, self.height)
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    self.window.backgroundColor = NSColor.clearColor;
    self.window.opaque = NO;
    self.window.hasShadow = NO;
    self.window.level = NSFloatingWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.window.ignoresMouseEvents = NO;
    self.window.acceptsMouseMovedEvents = YES;

    self.view = [[DragonView alloc] initWithFrame:NSMakeRect(0, 0, self.width, self.height)];
    self.view.controller = self;
    self.window.contentView = self.view;
    if (self.insideHome) {
        [self.window orderOut:nil];
    } else {
        [self.window makeKeyAndOrderFront:nil];
        [self.window orderFrontRegardless];
    }

    [self chooseTarget];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)showOnboardingIfNeeded {
    if (self.onboardingComplete) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showOnboarding:nil];
    });
}

- (NSTextField *)onboardingLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.selectable = NO;
    label.bordered = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.textColor = Hex(@"#31262c");
    label.font = [NSFont fontWithName:@"Avenir Next Demi Bold" size:12] ?: [NSFont boldSystemFontOfSize:12];
    return label;
}

- (void)showOnboarding:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = self.onboardingComplete ? @"Tune your Snoot" : @"Meet Snoot";
    alert.informativeText = @"Pick a name, vibe, and starter palette. You can keep customizing from the burrow later.";

    NSView *panel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 350, 186)];
    NSTextField *nameLabel = [self onboardingLabel:@"Name" frame:NSMakeRect(0, 158, 110, 18)];
    [panel addSubview:nameLabel];
    NSTextField *nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(118, 154, 220, 24)];
    nameField.stringValue = self.creatureName.length ? self.creatureName : @"Snoot";
    [panel addSubview:nameField];

    [panel addSubview:[self onboardingLabel:@"Palette" frame:NSMakeRect(0, 120, 110, 18)]];
    NSPopUpButton *palette = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(114, 116, 226, 26)];
    [palette addItemsWithTitles:@[@"Carbon Cardinal", @"Black Cherry", @"Ash Rose", @"Glacier", @"Moss"]];
    [palette selectItemWithTitle:@"Carbon Cardinal"];
    [panel addSubview:palette];

    [panel addSubview:[self onboardingLabel:@"Personality" frame:NSMakeRect(0, 82, 110, 18)]];
    NSPopUpButton *vibe = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(114, 78, 226, 26)];
    [vibe addItemsWithTitles:@[@"curious", @"cozy", @"mischievous"]];
    if (self.personality.length) [vibe selectItemWithTitle:self.personality];
    [panel addSubview:vibe];

    NSButton *bar = [NSButton checkboxWithTitle:@"Use menu bar burrow" target:nil action:nil];
    bar.frame = NSMakeRect(114, 42, 220, 24);
    bar.state = self.menuBarHome ? NSControlStateValueOn : NSControlStateValueOff;
    [panel addSubview:bar];

    NSTextField *note = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 340, 34)];
    note.stringValue = @"Snoot grows subtly from screen colors and the apps it spends time around.";
    note.editable = NO;
    note.selectable = NO;
    note.bordered = NO;
    note.bezeled = NO;
    note.drawsBackground = NO;
    note.textColor = Hex(@"#5b4d54");
    note.font = [NSFont fontWithName:@"Avenir Next" size:12] ?: [NSFont systemFontOfSize:12];
    [panel addSubview:note];

    alert.accessoryView = panel;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    self.creatureName = nameField.stringValue.length ? nameField.stringValue : @"Snoot";
    self.personality = vibe.titleOfSelectedItem.length ? vibe.titleOfSelectedItem : @"curious";
    self.menuBarHome = bar.state == NSControlStateValueOn;
    [self applyPaletteNamed:palette.titleOfSelectedItem];
    self.onboardingComplete = YES;
    [self updateMenuBarBurrow];
    if (self.menuBarHome) {
        [self.homeWindow orderOut:nil];
    } else if (self.homeWindow) {
        [self.homeWindow orderFrontRegardless];
    }
    [self saveCreature];
    [self syncHabitatControls];
}

- (NSPoint)defaultHomeOrigin {
    return NSMakePoint(NSMidX(self.screenFrame) - self.homeWidth / 2, NSMaxY(self.screenFrame) - self.homeHeight);
}

- (NSPoint)clampedHomeOrigin:(NSPoint)origin {
    CGFloat minX = NSMinX(self.screenFrame) + 8;
    CGFloat maxX = MAX(minX, NSMaxX(self.screenFrame) - self.homeWidth - 8);
    CGFloat minY = NSMinY(self.screenFrame) + 8;
    CGFloat maxY = MAX(minY, NSMaxY(self.screenFrame) - self.homeHeight + 16);
    return NSMakePoint(Clamp(origin.x, minX, maxX), Clamp(origin.y, minY, maxY));
}

- (void)showHome {
    NSPoint origin = self.hasCustomHomePosition ? NSMakePoint(self.homeX, self.homeY) : [self defaultHomeOrigin];
    origin = [self clampedHomeOrigin:origin];
    self.homeX = origin.x;
    self.homeY = origin.y;
    self.homeWindow = [[DragonWindow alloc] initWithContentRect:NSMakeRect(origin.x, origin.y, self.homeWidth, self.homeHeight)
                                                      styleMask:NSWindowStyleMaskBorderless
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
    self.homeWindow.backgroundColor = NSColor.clearColor;
    self.homeWindow.opaque = NO;
    self.homeWindow.hasShadow = NO;
    self.homeWindow.level = NSFloatingWindowLevel;
    self.homeWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.homeWindow.acceptsMouseMovedEvents = YES;
    self.homeView = [[HomeView alloc] initWithFrame:NSMakeRect(0, 0, self.homeWidth, self.homeHeight)];
    self.homeView.controller = self;
    self.homeWindow.contentView = self.homeView;
    [self updateMenuBarBurrow];
    if (self.menuBarHome) {
        [self.homeWindow orderOut:nil];
    } else {
        [self.homeWindow orderFrontRegardless];
    }
}

- (void)refreshBounds:(NSTimeInterval)current {
    if (current < self.nextBoundsCheck) return;
    NSScreen *screen = NSScreen.mainScreen;
    self.screenFrame = screen ? screen.visibleFrame : self.screenFrame;
    if (self.homeWindow) {
        NSPoint origin = self.hasCustomHomePosition ? self.homeWindow.frame.origin : [self defaultHomeOrigin];
        origin = [self clampedHomeOrigin:origin];
        self.homeX = origin.x;
        self.homeY = origin.y;
        [self.homeWindow setFrameOrigin:origin];
    }
    [self updateMenuBarBurrow];
    self.nextBoundsCheck = current + 2;
}

- (NSImage *)statusIconImage {
    NSURL *url = [NSBundle.mainBundle URLForResource:@"SnootStatusIcon" withExtension:@"png"];
    NSImage *image = url ? [[NSImage alloc] initWithContentsOfURL:url] : nil;
    if (image) {
        image.size = NSMakeSize(18, 18);
        image.template = YES;
    }
    return image;
}

- (NSMenu *)makeStatusMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Snoot"];
    NSMenuItem *open = [menu addItemWithTitle:@"Open Burrow" action:@selector(openHabitat) keyEquivalent:@""];
    open.target = self;
    NSMenuItem *home = [menu addItemWithTitle:self.insideHome ? @"Call Snoot Out" : @"Send Snoot Home" action:(self.insideHome ? @selector(leaveHome) : @selector(goHome)) keyEquivalent:@""];
    home.target = self;
    NSMenuItem *customize = [menu addItemWithTitle:@"Customize Snoot..." action:@selector(openHabitat) keyEquivalent:@""];
    customize.target = self;
    NSMenuItem *setup = [menu addItemWithTitle:@"Set Up Snoot..." action:@selector(showOnboarding:) keyEquivalent:@""];
    setup.target = self;
    NSMenuItem *share = [menu addItemWithTitle:@"Share Snoot..." action:@selector(shareSnoot) keyEquivalent:@""];
    share.target = self;
    NSMenuItem *copy = [menu addItemWithTitle:@"Copy Share Image" action:@selector(copyShareImage) keyEquivalent:@""];
    copy.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *toggle = [menu addItemWithTitle:@"Use Menu Bar Burrow" action:@selector(toggleMenuBarBurrow) keyEquivalent:@""];
    toggle.target = self;
    toggle.state = self.menuBarHome ? NSControlStateValueOn : NSControlStateValueOff;
    NSMenuItem *sound = [menu addItemWithTitle:@"Sound chirps" action:@selector(toggleSound) keyEquivalent:@""];
    sound.target = self;
    sound.state = self.soundOn ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [menu addItemWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@""];
    quit.target = self;
    return menu;
}

- (void)updateMenuBarBurrow {
    if (self.menuBarHome) {
        if (!self.statusItem) {
            self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
            NSImage *icon = [self statusIconImage];
            if (icon) {
                self.statusItem.button.image = icon;
                self.statusItem.button.title = @"";
            } else {
                self.statusItem.button.title = @"S";
            }
            self.statusItem.button.toolTip = @"Snoot burrow";
        }
        self.statusItem.menu = [self makeStatusMenu];
    } else if (self.statusItem) {
        [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
        self.statusItem = nil;
    }
}

- (NSRect)menuBarBurrowFrame {
    [self updateMenuBarBurrow];
    if (self.statusItem.button.window) {
        NSRect buttonRect = [self.statusItem.button convertRect:self.statusItem.button.bounds toView:nil];
        buttonRect = [self.statusItem.button.window convertRectToScreen:buttonRect];
        if (!NSIsEmptyRect(buttonRect)) {
            return NSInsetRect(buttonRect, -34, -8);
        }
    }
    NSScreen *screen = NSScreen.mainScreen;
    NSRect frame = screen ? screen.frame : self.screenFrame;
    return NSMakeRect(NSMaxX(frame) - 180, NSMaxY(frame) - 28, 112, 28);
}

- (void)toggleMenuBarBurrow {
    self.menuBarHome = !self.menuBarHome;
    [self updateMenuBarBurrow];
    if (self.menuBarHome) {
        [self.homeWindow orderOut:nil];
        [self bubble:@"bar burrow" seconds:1.6];
    } else {
        [self.homeWindow orderFrontRegardless];
        [self bubble:@"desktop burrow" seconds:1.6];
    }
    [self saveCreature];
    [self.homeView setNeedsDisplay:YES];
}

- (void)updateNeeds:(NSTimeInterval)dt {
    self.hunger = MIN(100, self.hunger + dt * 1.05);
    self.affection = MAX(0, self.affection - dt * 0.35);
}

- (void)maybeChirp:(NSTimeInterval)current {
    if (current < self.nextChirp) return;
    NSString *message;
    if (self.hunger > 68) {
        message = [self randomString:@[@"chirp?", @"peep peep", @"meep!"]];
    } else if (self.affection < 36) {
        message = [self randomString:@[@"prrp?", @"cheep!", @"tap tap?"]];
    } else {
        message = [self randomString:@[@"chirp!", @"peep!", @"brrrp!", @"trill!"]];
    }
    [self chirp:message seconds:5.2];
    self.nextChirp = current + [self randomBetween:26 max:66];
}

- (void)tick {
    NSTimeInterval current = Now();
    NSTimeInterval dt = MIN(0.08, MAX(0.001, current - self.lastTick));
    self.lastTick = current;
    self.phase += dt * 7.0;
    [self refreshBounds:current];
    [self updateNeeds:dt];
    [self updateActivitySensors:current];
    [self maybeChirp:current];
    [self updateMotion:current dt:dt];
    [self updateHabitatMotion:current dt:dt];
    [self updateParticles:dt];
    self.view.needsDisplay = YES;
    self.homeView.needsDisplay = YES;
    self.habitatView.needsDisplay = YES;
}

- (void)addExposureForKind:(NSString *)kind amount:(CGFloat)amount {
    self.warmExposure *= 0.999;
    self.coolExposure *= 0.999;
    self.natureExposure *= 0.999;
    self.darkExposure *= 0.999;
    self.creativeExposure *= 0.999;
    self.codeExposure *= 0.999;

    if ([kind isEqualToString:@"warm"]) self.warmExposure = Clamp(self.warmExposure + amount, 0, 1);
    if ([kind isEqualToString:@"cool"]) self.coolExposure = Clamp(self.coolExposure + amount, 0, 1);
    if ([kind isEqualToString:@"nature"]) self.natureExposure = Clamp(self.natureExposure + amount, 0, 1);
    if ([kind isEqualToString:@"dark"]) self.darkExposure = Clamp(self.darkExposure + amount, 0, 1);
    if ([kind isEqualToString:@"creative"]) self.creativeExposure = Clamp(self.creativeExposure + amount, 0, 1);
    if ([kind isEqualToString:@"code"]) self.codeExposure = Clamp(self.codeExposure + amount, 0, 1);
}

- (void)sampleScreenColorExposure {
    typedef CGImageRef (*CaptureFn)(CGRect, uint32_t, uint32_t, uint32_t);
    static CaptureFn capture = NULL;
    static BOOL lookedUpCapture = NO;
    if (!lookedUpCapture) {
        void *handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY);
        capture = handle ? (CaptureFn)dlsym(handle, "CGWindowListCreateImage") : NULL;
        lookedUpCapture = YES;
    }
    if (!capture) return;

    CGImageRef image = capture(CGRectInfinite, 1, 0, 0);
    if (!image) return;

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    CGImageRelease(image);
    if (!rep) return;

    NSInteger width = rep.pixelsWide;
    NSInteger height = rep.pixelsHigh;
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    NSInteger count = 0;

    for (NSInteger y = height / 5; y < height; y += MAX(1, height / 5)) {
        for (NSInteger x = width / 5; x < width; x += MAX(1, width / 5)) {
            NSColor *color = [[rep colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
            if (!color) continue;
            red += color.redComponent;
            green += color.greenComponent;
            blue += color.blueComponent;
            count++;
        }
    }

    if (count == 0) return;
    red /= count;
    green /= count;
    blue /= count;
    CGFloat brightness = (red + green + blue) / 3.0;

    if (brightness < 0.22) {
        [self addExposureForKind:@"dark" amount:0.010];
    } else if (green > red + 0.08 && green > blue + 0.02) {
        [self addExposureForKind:@"nature" amount:0.009];
    } else if (red > blue + 0.08 && red >= green) {
        [self addExposureForKind:@"warm" amount:0.009];
    } else if (blue > red + 0.04) {
        [self addExposureForKind:@"cool" amount:0.009];
    }
}

- (void)updateActivitySensors:(NSTimeInterval)current {
    if (current < self.nextSensorTick) return;
    self.nextSensorTick = current + 30.0;

    NSString *appName = NSWorkspace.sharedWorkspace.frontmostApplication.localizedName ?: @"";
    self.lastAppName = appName;
    if (appName.length > 0) {
        [self.recentApps removeObject:appName];
        [self.recentApps insertObject:appName atIndex:0];
        while (self.recentApps.count > 6) {
            [self.recentApps removeLastObject];
        }
    }
    NSString *lower = appName.lowercaseString;

    if ([lower containsString:@"cursor"] || [lower containsString:@"xcode"] || [lower containsString:@"terminal"] || [lower containsString:@"code"] || [lower containsString:@"dbeaver"]) {
        [self addExposureForKind:@"code" amount:0.014];
        self.confidence = Clamp(self.confidence + 0.18, 0, 100);
    } else if ([lower containsString:@"figma"] || [lower containsString:@"photoshop"] || [lower containsString:@"illustrator"] || [lower containsString:@"procreate"] || [lower containsString:@"bambu"]) {
        [self addExposureForKind:@"creative" amount:0.014];
        self.curiosity = Clamp(self.curiosity + 0.20, 0, 100);
    } else if ([lower containsString:@"safari"] || [lower containsString:@"dia"] || [lower containsString:@"chrome"]) {
        self.curiosity = Clamp(self.curiosity + 0.08, 0, 100);
    }

    self.energy = Clamp(self.energy - 0.05, 0, 100);
    [self sampleScreenColorExposure];
    [self updateDerivedTraits];
    [self.homeView setNeedsDisplay:YES];
    if (current - self.lastSaved > 45.0) {
        [self saveCreature];
    }
}

- (CGFloat)footOffset {
    BOOL biped = [self.stance isEqualToString:@"two legs"];
    CGFloat bodyTall = PartValue(self.partBodyHeight, -1, 4);
    CGFloat legLen = PartValue(self.partLegLength, 4, 10);
    CGFloat bodyY = biped ? 11 : 17;
    CGFloat bodyH = biped ? 18 + bodyTall : 12 + bodyTall;
    CGFloat pawH = biped ? 5.0 : 5.0;
    CGFloat groundY = bodyY + bodyH + legLen + 5.2 + 0.4;
    CGFloat footBottomFromTop = 42.0 + (groundY + pawH + 2.0) * 4.0;
    return MAX(10.0, self.height - footBottomFromTop);
}

- (BOOL)canFly {
    return ![self.wingType isEqualToString:@"no wings"];
}

- (CGFloat)maxVisibleSupportY {
    return NSMaxY(self.screenFrame) + 12.0;
}

- (Support)homeSupport {
    Support support;
    support.exists = YES;
    support.isHome = YES;
    support.isFloor = NO;
    if (self.menuBarHome) {
        NSRect frame = [self menuBarBurrowFrame];
        support.y = NSMinY(frame) + 4.0;
        support.minX = NSMinX(frame);
        support.maxX = NSMaxX(frame);
        return support;
    }
    NSRect frame = self.homeWindow ? self.homeWindow.frame : NSMakeRect(NSMidX(self.screenFrame) - self.homeWidth / 2, NSMaxY(self.screenFrame) - self.homeHeight, self.homeWidth, self.homeHeight);
    support.y = frame.origin.y + frame.size.height - 164.0;
    support.minX = frame.origin.x + 28.0;
    support.maxX = frame.origin.x + frame.size.width - 28.0;
    return support;
}

- (void)considerSupport:(Support)candidate best:(Support *)best centerX:(CGFloat)centerX footY:(CGFloat)footY margin:(CGFloat)margin {
    if (!candidate.exists) return;
    if (centerX < candidate.minX || centerX > candidate.maxX) return;
    if (candidate.y > footY + margin) return;
    if (candidate.y > [self maxVisibleSupportY]) return;
    if (!best->exists || candidate.y > best->y) {
        *best = candidate;
    }
}

- (Support)supportBelowFootWithMargin:(CGFloat)margin {
    CGFloat centerX = self.x + self.width / 2.0;
    CGFloat footY = self.y + [self footOffset];

    Support best;
    best.exists = YES;
    best.isHome = NO;
    best.isFloor = YES;
    best.y = NSMinY(self.screenFrame);
    best.minX = NSMinX(self.screenFrame);
    best.maxX = NSMaxX(self.screenFrame);

    Support home = [self homeSupport];
    [self considerSupport:home best:&best centerX:centerX footY:footY margin:margin];

    NSArray *windows = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    CGFloat fullScreenHeight = NSScreen.mainScreen.frame.size.height;
    pid_t pid = getpid();
    for (NSDictionary *info in windows) {
        NSNumber *ownerPID = info[(id)kCGWindowOwnerPID];
        NSNumber *layer = info[(id)kCGWindowLayer];
        NSNumber *alpha = info[(id)kCGWindowAlpha];
        if (ownerPID.intValue == pid || layer.intValue != 0 || alpha.doubleValue < 0.05) continue;

        CGRect cgBounds = CGRectZero;
        if (!CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)info[(id)kCGWindowBounds], &cgBounds)) continue;
        if (cgBounds.size.width < 100 || cgBounds.size.height < 60) continue;

        CGFloat minX = cgBounds.origin.x;
        CGFloat maxX = cgBounds.origin.x + cgBounds.size.width;
        CGFloat topY = fullScreenHeight - cgBounds.origin.y;
        if (topY < NSMinY(self.screenFrame) + 18 || topY > NSMaxY(self.screenFrame) + 12) continue;
        if (centerX < minX + 8 || centerX > maxX - 8) continue;

        Support support;
        support.exists = YES;
        support.isHome = NO;
        support.isFloor = NO;
        support.y = topY;
        support.minX = minX + 8;
        support.maxX = maxX - 8;
        [self considerSupport:support best:&best centerX:centerX footY:footY margin:margin];
    }

    return best;
}

- (BOOL)isGroundedOnSupport:(Support)support {
    CGFloat footY = self.y + [self footOffset];
    return support.exists && fabs(footY - support.y) <= 7.0 && self.vy <= 0.2 && !self.flying;
}

- (NSRect)habitatSceneRect {
    NSSize size = self.habitatView ? self.habitatView.bounds.size : NSMakeSize(940, 640);
    CGFloat panelWidth = 338;
    CGFloat margin = 22;
    return NSMakeRect(margin, 28, size.width - panelWidth - margin * 2, size.height - 56);
}

- (void)resetHabitatMotionIfNeeded {
    NSRect scene = [self habitatSceneRect];
    CGFloat spriteW = self.width;
    CGFloat foot = self.height - [self footOffset];
    CGFloat groundY = NSMaxY(scene) - 44;
    if (self.habitatX < NSMinX(scene) || self.habitatX > NSMaxX(scene) - spriteW ||
        self.habitatY < NSMinY(scene) || self.habitatY + foot > groundY) {
        self.habitatX = NSMidX(scene) - spriteW / 2;
        self.habitatY = groundY - foot;
        self.habitatTargetX = self.habitatX;
        self.habitatTargetY = self.habitatY;
        self.habitatVX = 1.2;
        self.habitatVY = 0;
    }
}

- (void)chooseHabitatTarget {
    NSRect scene = [self habitatSceneRect];
    CGFloat spriteW = self.width;
    CGFloat foot = self.height - [self footOffset];
    CGFloat groundY = NSMaxY(scene) - 44;
    CGFloat left = NSMinX(scene) + 20;
    CGFloat right = MAX(left, NSMaxX(scene) - spriteW - 20);
    BOOL grounded = fabs((self.habitatY + foot) - groundY) < 6 && !self.habitatFlying;

    if (grounded && [self canFly] && arc4random_uniform(100) < 18) {
        self.habitatFlying = YES;
        self.habitatFlightUntil = Now() + [self randomBetween:0.8 max:1.8];
        self.habitatTargetX = [self randomBetween:left max:right];
        self.habitatTargetY = groundY - foot - [self randomBetween:70 max:135];
    } else {
        self.habitatTargetX = [self randomBetween:left max:right];
        self.habitatTargetY = groundY - foot;
    }
    self.habitatNextDecision = Now() + [self randomBetween:1.5 max:4.5];
}

- (void)updateHabitatMotion:(NSTimeInterval)current dt:(NSTimeInterval)dt {
    if (!self.habitatView) return;
    if (!self.insideHome) return;
    if (![self canFly]) {
        self.habitatFlying = NO;
    }
    [self resetHabitatMotionIfNeeded];
    if (current >= self.habitatNextDecision) {
        [self chooseHabitatTarget];
    }
    if (self.habitatFlying && current > self.habitatFlightUntil) {
        self.habitatFlying = NO;
    }

    NSRect scene = [self habitatSceneRect];
    CGFloat spriteW = self.width;
    CGFloat foot = self.height - [self footOffset];
    CGFloat groundY = NSMaxY(scene) - 44;
    CGFloat left = NSMinX(scene) + 18;
    CGFloat right = MAX(left, NSMaxX(scene) - spriteW - 18);
    BOOL grounded = self.habitatY + foot >= groundY - 2 && self.habitatVY >= -0.1 && !self.habitatFlying;
    CGFloat dx = self.habitatTargetX - self.habitatX;

    if (grounded) {
        self.habitatY = groundY - foot;
        self.habitatVY = 0;
        self.habitatVX += Clamp(dx * 0.005, -0.20, 0.20);
        self.habitatVX *= 0.88;
    } else if (self.habitatFlying) {
        CGFloat dy = self.habitatTargetY - self.habitatY;
        self.habitatVX += Clamp(dx * 0.006, -0.28, 0.28);
        self.habitatVY += Clamp(dy * 0.006, -0.28, 0.28);
        self.habitatVY += 0.055;
        self.habitatVX *= 0.94;
        self.habitatVY *= 0.96;
    } else {
        self.habitatVX += Clamp(dx * 0.002, -0.08, 0.08);
        self.habitatVY += 0.30;
        self.habitatVX *= 0.98;
    }

    CGFloat speed = hypot(self.habitatVX, self.habitatVY);
    CGFloat maxSpeed = self.habitatFlying ? 4.2 : 2.7;
    if (speed > maxSpeed) {
        self.habitatVX *= maxSpeed / speed;
        self.habitatVY *= maxSpeed / speed;
    }
    if (fabs(self.habitatVX) > 0.12) {
        self.habitatFacing = self.habitatVX > 0 ? 1 : -1;
    }

    self.habitatX += self.habitatVX * dt / 0.033;
    self.habitatY += self.habitatVY * dt / 0.033;
    if (self.habitatX < left || self.habitatX > right) self.habitatVX *= -0.55;
    self.habitatX = Clamp(self.habitatX, left, right);
    self.habitatY = Clamp(self.habitatY, NSMinY(scene) + 60, groundY - foot);
    if (self.habitatY + foot >= groundY - 1 && self.habitatVY > 0) {
        self.habitatY = groundY - foot;
        self.habitatVY = 0;
        self.habitatFlying = NO;
    }
}

- (void)updateMotion:(NSTimeInterval)current dt:(NSTimeInterval)dt {
    if (self.insideHome) return;
    if (self.dragging) return;
    if (![self canFly]) {
        self.flying = NO;
    }
    if (self.sitting && current >= self.sitUntil) {
        self.sitting = NO;
        self.nextDecision = current + [self randomBetween:0.8 max:2.0];
    }
    if (self.sitting) {
        Support support = [self supportBelowFootWithMargin:24.0];
        self.flying = NO;
        self.seekingHome = NO;
        self.y = support.y - [self footOffset];
        self.vx *= 0.35;
        if (fabs(self.vx) < 0.05) self.vx = 0;
        self.vy = 0;
        self.targetX = self.x;
        self.targetY = self.y;
        [self keepOnScreen];
        [self.window setFrameOrigin:NSMakePoint(self.x, self.y)];
        return;
    }

    if (current >= self.nextDecision) {
        [self chooseTarget];
    }

    if (self.seekingHome) {
        Support home = [self homeSupport];
        self.targetX = (home.minX + home.maxX) / 2.0 - self.width / 2.0;
        self.targetY = home.y - [self footOffset];
        self.flying = [self canFly];
        if (self.flying) {
            self.flightUntil = current + 0.4;
        }
        CGFloat centerX = self.x + self.width / 2.0;
        CGFloat footY = self.y + [self footOffset];
        BOOL atEntranceX = centerX >= home.minX - 34.0 && centerX <= home.maxX + 34.0;
        BOOL atEntranceY = fabs(footY - home.y) < 36.0 || (self.flying && footY > home.y - 42.0 && footY < home.y + 60.0);
        if (atEntranceX && atEntranceY) {
            self.seekingHome = NO;
            self.flying = NO;
            self.sitting = NO;
            self.insideHome = YES;
            self.vx = 0;
            self.vy = 0;
            self.y = home.y - [self footOffset];
            NSRect scene = [self habitatSceneRect];
            CGFloat foot = self.height - [self footOffset];
            CGFloat groundY = NSMaxY(scene) - 44;
            self.habitatX = NSMinX(scene) + 72;
            self.habitatY = groundY - foot;
            self.habitatTargetX = self.habitatX + 140;
            self.habitatTargetY = self.habitatY;
            self.habitatVX = 1.0;
            self.habitatVY = 0;
            self.habitatFlying = NO;
            [self bubble:@"prrp" seconds:2.2];
            [self syncDesktopVisibilityForLocation];
            [self saveCreature];
        }
    }

    if (self.flying && current > self.flightUntil) {
        self.flying = NO;
    }

    Support support = [self supportBelowFootWithMargin:self.flying ? 900.0 : 16.0];
    BOOL grounded = [self isGroundedOnSupport:support];

    CGFloat dx = self.targetX - self.x;

    if (grounded) {
        self.y = support.y - [self footOffset];
        self.vy = 0;
        CGFloat minOriginX = support.minX - self.width / 2.0 + 12;
        CGFloat maxOriginX = support.maxX - self.width / 2.0 - 12;
        self.targetX = MAX(minOriginX, MIN(maxOriginX, self.targetX));
        self.vx += MAX(-0.22, MIN(0.22, dx * 0.004));
        self.vx *= 0.86;
    } else if (self.flying) {
        CGFloat dy = self.targetY - self.y;
        self.vx += MAX(-0.32, MIN(0.32, dx * 0.006));
        self.vy += MAX(-0.30, MIN(0.30, dy * 0.006));
        self.vy -= 0.035;
        self.vx *= 0.94;
        self.vy *= 0.96;
    } else {
        self.vx += MAX(-0.10, MIN(0.10, dx * 0.002));
        self.vy -= 0.34;
        self.vx *= 0.98;
        if (self.vy < -9.0) self.vy = -9.0;
        if (self.y + [self footOffset] <= support.y && self.vy <= 0) {
            self.y = support.y - [self footOffset];
            self.vy = 0;
            self.flying = NO;
            [self burst:@"spark" count:4];
        }
    }

    CGFloat speed = hypot(self.vx, self.vy);
    CGFloat maxSpeed = self.flying ? 5.2 : 3.0;
    if (speed > maxSpeed) {
        self.vx *= maxSpeed / speed;
        self.vy *= maxSpeed / speed;
    }
    if (fabs(self.vx) > 0.15) {
        self.facing = self.vx > 0 ? 1 : -1;
    }
    self.x += self.vx * dt / 0.033;
    self.y += self.vy * dt / 0.033;
    [self keepOnScreen];
    [self.window setFrameOrigin:NSMakePoint(self.x, self.y)];
}

- (void)chooseTarget {
    if (self.seekingHome) {
        self.nextDecision = Now() + 1.0;
        return;
    }

    Support support = [self supportBelowFootWithMargin:18.0];
    BOOL grounded = [self isGroundedOnSupport:support];
    NSInteger sitChance = [self.personality isEqualToString:@"cozy"] ? 24 : ([self.personality isEqualToString:@"mischievous"] ? 8 : 14);
    NSInteger flyChance = [self.personality isEqualToString:@"curious"] ? 23 : ([self.personality isEqualToString:@"cozy"] ? 10 : 18);
    if (self.energy < 38) {
        sitChance += 8;
        flyChance = MAX(5, flyChance - 8);
    }

    if (grounded && arc4random_uniform(100) < sitChance) {
        self.sitting = YES;
        self.sitUntil = Now() + [self randomBetween:3.0 max:7.0];
        self.flying = NO;
        self.vx = 0;
        self.vy = 0;
        self.targetX = self.x;
        self.targetY = support.y - [self footOffset];
        self.nextDecision = self.sitUntil;
        return;
    }

    if (grounded && [self canFly] && arc4random_uniform(100) < flyChance) {
        self.flying = YES;
        self.flightUntil = Now() + [self randomBetween:1.2 max:2.8];
        CGFloat left = NSMinX(self.screenFrame) + 12;
        CGFloat right = MAX(left, NSMaxX(self.screenFrame) - self.width - 12);
        self.targetX = [self randomBetween:MAX(left, self.x - 260) max:MIN(right, self.x + 260)];
        self.targetY = MIN([self maxVisibleSupportY] - [self footOffset], self.y + [self randomBetween:75 max:145]);
    } else if (grounded) {
        CGFloat minOriginX = support.minX - self.width / 2.0 + 18;
        CGFloat maxOriginX = support.maxX - self.width / 2.0 - 18;
        self.targetX = [self randomBetween:minOriginX max:maxOriginX];
        self.targetY = support.y - [self footOffset];
    } else {
        self.targetY = NSMinY(self.screenFrame) - [self footOffset];
    }

    self.nextDecision = Now() + [self randomBetween:2.5 max:7.0];
}

- (void)keepOnScreen {
    CGFloat minX = NSMinX(self.screenFrame) + 8;
    CGFloat maxX = MAX(minX, NSMaxX(self.screenFrame) - self.width - 8);
    CGFloat minY = NSMinY(self.screenFrame) - [self footOffset];
    CGFloat maxY = MAX(minY, NSMaxY(self.screenFrame) - self.height + 8);
    if (self.menuBarHome && self.seekingHome) {
        NSScreen *screen = NSScreen.mainScreen;
        NSRect fullFrame = screen ? screen.frame : self.screenFrame;
        minX = NSMinX(fullFrame) - self.width / 2.0 - 16.0;
        maxX = NSMaxX(fullFrame) - self.width / 2.0 + 16.0;
        maxY = NSMaxY(fullFrame) - [self footOffset] + 10.0;
    }
    if (self.x < minX || self.x > maxX) self.vx *= -0.65;
    if (self.y < minY || self.y > maxY) self.vy *= -0.65;
    self.x = MAX(minX, MIN(maxX, self.x));
    self.y = MAX(minY, MIN(maxY, self.y));
}

- (void)updateParticles:(NSTimeInterval)dt {
    NSMutableArray *kept = [NSMutableArray array];
    for (NSMutableDictionary *particle in self.particles) {
        CGFloat x = [particle[@"x"] doubleValue] + [particle[@"vx"] doubleValue] * dt / 0.033;
        CGFloat y = [particle[@"y"] doubleValue] + [particle[@"vy"] doubleValue] * dt / 0.033;
        CGFloat vy = [particle[@"vy"] doubleValue] + 0.025;
        CGFloat life = [particle[@"life"] doubleValue] - dt;
        if (life > 0) {
            particle[@"x"] = @(x);
            particle[@"y"] = @(y);
            particle[@"vy"] = @(vy);
            particle[@"life"] = @(life);
            [kept addObject:particle];
        }
    }
    self.particles = kept;
}

- (void)startHomeDragAt:(NSPoint)point {
    self.draggingHome = YES;
    self.homeWasDragged = NO;
    self.homeDragStartMouse = point;
    self.homeDragStartOrigin = self.homeWindow.frame.origin;
}

- (void)dragHomeTo:(NSPoint)point {
    if (!self.draggingHome) return;
    CGFloat dx = point.x - self.homeDragStartMouse.x;
    CGFloat dy = point.y - self.homeDragStartMouse.y;
    if (fabs(dx) > 5 || fabs(dy) > 5) self.homeWasDragged = YES;
    NSPoint origin = NSMakePoint(self.homeDragStartOrigin.x + dx, self.homeDragStartOrigin.y + dy);
    origin = [self clampedHomeOrigin:origin];
    self.homeX = origin.x;
    self.homeY = origin.y;
    self.hasCustomHomePosition = YES;
    [self.homeWindow setFrameOrigin:origin];
    if (self.seekingHome) {
        Support home = [self homeSupport];
        self.targetX = (home.minX + home.maxX) / 2.0 - self.width / 2.0;
        self.targetY = home.y - [self footOffset];
    }
    [self.homeView setNeedsDisplay:YES];
}

- (void)finishHomeDragAt:(NSPoint)point {
    if (!self.draggingHome) return;
    self.draggingHome = NO;
    BOOL moved = self.homeWasDragged || hypot(point.x - self.homeDragStartMouse.x, point.y - self.homeDragStartMouse.y) > 5;
    if (moved) {
        self.hasCustomHomePosition = YES;
        self.homeX = self.homeWindow.frame.origin.x;
        self.homeY = self.homeWindow.frame.origin.y;
        [self saveCreature];
        [self.homeView setNeedsDisplay:YES];
        return;
    }

    [self openHabitat];
    if (self.insideHome) {
        [self leaveHome];
    } else {
        [self goHome];
    }
}

- (void)startDragAt:(NSPoint)point {
    self.dragStartMouse = point;
    self.dragStartOrigin = self.window.frame.origin;
    self.wasDragged = NO;
    self.dragging = YES;
    self.sitting = NO;
    self.flying = NO;
    self.seekingHome = NO;
}

- (void)dragTo:(NSPoint)point {
    CGFloat dx = point.x - self.dragStartMouse.x;
    CGFloat dy = point.y - self.dragStartMouse.y;
    if (fabs(dx) > 4 || fabs(dy) > 4) self.wasDragged = YES;
    self.x = self.dragStartOrigin.x + dx;
    self.y = self.dragStartOrigin.y + dy;
    self.vx = 0;
    self.vy = 0;
    [self keepOnScreen];
    self.targetX = self.x;
    self.targetY = self.y;
    [self.window setFrameOrigin:NSMakePoint(self.x, self.y)];
}

- (void)finishDragAt:(NSPoint)point {
    self.dragging = NO;
    BOOL moved = self.wasDragged || hypot(point.x - self.dragStartMouse.x, point.y - self.dragStartMouse.y) > 5;
    if (moved) {
        [self bubble:@"whee!" seconds:2.2];
        [self burst:@"spark" count:9];
    } else {
        [self pet];
    }
}

- (void)pet {
    self.affection = MIN(100, self.affection + 28);
    self.hunger = MIN(100, self.hunger + 1.5);
    [self bubble:[self randomString:@[@"prrrp!", @"chirp!", @"brrrp!", @"trill!"]] seconds:2.6];
    self.mouthUntil = Now() + 0.9;
    [self burst:@"heart" count:8];
    [self playSound:@"Purr"];
    [self saveCreature];
    [self.homeView setNeedsDisplay:YES];
    [self.habitatView setNeedsDisplay:YES];
    [self syncHabitatControls];
}

- (void)sit {
    if (self.insideHome) {
        [self leaveHome];
        return;
    }
    Support support = [self supportBelowFootWithMargin:900.0];
    self.sitting = YES;
    self.sitUntil = Now() + 12.0;
    self.flying = NO;
    self.seekingHome = NO;
    self.vx = 0;
    self.vy = 0;
    self.y = support.y - [self footOffset];
    self.targetX = self.x;
    self.targetY = self.y;
    self.nextDecision = self.sitUntil;
    [self keepOnScreen];
    [self.window setFrameOrigin:NSMakePoint(self.x, self.y)];
    [self bubble:@"mrrp" seconds:2.0];
    self.mouthUntil = Now() + 0.45;
    [self playSound:@"Tink"];
    [self.view setNeedsDisplay:YES];
    [self.habitatView setNeedsDisplay:YES];
}

- (void)feed {
    [self feedBerry];
}

- (void)feedFoodNamed:(NSString *)name exposure:(NSString *)exposure curiosity:(CGFloat)curiosity confidence:(CGFloat)confidence energy:(CGFloat)energy {
    self.hunger = MAX(0, self.hunger - 38);
    self.affection = MIN(100, self.affection + 10);
    self.curiosity = Clamp(self.curiosity + curiosity, 0, 100);
    self.confidence = Clamp(self.confidence + confidence, 0, 100);
    self.energy = Clamp(self.energy + energy, 0, 100);
    self.favoriteFood = name;
    [self addExposureForKind:exposure amount:0.028];
    [self updateDerivedTraits];
    [self bubble:[self randomString:@[@"nom!", @"mlem!", @"peep!", @"cronch!"]] seconds:2.8];
    self.mouthUntil = Now() + 1.4;
    [self burst:@"crumb" count:12];
    [self playSound:@"Pop"];
    [self saveCreature];
    [self.homeView setNeedsDisplay:YES];
    [self.habitatView setNeedsDisplay:YES];
    [self syncHabitatControls];
}

- (void)feedBerry {
    [self feedFoodNamed:@"meteor berries" exposure:@"cool" curiosity:1.2 confidence:0.2 energy:8.0];
}

- (void)feedMeat {
    [self feedFoodNamed:@"smoked sun-meat" exposure:@"warm" curiosity:0.2 confidence:1.5 energy:12.0];
}

- (void)feedGreens {
    [self feedFoodNamed:@"crunchy fern sprouts" exposure:@"nature" curiosity:1.0 confidence:0.4 energy:9.0];
}

- (void)feedSweet {
    [self feedFoodNamed:@"moon sugar" exposure:@"creative" curiosity:1.6 confidence:0.1 energy:16.0];
}

- (void)chirp:(NSString *)text seconds:(NSTimeInterval)seconds {
    self.mouthUntil = Now() + 1.2;
    [self burst:@"spark" count:5];
    [self playSound:[self randomString:@[@"Ping", @"Glass", @"Tink"]]];
}

- (void)bubble:(NSString *)text seconds:(NSTimeInterval)seconds {
    self.bubbleText = @"";
    self.bubbleUntil = 0;
}

- (void)goHome {
    if (self.insideHome) {
        [self openHabitat];
        return;
    }
    Support home = [self homeSupport];
    self.seekingHome = YES;
    self.sitting = NO;
    self.flying = [self canFly];
    if (self.flying) {
        self.flightUntil = Now() + 2.0;
    }
    self.targetX = (home.minX + home.maxX) / 2.0 - self.width / 2.0;
    self.targetY = home.y - [self footOffset];
    [self bubble:@"chirp!" seconds:2.0];
    [self burst:@"spark" count:8];
    [self updateMenuBarBurrow];
}

- (void)openHabitat {
    if (!self.habitatWindow) {
        NSRect frame = NSScreen.mainScreen ? NSScreen.mainScreen.visibleFrame : NSMakeRect(0, 0, 1200, 800);
        CGFloat width = MIN(940, MAX(820, frame.size.width - 120));
        CGFloat height = MIN(640, MAX(560, frame.size.height - 120));
        NSRect rect = NSMakeRect(NSMidX(frame) - width / 2, NSMidY(frame) - height / 2, width, height);
        self.habitatWindow = [[NSWindow alloc] initWithContentRect:rect
                                                         styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
                                                           backing:NSBackingStoreBuffered
                                                             defer:NO];
        self.habitatWindow.releasedWhenClosed = NO;
        self.habitatWindow.title = @"Snoot Burrow";
        self.habitatWindow.backgroundColor = Hex(@"#2b2226");
        self.habitatWindow.level = NSFloatingWindowLevel;
        self.habitatView = [[HabitatView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
        self.habitatView.controller = self;
        self.habitatWindow.contentView = self.habitatView;
        [self.habitatView buildCreatorControls];
        [self resetHabitatMotionIfNeeded];
    }
    [self.habitatWindow makeKeyAndOrderFront:nil];
    [self.habitatWindow orderFrontRegardless];
    [self.habitatWindow makeFirstResponder:self.habitatView];
    [self resetHabitatMotionIfNeeded];
    [self syncHabitatControls];
    [self.habitatView setNeedsDisplay:YES];
}

- (void)leaveHome {
    Support home = [self homeSupport];
    self.insideHome = NO;
    self.seekingHome = NO;
    self.sitting = NO;
    self.habitatFlying = NO;
    BOOL canFly = [self canFly];
    self.flying = canFly;
    if (self.flying) {
        self.flightUntil = Now() + 1.2;
    }
    self.x = (home.minX + home.maxX) / 2.0 - self.width / 2.0;
    self.y = home.y + 10;
    self.targetX = self.x + (arc4random_uniform(2) == 0 ? -130 : 130);
    self.targetY = canFly ? self.y + 50 : home.y - [self footOffset];
    self.vx = self.targetX > self.x ? (canFly ? 2.8 : 1.4) : (canFly ? -2.8 : -1.4);
    self.vy = canFly ? 2.5 : 0.2;
    [self.window makeKeyAndOrderFront:nil];
    [self.window orderFrontRegardless];
    [self bubble:@"peep!" seconds:2.0];
    [self syncDesktopVisibilityForLocation];
    [self saveCreature];
}

- (void)toggleHomeDashboard {
    if (!self.homeWindow.isVisible) {
        [self.homeWindow orderFrontRegardless];
    } else {
        [self.homeWindow orderFrontRegardless];
    }
}

- (void)syncHabitatControls {
    [self.habitatView syncControlsFromController];
}

- (void)redrawCreatureSurfaces {
    [self updateDerivedTraits];
    [self.view setNeedsDisplay:YES];
    [self.homeView setNeedsDisplay:YES];
    [self.habitatView setNeedsDisplay:YES];
}

- (CGFloat)creatorValueForKey:(NSString *)key {
    if ([key isEqualToString:@"ageDays"]) return Clamp([self ageDays], 0, 180);
    if ([key isEqualToString:@"hunger"]) return self.hunger;
    if ([key isEqualToString:@"affection"]) return self.affection;
    if ([key isEqualToString:@"energy"]) return self.energy;
    if ([key isEqualToString:@"curiosity"]) return self.curiosity;
    if ([key isEqualToString:@"confidence"]) return self.confidence;
    if ([key isEqualToString:@"exposure.warm"]) return self.warmExposure;
    if ([key isEqualToString:@"exposure.cool"]) return self.coolExposure;
    if ([key isEqualToString:@"exposure.nature"]) return self.natureExposure;
    if ([key isEqualToString:@"exposure.dark"]) return self.darkExposure;
    if ([key isEqualToString:@"exposure.creative"]) return self.creativeExposure;
    if ([key isEqualToString:@"exposure.code"]) return self.codeExposure;
    if ([key isEqualToString:@"parts.bodyLength"]) return self.partBodyLength;
    if ([key isEqualToString:@"parts.bodyHeight"]) return self.partBodyHeight;
    if ([key isEqualToString:@"parts.headSize"]) return self.partHeadSize;
    if ([key isEqualToString:@"parts.snoutLength"]) return self.partSnoutLength;
    if ([key isEqualToString:@"parts.hornLength"]) return self.partHornLength;
    if ([key isEqualToString:@"parts.wingSize"]) return self.partWingSize;
    if ([key isEqualToString:@"parts.tailLength"]) return self.partTailLength;
    if ([key isEqualToString:@"parts.legLength"]) return self.partLegLength;
    if ([key isEqualToString:@"parts.neckLength"]) return self.partNeckLength;
    if ([key isEqualToString:@"parts.clawLength"]) return self.partClawLength;
    if ([key isEqualToString:@"parts.crestSize"]) return self.partCrestSize;
    if ([key isEqualToString:@"parts.eyeSize"]) return self.partEyeSize;
    if ([key isEqualToString:@"parts.bellySize"]) return self.partBellySize;
    if ([key isEqualToString:@"parts.cheekSize"]) return self.partCheekSize;
    if ([key isEqualToString:@"parts.patternDensity"]) return self.patternDensity;
    if ([key isEqualToString:@"parts.patternColorCount"]) return round(Clamp(self.patternColorCount, 1, 3));
    return 0;
}

- (NSString *)creatorStringForKey:(NSString *)key {
    if ([key isEqualToString:@"favoriteFood"]) return self.favoriteFood ?: @"meteor berries";
    if ([key isEqualToString:@"favoriteColor"]) return self.favoriteColor ?: @"sky blue";
    if ([key isEqualToString:@"lastAppName"]) return self.lastAppName.length ? self.lastAppName : @"Desktop";
    if ([key isEqualToString:@"style.hornType"]) return self.hornType ?: @"natural";
    if ([key isEqualToString:@"style.eyeShape"]) return self.eyeShape ?: @"friendly";
    if ([key isEqualToString:@"style.stance"]) return self.stance ?: @"four legs";
    if ([key isEqualToString:@"style.tailTip"]) return self.tailTipType ?: @"fire tip";
    if ([key isEqualToString:@"style.wingType"]) return self.wingType ?: @"normal wings";
    if ([key isEqualToString:@"style.patternType"]) return self.patternType ?: @"dots";
    return @"";
}

- (void)setCreatorValue:(CGFloat)value forKey:(NSString *)key {
    if ([key isEqualToString:@"ageDays"]) self.birthTime = Now() - Clamp(value, 0, 180) * 86400.0;
    if ([key isEqualToString:@"hunger"]) self.hunger = Clamp(value, 0, 100);
    if ([key isEqualToString:@"affection"]) self.affection = Clamp(value, 0, 100);
    if ([key isEqualToString:@"energy"]) self.energy = Clamp(value, 0, 100);
    if ([key isEqualToString:@"curiosity"]) self.curiosity = Clamp(value, 0, 100);
    if ([key isEqualToString:@"confidence"]) self.confidence = Clamp(value, 0, 100);
    if ([key isEqualToString:@"exposure.warm"]) self.warmExposure = Clamp(value, 0, 1);
    if ([key isEqualToString:@"exposure.cool"]) self.coolExposure = Clamp(value, 0, 1);
    if ([key isEqualToString:@"exposure.nature"]) self.natureExposure = Clamp(value, 0, 1);
    if ([key isEqualToString:@"exposure.dark"]) self.darkExposure = Clamp(value, 0, 1);
    if ([key isEqualToString:@"exposure.creative"]) self.creativeExposure = Clamp(value, 0, 1);
    if ([key isEqualToString:@"exposure.code"]) self.codeExposure = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.bodyLength"]) self.partBodyLength = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.bodyHeight"]) self.partBodyHeight = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.headSize"]) self.partHeadSize = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.snoutLength"]) self.partSnoutLength = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.hornLength"]) self.partHornLength = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.wingSize"]) self.partWingSize = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.tailLength"]) self.partTailLength = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.legLength"]) self.partLegLength = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.neckLength"]) self.partNeckLength = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.clawLength"]) self.partClawLength = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.crestSize"]) self.partCrestSize = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.eyeSize"]) self.partEyeSize = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.bellySize"]) self.partBellySize = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.cheekSize"]) self.partCheekSize = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.patternDensity"]) self.patternDensity = Clamp(value, 0, 1);
    if ([key isEqualToString:@"parts.patternColorCount"]) self.patternColorCount = round(Clamp(value, 1, 3));
    [self redrawCreatureSurfaces];
}

- (void)setCreatorString:(NSString *)value forKey:(NSString *)key {
    if ([key isEqualToString:@"name"]) {
        self.creatureName = value.length ? value : @"Pebble";
    } else if ([key isEqualToString:@"favoriteFood"]) {
        self.favoriteFood = value.length ? value : @"meteor berries";
    } else if ([key isEqualToString:@"lastAppName"]) {
        self.lastAppName = value ?: @"";
    } else if ([key isEqualToString:@"favoriteColor"]) {
        self.favoriteColor = value.length ? value : @"sky blue";
        self.warmExposure = MIN(self.warmExposure, 0.25);
        self.coolExposure = MIN(self.coolExposure, 0.25);
        self.natureExposure = MIN(self.natureExposure, 0.25);
        self.darkExposure = MIN(self.darkExposure, 0.25);
        self.creativeExposure = MIN(self.creativeExposure, 0.25);
        if ([value isEqualToString:@"ember coral"]) self.warmExposure = 0.72;
        if ([value isEqualToString:@"sky blue"]) self.coolExposure = 0.72;
        if ([value isEqualToString:@"moss green"]) self.natureExposure = 0.72;
        if ([value isEqualToString:@"moonlit violet"]) self.darkExposure = 0.72;
        if ([value isEqualToString:@"carnival bright"]) self.creativeExposure = 0.72;
    } else if ([key isEqualToString:@"style.hornType"]) {
        self.hornType = value.length ? value : @"natural";
    } else if ([key isEqualToString:@"style.eyeShape"]) {
        self.eyeShape = value.length ? value : @"friendly";
    } else if ([key isEqualToString:@"style.stance"]) {
        self.stance = value.length ? value : @"four legs";
    } else if ([key isEqualToString:@"style.tailTip"]) {
        self.tailTipType = value.length ? value : @"fire tip";
    } else if ([key isEqualToString:@"style.wingType"]) {
        self.wingType = value.length ? value : @"normal wings";
        if (![self canFly]) {
            self.flying = NO;
            self.habitatFlying = NO;
        }
    } else if ([key isEqualToString:@"style.patternType"]) {
        self.patternType = value.length ? value : @"dots";
    }
    [self redrawCreatureSurfaces];
}

- (NSArray<NSString *> *)configurationNames {
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self configurationDirectoryURL]
                                                            includingPropertiesForKeys:nil
                                                                               options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                 error:nil] ?: @[];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSURL *url in files) {
        if ([url.pathExtension.lowercaseString isEqualToString:@"json"]) {
            [names addObject:url.URLByDeletingPathExtension.lastPathComponent];
        }
    }
    [names sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return names;
}

- (void)saveCurrentConfigurationNamed:(NSString *)name {
    NSString *safe = [self safeConfigurationName:name];
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self creatureSnapshot] options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [data writeToURL:[self configurationURLForName:safe] atomically:YES];
        [self bubble:@"saved" seconds:1.4];
    }
}

- (void)loadConfigurationNamed:(NSString *)name {
    NSData *data = [NSData dataWithContentsOfURL:[self configurationURLForName:name]];
    NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if ([json isKindOfClass:NSDictionary.class]) {
        [self applyCreatureDictionary:json];
        [self saveCreature];
        [self redrawCreatureSurfaces];
        [self syncHabitatControls];
        [self bubble:@"loaded" seconds:1.4];
    }
}

- (NSURL *)exportShareSnapshot {
    [self updateDerivedTraits];
    NSURL *dir = [[self supportDirectoryURL] URLByAppendingPathComponent:@"Exports" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *safeName = [[self safeConfigurationName:self.creatureName ?: @"snoot"] lowercaseString];
    NSURL *url = [dir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-snoot.html", safeName]];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    NSString *date = [formatter stringFromDate:[NSDate date]];
    NSArray<NSString *> *apps = self.recentApps.count ? self.recentApps : (self.lastAppName.length ? @[self.lastAppName] : @[@"Desktop"]);
    NSMutableString *appHTML = [NSMutableString string];
    for (NSString *app in apps) {
        [appHTML appendFormat:@"<li>%@</li>", HTMLEscape(app)];
    }
    NSArray<NSString *> *swatches = @[
        [self dragonColorHexForKey:@"body"],
        [self dragonColorHexForKey:@"highlight"],
        [self dragonColorHexForKey:@"belly"],
        [self dragonColorHexForKey:@"wing"],
        [self dragonColorHexForKey:@"crest"],
        [self dragonColorHexForKey:@"outline"]
    ];
    NSMutableString *swatchHTML = [NSMutableString string];
    for (NSString *hex in swatches) {
        [swatchHTML appendFormat:@"<span style=\"background:%@\"></span>", HTMLEscape(hex)];
    }
    NSString *html = [NSString stringWithFormat:
        @"<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        "<title>%@'s Snoot</title><style>"
        ":root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#0b0709;color:#fff;font-family:-apple-system,BlinkMacSystemFont,'Avenir Next',Inter,sans-serif;display:grid;place-items:center;padding:18px}"
        ".card{width:min(430px,100%%);border:3px solid #2a0d12;background:linear-gradient(180deg,#1b1115,#0f0b0e 70%%);box-shadow:0 24px 70px #0009;padding:18px}"
        ".hero{min-height:230px;display:grid;place-items:center;background:radial-gradient(circle at 50%% 42%%,#4a1019 0,#1b1115 42%%,#090709 100%%);border:2px solid #3b2025;margin-bottom:18px;position:relative;overflow:hidden}"
        ".sprite{width:214px;height:166px;image-rendering:pixelated;position:relative}.px{position:absolute;width:8px;height:8px;background:#fff}.body{left:56px;top:72px;width:92px;height:50px;background:%@;box-shadow:0 0 0 8px %@,24px -18px 0 0 %@,-32px 22px 0 -8px %@}.head{left:124px;top:40px;width:58px;height:50px;background:%@;box-shadow:0 0 0 8px %@}.snout{left:174px;top:64px;width:34px;height:22px;background:%@;box-shadow:0 0 0 8px %@}.belly{left:78px;top:83px;width:42px;height:32px;background:%@}.wing{left:38px;top:38px;width:70px;height:48px;background:%@;clip-path:polygon(0 12%%,100%% 0,72%% 38%%,100%% 58%%,50%% 100%%,24%% 58%%);box-shadow:0 0 0 8px %@}.horn{left:136px;top:8px;width:18px;height:36px;background:%@;box-shadow:36px 8px 0 %@}.eye{left:154px;top:56px;width:18px;height:18px;background:%@;box-shadow:0 0 0 5px #050304}.tail{left:8px;top:98px;width:58px;height:20px;background:%@;box-shadow:0 0 0 8px %@}.flame{left:0;top:78px;width:20px;height:28px;background:%@;box-shadow:8px -8px 0 %@}.feet{left:62px;top:122px;width:98px;height:22px;background:%@;box-shadow:0 0 0 8px %@}.title{font-size:34px;font-weight:800;letter-spacing:0;margin:0 0 4px}.sub{color:#ead8dc;margin:0 0 16px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}.stat{border:1px solid #392128;background:#150f12;padding:12px}.k{font-size:12px;color:#c8aeb4}.v{font-size:18px;font-weight:700;margin-top:2px}.apps{margin:14px 0 0;padding:0;list-style:none}.apps li{display:inline-block;margin:0 6px 8px 0;padding:7px 10px;background:#f4eee8;color:#170d10;font-weight:700;font-size:13px}.swatches{display:flex;gap:8px;margin-top:14px}.swatches span{width:30px;height:30px;border:2px solid #000}.stamp{margin-top:16px;color:#b69aa1;font-size:12px}</style></head>"
        "<body><main class=\"card\"><section class=\"hero\"><div class=\"sprite\"><i class=\"wing\"></i><i class=\"tail\"></i><i class=\"flame\"></i><i class=\"body\"></i><i class=\"belly\"></i><i class=\"feet\"></i><i class=\"head\"></i><i class=\"snout\"></i><i class=\"horn\"></i><i class=\"eye\"></i></div></section>"
        "<h1 class=\"title\">%@</h1><p class=\"sub\">A %@ %@ from Snoot for macOS.</p><div class=\"grid\"><div class=\"stat\"><div class=\"k\">Age</div><div class=\"v\">%.0f days</div></div><div class=\"stat\"><div class=\"k\">Favorite food</div><div class=\"v\">%@</div></div><div class=\"stat\"><div class=\"k\">Vibe</div><div class=\"v\">%@</div></div><div class=\"stat\"><div class=\"k\">Stage</div><div class=\"v\">%@</div></div></div>"
        "<div class=\"swatches\">%@</div><ul class=\"apps\">%@</ul><p class=\"stamp\">Snapshot exported %@. Recent apps are shown from this Mac only.</p></main></body></html>",
        HTMLEscape(self.creatureName ?: @"Snoot"),
        [self dragonColorHexForKey:@"body"], [self dragonColorHexForKey:@"outline"], [self dragonColorHexForKey:@"highlight"], [self dragonColorHexForKey:@"body"],
        [self dragonColorHexForKey:@"body"], [self dragonColorHexForKey:@"outline"], [self dragonColorHexForKey:@"highlight"], [self dragonColorHexForKey:@"outline"], [self dragonColorHexForKey:@"belly"],
        [self dragonColorHexForKey:@"wing"], [self dragonColorHexForKey:@"outline"], [self dragonColorHexForKey:@"horn"], [self dragonColorHexForKey:@"horn"], [self dragonColorHexForKey:@"eye"],
        [self dragonColorHexForKey:@"body"], [self dragonColorHexForKey:@"outline"], [self dragonColorHexForKey:@"flameMid"], [self dragonColorHexForKey:@"flameCore"], [self dragonColorHexForKey:@"claw"], [self dragonColorHexForKey:@"outline"],
        HTMLEscape(self.creatureName ?: @"Snoot"),
        HTMLEscape(self.personality ?: @"curious"),
        HTMLEscape(self.lifeStage ?: @"Hatchling"),
        [self ageDays],
        HTMLEscape(self.favoriteFood ?: @"meteor berries"),
        HTMLEscape(self.personality ?: @"curious"),
        HTMLEscape(self.lifeStage ?: @"Hatchling"),
        swatchHTML,
        appHTML,
        HTMLEscape(date)];
    [html writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return url;
}

- (BOOL)exportLandingSpritesToDirectory:(NSURL *)directoryURL {
    [self updateDerivedTraits];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *directoryError = nil;
    if (![fm createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        NSLog(@"Unable to create landing sprite directory: %@", directoryError);
        return NO;
    }

    DragonView *savedView = self.view;
    CGFloat savedFacing = self.facing;
    CGFloat savedPhase = self.phase;
    BOOL savedFlying = self.flying;
    BOOL savedSitting = self.sitting;
    BOOL savedHabitatFlying = self.habitatFlying;

    DragonView *renderView = [[DragonView alloc] initWithFrame:NSMakeRect(0, 0, self.width, self.height)];
    renderView.controller = self;
    self.view = renderView;
    self.facing = 1;
    self.flying = NO;
    self.habitatFlying = NO;
    self.sitting = NO;

    CGFloat phases[] = {0.0, 3.333333, 6.666667, 10.0};
    BOOL ok = YES;
    for (NSInteger i = 0; i < 4; i++) {
        self.phase = phases[i];
        CGFloat bob = round(sin(self.phase * 0.52) * 1.15);
        CGFloat run = sin(self.phase * 0.52);

        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(self.width, self.height)];
        [image lockFocusFlipped:YES];
        [[NSColor clearColor] setFill];
        NSRectFillUsingOperation(NSMakeRect(0, 0, self.width, self.height), NSCompositingOperationCopy);
        [renderView drawDragonWithBob:bob run:run mouthOpen:NO flying:NO moving:YES sitting:NO];
        [image unlockFocus];

        NSData *tiff = image.TIFFRepresentation;
        NSBitmapImageRep *rep = tiff ? [[NSBitmapImageRep alloc] initWithData:tiff] : nil;
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSURL *url = [directoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"snoot-walk-%ld.png", (long)i]];
        if (!png || ![png writeToURL:url atomically:YES]) {
            NSLog(@"Unable to export landing sprite frame %@", url.path);
            ok = NO;
            break;
        }
    }

    self.view = savedView;
    self.facing = savedFacing;
    self.phase = savedPhase;
    self.flying = savedFlying;
    self.habitatFlying = savedHabitatFlying;
    self.sitting = savedSitting;
    return ok;
}

- (NSURL *)exportShareImage {
    [self updateDerivedTraits];
    NSURL *dir = [[self supportDirectoryURL] URLByAppendingPathComponent:@"Exports" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *safeName = [[self safeConfigurationName:self.creatureName ?: @"snoot"] lowercaseString];
    NSURL *url = [dir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-snoot-share.png", safeName]];

    CGFloat width = 1080;
    CGFloat height = 1920;
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
    [image lockFocusFlipped:YES];

    NSGradient *background = [[NSGradient alloc] initWithColorsAndLocations:
        Hex(@"#07131A"), 0.0,
        Hex(@"#10231C"), 0.42,
        Hex(@"#060A12"), 1.0,
        nil];
    [background drawInRect:NSMakeRect(0, 0, width, height) angle:90];

    void (^rect)(CGFloat, CGFloat, CGFloat, CGFloat, NSColor *) = ^(CGFloat x, CGFloat y, CGFloat w, CGFloat h, NSColor *color) {
        [color setFill];
        NSRectFill(NSMakeRect(round(x), round(y), round(w), round(h)));
    };
    void (^oval)(CGFloat, CGFloat, CGFloat, CGFloat, NSColor *) = ^(CGFloat x, CGFloat y, CGFloat w, CGFloat h, NSColor *color) {
        [color setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(round(x), round(y), round(w), round(h))] fill];
    };
    NSColor *moss = Hex(@"#6E936F");
    NSColor *aura = Blend(Hex(@"#1D342A"), moss, 0.36);
    NSGradient *auraGradient = [[NSGradient alloc] initWithColorsAndLocations:
        [aura colorWithAlphaComponent:0.72], 0.0,
        [Hex(@"#1B2B2B") colorWithAlphaComponent:0.46], 0.64,
        [Hex(@"#07131A") colorWithAlphaComponent:0.0], 1.0,
        nil];
    NSBezierPath *auraPath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(118, 360, 844, 700)];
    [auraGradient drawInBezierPath:auraPath relativeCenterPosition:NSMakePoint(0.0, -0.08)];
    [[moss colorWithAlphaComponent:0.22] setStroke];
    auraPath.lineWidth = 2.0;
    [auraPath stroke];

    NSGradient *floorGlow = [[NSGradient alloc] initWithColorsAndLocations:
        [Hex(@"#B7D186") colorWithAlphaComponent:0.28], 0.0,
        [Hex(@"#466847") colorWithAlphaComponent:0.22], 0.45,
        [Hex(@"#07131A") colorWithAlphaComponent:0.0], 1.0,
        nil];
    [floorGlow drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(180, 802, 720, 150)] relativeCenterPosition:NSMakePoint(0, 0.05)];
    oval(252, 832, 576, 62, HexAlpha(@"#071008", 0.34));

    for (NSInteger i = 0; i < 22; i++) {
        CGFloat x = 188 + (i * 67) % 704;
        CGFloat y = 846 + (i % 5) * 15 + (i % 2) * 5;
        CGFloat w = 24 + (i % 4) * 16;
        rect(x, y, w, 3, HexAlpha(@"#87A879", 0.26));
        if (i % 3 == 0) rect(x + w + 6, y + 5, 18, 3, HexAlpha(@"#D9B46B", 0.22));
    }
    for (NSInteger i = 0; i < 20; i++) {
        CGFloat x = 132 + (i * 89) % 820;
        CGFloat y = 278 + (i * 97) % 650;
        CGFloat s = 2 + (i % 3);
        rect(x, y, s, s, HexAlpha(i % 4 == 0 ? @"#F7D88A" : @"#9DC795", 0.52));
    }

    void (^centerText)(NSString *, CGFloat, CGFloat, CGFloat, NSColor *, BOOL) =
        ^(NSString *value, CGFloat y, CGFloat h, CGFloat size, NSColor *color, BOOL bold) {
            NSFont *font = bold ? ([NSFont fontWithName:@"Avenir Next Heavy" size:size] ?: [NSFont boldSystemFontOfSize:size])
                                : ([NSFont fontWithName:@"Avenir Next Demi Bold" size:size] ?: [NSFont systemFontOfSize:size]);
            NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
            style.alignment = NSTextAlignmentCenter;
            style.lineBreakMode = NSLineBreakByTruncatingTail;
            NSDictionary *attrs = @{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: color,
                NSParagraphStyleAttributeName: style
            };
            NSShadow *shadow = [[NSShadow alloc] init];
            shadow.shadowOffset = NSMakeSize(0, 8);
            shadow.shadowBlurRadius = bold ? 14 : 7;
            shadow.shadowColor = bold ? HexAlpha(@"#F7D88A", 0.20) : HexAlpha(@"#9DC795", 0.20);
            [NSGraphicsContext saveGraphicsState];
            shadow.shadowOffset = NSMakeSize(0, 8);
            [shadow set];
            [value drawInRect:NSMakeRect(80, y, width - 160, h) withAttributes:attrs];
            [NSGraphicsContext restoreGraphicsState];
        };

    CGFloat savedFacing = self.facing;
    self.facing = 1;
    if (self.view) {
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform *dragon = [NSAffineTransform transform];
        [dragon translateXBy:206 yBy:474];
        [dragon scaleXBy:1.95 yBy:1.95];
        [dragon concat];
        [self.view drawDragonWithBob:0 run:0 mouthOpen:NO flying:NO moving:NO sitting:NO];
        [NSGraphicsContext restoreGraphicsState];
    }
    self.facing = savedFacing;

    centerText(self.creatureName ?: @"Snoot", 1128, 106, 84, Hex(@"#FFF8E8"), YES);
    centerText(@"snoot.app", 1242, 54, 36, Hex(@"#DDBB8A"), NO);

    [image unlockFocus];
    NSData *tiff = [image TIFFRepresentation];
    NSBitmapImageRep *rep = tiff ? [[NSBitmapImageRep alloc] initWithData:tiff] : nil;
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (![png writeToURL:url atomically:YES]) return nil;
    return url;
}

- (void)shareSnoot {
    NSURL *url = [self exportShareImage];
    if (!url) return;
    NSString *message = [NSString stringWithFormat:@"Meet %@, my Snoot desktop dragon.", self.creatureName ?: @"Snoot"];
    NSSharingServicePicker *picker = [[NSSharingServicePicker alloc] initWithItems:@[message, url]];
    NSView *anchor = self.statusItem.button ?: self.view;
    if (anchor) {
        [picker showRelativeToRect:anchor.bounds ofView:anchor preferredEdge:NSRectEdgeMinY];
    } else {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)copyShareImage {
    NSURL *url = [self exportShareImage];
    NSData *data = url ? [NSData dataWithContentsOfURL:url] : nil;
    if (!data) return;
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setData:data forType:NSPasteboardTypePNG];
    [pasteboard writeObjects:@[url]];
    [self playSound:@"Pop"];
}

- (void)burst:(NSString *)kind count:(NSUInteger)count {
    NSArray<NSColor *> *palette;
    if ([kind isEqualToString:@"heart"]) {
        palette = @[Hex(@"#ff5a7a"), Hex(@"#ff8aa0"), Hex(@"#ffd1dc")];
    } else if ([kind isEqualToString:@"crumb"]) {
        palette = @[Hex(@"#f8d56b"), Hex(@"#f39c4a"), Hex(@"#fff3a6")];
    } else {
        palette = @[Hex(@"#7df6d2"), Hex(@"#f8d56b"), Hex(@"#8d85ff")];
    }
    CGFloat originX = self.facing > 0 ? 148 : 112;
    CGFloat originY = 164;
    for (NSUInteger i = 0; i < count; i++) {
        CGFloat angle = [self randomBetween:-M_PI * 0.95 max:-M_PI * 0.05];
        CGFloat speed = [self randomBetween:1.4 max:3.4];
        NSMutableDictionary *particle = [@{
            @"kind": kind,
            @"x": @(originX + [self randomBetween:-12 max:12]),
            @"y": @(originY + [self randomBetween:-10 max:12]),
            @"vx": @(cos(angle) * speed),
            @"vy": @(sin(angle) * speed),
            @"life": @([self randomBetween:0.7 max:1.25]),
            @"color": palette[arc4random_uniform((uint32_t)palette.count)],
            @"size": @([self randomBetween:4 max:8])
        } mutableCopy];
        [self.particles addObject:particle];
    }
}

- (void)playSound:(NSString *)name {
    if (!self.soundOn) return;
    NSArray<NSString *> *paths = @[
        [NSString stringWithFormat:@"/System/Library/Sounds/%@.aiff", name],
        @"/System/Library/Sounds/Ping.aiff",
        @"/System/Library/Sounds/Pop.aiff"
    ];
    for (NSString *path in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSSound *sound = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
            if (sound) {
                [self.activeSounds addObject:sound];
                [sound play];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.activeSounds removeObject:sound];
                });
            }
            return;
        }
    }
}

- (void)finishCreatorChange:(NSString *)message {
    [self updateDerivedTraits];
    [self saveCreature];
    [self.homeView setNeedsDisplay:YES];
    [self.view setNeedsDisplay:YES];
    [self.habitatView setNeedsDisplay:YES];
    [self syncHabitatControls];
    if (message.length > 0) {
        [self bubble:message seconds:2.2];
    }
}

- (void)setNumericAttributeFromMenu:(NSMenuItem *)item {
    NSDictionary *payload = item.representedObject;
    NSString *key = payload[@"key"];
    CGFloat value = [payload[@"value"] doubleValue];
    if ([key isEqualToString:@"hunger"]) self.hunger = value;
    if ([key isEqualToString:@"affection"]) self.affection = value;
    if ([key isEqualToString:@"energy"]) self.energy = value;
    if ([key isEqualToString:@"curiosity"]) self.curiosity = value;
    if ([key isEqualToString:@"confidence"]) self.confidence = value;
    [self finishCreatorChange:[NSString stringWithFormat:@"%@ %.0f", key, value]];
}

- (void)setExposureFromMenu:(NSMenuItem *)item {
    NSDictionary *payload = item.representedObject;
    NSString *key = payload[@"key"];
    CGFloat value = [payload[@"value"] doubleValue];
    if ([key isEqualToString:@"warm"]) self.warmExposure = value;
    if ([key isEqualToString:@"cool"]) self.coolExposure = value;
    if ([key isEqualToString:@"nature"]) self.natureExposure = value;
    if ([key isEqualToString:@"dark"]) self.darkExposure = value;
    if ([key isEqualToString:@"creative"]) self.creativeExposure = value;
    if ([key isEqualToString:@"code"]) self.codeExposure = value;
    [self finishCreatorChange:[NSString stringWithFormat:@"%@ %.2f", key, value]];
}

- (void)setPartFromMenu:(NSMenuItem *)item {
    NSDictionary *payload = item.representedObject;
    NSString *key = payload[@"key"];
    CGFloat value = [payload[@"value"] doubleValue];
    [self setCreatorValue:value forKey:key];
    [self finishCreatorChange:[NSString stringWithFormat:@"%@ %.2f", [key stringByReplacingOccurrencesOfString:@"parts." withString:@""], value]];
}

- (void)setStyleFromMenu:(NSMenuItem *)item {
    NSDictionary *payload = item.representedObject;
    NSString *key = payload[@"key"];
    NSString *value = payload[@"value"] ?: item.title;
    [self setCreatorString:value forKey:key];
    [self finishCreatorChange:value];
}

- (void)setStageFromMenu:(NSMenuItem *)item {
    NSDictionary *payload = item.representedObject;
    CGFloat days = [payload[@"days"] doubleValue];
    self.birthTime = Now() - days * 86400.0;
    [self finishCreatorChange:payload[@"label"] ?: @"stage"];
}

- (void)setFavoriteFoodFromMenu:(NSMenuItem *)item {
    self.favoriteFood = item.representedObject ?: item.title;
    [self finishCreatorChange:@"nom"];
}

- (void)setFavoriteColorFromMenu:(NSMenuItem *)item {
    NSDictionary *payload = item.representedObject;
    self.favoriteColor = payload[@"label"] ?: item.title;
    NSString *kind = payload[@"exposure"];
    if (kind) {
        self.warmExposure = MIN(self.warmExposure, 0.25);
        self.coolExposure = MIN(self.coolExposure, 0.25);
        self.natureExposure = MIN(self.natureExposure, 0.25);
        self.darkExposure = MIN(self.darkExposure, 0.25);
        self.creativeExposure = MIN(self.creativeExposure, 0.25);
        if ([kind isEqualToString:@"warm"]) self.warmExposure = 0.72;
        if ([kind isEqualToString:@"cool"]) self.coolExposure = 0.72;
        if ([kind isEqualToString:@"nature"]) self.natureExposure = 0.72;
        if ([kind isEqualToString:@"dark"]) self.darkExposure = 0.72;
        if ([kind isEqualToString:@"creative"]) self.creativeExposure = 0.72;
    }
    [self finishCreatorChange:self.favoriteColor];
}

- (void)setLastAppFromMenu:(NSMenuItem *)item {
    self.lastAppName = item.representedObject ?: item.title;
    [self finishCreatorChange:@"watching"];
}

- (void)applyCreatorProfileFromMenu:(NSMenuItem *)item {
    NSString *profile = item.representedObject ?: item.title.lowercaseString;
    if ([profile isEqualToString:@"engineer"]) {
        self.codeExposure = 0.75; self.darkExposure = 0.42; self.coolExposure = 0.45; self.creativeExposure = 0.08; self.warmExposure = 0.05; self.natureExposure = 0.03;
        self.confidence = 78; self.curiosity = 54; self.favoriteFood = @"smoked sun-meat"; self.lastAppName = @"Cursor";
    } else if ([profile isEqualToString:@"designer"]) {
        self.creativeExposure = 0.72; self.warmExposure = 0.34; self.coolExposure = 0.34; self.natureExposure = 0.12; self.darkExposure = 0.10; self.codeExposure = 0.08;
        self.curiosity = 82; self.confidence = 48; self.favoriteFood = @"moon sugar"; self.lastAppName = @"Figma";
    } else if ([profile isEqualToString:@"night-owl"]) {
        self.darkExposure = 0.78; self.coolExposure = 0.38; self.creativeExposure = 0.22; self.codeExposure = 0.32; self.warmExposure = 0.04; self.natureExposure = 0.02;
        self.energy = 46; self.curiosity = 74; self.favoriteFood = @"moon sugar"; self.lastAppName = @"Terminal";
    } else {
        self.coolExposure = 0.32; self.warmExposure = 0.25; self.natureExposure = 0.22; self.creativeExposure = 0.25; self.codeExposure = 0.25; self.darkExposure = 0.16;
        self.energy = 78; self.curiosity = 68; self.confidence = 62; self.favoriteFood = @"meteor berries"; self.lastAppName = @"Safari";
    }
    [self finishCreatorChange:profile];
}

- (void)renameCreatureFromMenu:(NSMenuItem *)item {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename the snoot";
    alert.informativeText = @"This updates the name saved in creature.json.";
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)];
    field.stringValue = self.creatureName ?: @"Pebble";
    alert.accessoryView = field;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn && field.stringValue.length > 0) {
        self.creatureName = field.stringValue;
        [self finishCreatorChange:self.creatureName];
    }
}

- (void)resetCreatureFromMenu:(NSMenuItem *)item {
    self.creatureName = @"Pebble";
    self.birthTime = Now();
    self.hunger = 18;
    self.affection = 76;
    self.energy = 82;
    self.curiosity = 58;
    self.confidence = 34;
    self.warmExposure = 0;
    self.coolExposure = 0.35;
    self.natureExposure = 0;
    self.darkExposure = 0;
    self.creativeExposure = 0;
    self.codeExposure = 0;
    self.partBodyLength = 0.50;
    self.partBodyHeight = 0.50;
    self.partHeadSize = 0.50;
    self.partSnoutLength = 0.35;
    self.partHornLength = 0.35;
    self.partWingSize = 0.50;
    self.partTailLength = 0.50;
    self.partLegLength = 0.50;
    self.partNeckLength = 0.45;
    self.partClawLength = 0.45;
    self.partCrestSize = 0.50;
    self.partEyeSize = 0.50;
    self.partBellySize = 0.50;
    self.partCheekSize = 0.50;
    self.patternDensity = 0.35;
    self.patternColorCount = 2;
    self.hornType = @"natural";
    self.eyeShape = @"friendly";
    self.stance = @"four legs";
    self.tailTipType = @"fire tip";
    self.wingType = @"normal wings";
    self.patternType = @"dots";
    [self resetDragonColors];
    self.favoriteFood = @"meteor berries";
    self.favoriteColor = @"sky blue";
    self.lastAppName = @"";
    [self finishCreatorChange:@"reset"];
}

- (void)saveCreatureFromMenu:(NSMenuItem *)item {
    [self saveCreature];
    [self bubble:@"saved" seconds:1.6];
}

- (void)reloadCreatureFromMenu:(NSMenuItem *)item {
    [self loadCreature];
    [self finishCreatorChange:@"reloaded"];
}

- (void)addValueItemsToMenu:(NSMenu *)menu key:(NSString *)key values:(NSArray<NSNumber *> *)values action:(SEL)action {
    for (NSNumber *value in values) {
        NSMenuItem *item = [menu addItemWithTitle:[NSString stringWithFormat:@"%g", value.doubleValue] action:action keyEquivalent:@""];
        item.target = self;
        item.representedObject = @{@"key": key, @"value": value};
    }
}

- (NSMenu *)makeCreatorMenu {
    NSMenu *creator = [[NSMenu alloc] initWithTitle:@"Customize Snoot"];
    NSMenuItem *rename = [creator addItemWithTitle:@"Rename..." action:@selector(renameCreatureFromMenu:) keyEquivalent:@""];
    rename.target = self;

    NSMenuItem *stageRoot = [creator addItemWithTitle:@"Age / Stage" action:nil keyEquivalent:@""];
    NSMenu *stageMenu = [[NSMenu alloc] initWithTitle:@"Age / Stage"];
    NSArray *stages = @[
        @{@"label": @"Hatchling, day 0", @"days": @0},
        @{@"label": @"Juvenile, day 7", @"days": @7},
        @{@"label": @"Adolescent, day 21", @"days": @21},
        @{@"label": @"Adult, day 45", @"days": @45},
        @{@"label": @"Elder, day 90", @"days": @90}
    ];
    for (NSDictionary *stage in stages) {
        NSMenuItem *item = [stageMenu addItemWithTitle:stage[@"label"] action:@selector(setStageFromMenu:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = stage;
    }
    [creator setSubmenu:stageMenu forItem:stageRoot];

    NSMenuItem *statsRoot = [creator addItemWithTitle:@"Stats" action:nil keyEquivalent:@""];
    NSMenu *statsMenu = [[NSMenu alloc] initWithTitle:@"Stats"];
    NSArray *statKeys = @[@"hunger", @"affection", @"energy", @"curiosity", @"confidence"];
    NSArray *statValues = @[@0, @25, @50, @75, @100];
    for (NSString *key in statKeys) {
        NSMenuItem *root = [statsMenu addItemWithTitle:key action:nil keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:key];
        [self addValueItemsToMenu:submenu key:key values:statValues action:@selector(setNumericAttributeFromMenu:)];
        [statsMenu setSubmenu:submenu forItem:root];
    }
    [creator setSubmenu:statsMenu forItem:statsRoot];

    NSMenuItem *exposureRoot = [creator addItemWithTitle:@"Growth Exposures" action:nil keyEquivalent:@""];
    NSMenu *exposureMenu = [[NSMenu alloc] initWithTitle:@"Growth Exposures"];
    NSArray *exposureKeys = @[@"warm", @"cool", @"nature", @"dark", @"creative", @"code"];
    NSArray *exposureValues = @[@0, @0.15, @0.35, @0.65, @1.0];
    for (NSString *key in exposureKeys) {
        NSMenuItem *root = [exposureMenu addItemWithTitle:key action:nil keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:key];
        [self addValueItemsToMenu:submenu key:key values:exposureValues action:@selector(setExposureFromMenu:)];
        [exposureMenu setSubmenu:submenu forItem:root];
    }
    [creator setSubmenu:exposureMenu forItem:exposureRoot];

    NSMenuItem *partsRoot = [creator addItemWithTitle:@"Body Parts" action:nil keyEquivalent:@""];
    NSMenu *partsMenu = [[NSMenu alloc] initWithTitle:@"Body Parts"];
    NSArray *partItems = @[
        @{@"label": @"body length", @"key": @"parts.bodyLength"},
        @{@"label": @"body height", @"key": @"parts.bodyHeight"},
        @{@"label": @"head size", @"key": @"parts.headSize"},
        @{@"label": @"snout length", @"key": @"parts.snoutLength"},
        @{@"label": @"horn length", @"key": @"parts.hornLength"},
        @{@"label": @"neck length", @"key": @"parts.neckLength"},
        @{@"label": @"wing size", @"key": @"parts.wingSize"},
        @{@"label": @"tail length", @"key": @"parts.tailLength"},
        @{@"label": @"leg length", @"key": @"parts.legLength"},
        @{@"label": @"claw length", @"key": @"parts.clawLength"},
        @{@"label": @"crest size", @"key": @"parts.crestSize"},
        @{@"label": @"eye size", @"key": @"parts.eyeSize"},
        @{@"label": @"belly size", @"key": @"parts.bellySize"},
        @{@"label": @"cheek size", @"key": @"parts.cheekSize"},
        @{@"label": @"pattern density", @"key": @"parts.patternDensity"},
        @{@"label": @"pattern colors", @"key": @"parts.patternColorCount"}
    ];
    NSArray *partValues = @[@0, @0.25, @0.5, @0.75, @1.0];
    NSArray *styleItems = @[
        @{@"label": @"horn type", @"key": @"style.hornType", @"values": @[@"natural", @"very straight", @"corkscrew"]},
        @{@"label": @"eye mood", @"key": @"style.eyeShape", @"values": @[@"friendly", @"neutral", @"menacing"]},
        @{@"label": @"stance", @"key": @"style.stance", @"values": @[@"four legs", @"two legs"]},
        @{@"label": @"tail tip", @"key": @"style.tailTip", @"values": @[@"neutral tip", @"fire tip", @"horned tip"]},
        @{@"label": @"wing type", @"key": @"style.wingType", @"values": @[@"no wings", @"normal wings", @"large wings", @"water wings"]},
        @{@"label": @"pattern", @"key": @"style.patternType", @"values": @[@"dots", @"stripes", @"bands", @"freckles", @"skull mark"]}
    ];
    for (NSDictionary *style in styleItems) {
        NSMenuItem *root = [partsMenu addItemWithTitle:style[@"label"] action:nil keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:style[@"label"]];
        for (NSString *value in style[@"values"]) {
            NSMenuItem *item = [submenu addItemWithTitle:value action:@selector(setStyleFromMenu:) keyEquivalent:@""];
            item.target = self;
            item.representedObject = @{@"key": style[@"key"], @"value": value};
        }
        [partsMenu setSubmenu:submenu forItem:root];
    }
    for (NSDictionary *part in partItems) {
        NSMenuItem *root = [partsMenu addItemWithTitle:part[@"label"] action:nil keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:part[@"label"]];
        NSArray *values = [part[@"key"] isEqualToString:@"parts.patternColorCount"] ? @[@1, @2, @3] : partValues;
        [self addValueItemsToMenu:submenu key:part[@"key"] values:values action:@selector(setPartFromMenu:)];
        [partsMenu setSubmenu:submenu forItem:root];
    }
    [creator setSubmenu:partsMenu forItem:partsRoot];

    NSMenuItem *foodRoot = [creator addItemWithTitle:@"Favorite Food" action:nil keyEquivalent:@""];
    NSMenu *foodMenu = [[NSMenu alloc] initWithTitle:@"Favorite Food"];
    for (NSString *food in @[@"meteor berries", @"smoked sun-meat", @"crunchy fern sprouts", @"moon sugar", @"starfruit cubes"]) {
        NSMenuItem *item = [foodMenu addItemWithTitle:food action:@selector(setFavoriteFoodFromMenu:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = food;
    }
    [creator setSubmenu:foodMenu forItem:foodRoot];

    NSMenuItem *colorRoot = [creator addItemWithTitle:@"Favorite Color / Palette" action:nil keyEquivalent:@""];
    NSMenu *colorMenu = [[NSMenu alloc] initWithTitle:@"Favorite Color / Palette"];
    NSArray *colors = @[
        @{@"label": @"sky blue", @"exposure": @"cool"},
        @{@"label": @"ember coral", @"exposure": @"warm"},
        @{@"label": @"moss green", @"exposure": @"nature"},
        @{@"label": @"moonlit violet", @"exposure": @"dark"},
        @{@"label": @"carnival bright", @"exposure": @"creative"}
    ];
    for (NSDictionary *color in colors) {
        NSMenuItem *item = [colorMenu addItemWithTitle:color[@"label"] action:@selector(setFavoriteColorFromMenu:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = color;
    }
    [creator setSubmenu:colorMenu forItem:colorRoot];

    NSMenuItem *appRoot = [creator addItemWithTitle:@"Last App" action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Last App"];
    for (NSString *app in @[@"Cursor", @"Figma", @"Terminal", @"Safari", @"BambuStudio", @"Notes"]) {
        NSMenuItem *item = [appMenu addItemWithTitle:app action:@selector(setLastAppFromMenu:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = app;
    }
    [creator setSubmenu:appMenu forItem:appRoot];

    NSMenuItem *profileRoot = [creator addItemWithTitle:@"Apply Test Profile" action:nil keyEquivalent:@""];
    NSMenu *profileMenu = [[NSMenu alloc] initWithTitle:@"Apply Test Profile"];
    for (NSString *profile in @[@"engineer", @"designer", @"night-owl", @"balanced"]) {
        NSMenuItem *item = [profileMenu addItemWithTitle:profile action:@selector(applyCreatorProfileFromMenu:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = profile;
    }
    [creator setSubmenu:profileMenu forItem:profileRoot];

    [creator addItem:NSMenuItem.separatorItem];
    NSMenuItem *save = [creator addItemWithTitle:@"Save creature.json" action:@selector(saveCreatureFromMenu:) keyEquivalent:@""];
    save.target = self;
    NSMenuItem *reload = [creator addItemWithTitle:@"Reload creature.json" action:@selector(reloadCreatureFromMenu:) keyEquivalent:@""];
    reload.target = self;
    NSMenuItem *reset = [creator addItemWithTitle:@"Reset Hatchling" action:@selector(resetCreatureFromMenu:) keyEquivalent:@""];
    reset.target = self;
    return creator;
}

- (NSMenu *)makeMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *pet = [menu addItemWithTitle:@"Pet the snoot" action:@selector(pet) keyEquivalent:@""];
    pet.target = self;
    NSMenuItem *sit = [menu addItemWithTitle:@"Sit" action:@selector(sit) keyEquivalent:@"s"];
    sit.target = self;
    NSMenuItem *feedRoot = [menu addItemWithTitle:@"Feed" action:nil keyEquivalent:@""];
    NSMenu *foodMenu = [[NSMenu alloc] initWithTitle:@"Feed"];
    NSMenuItem *berry = [foodMenu addItemWithTitle:@"Meteor berries" action:@selector(feedBerry) keyEquivalent:@""];
    berry.target = self;
    NSMenuItem *meat = [foodMenu addItemWithTitle:@"Smoked sun-meat" action:@selector(feedMeat) keyEquivalent:@""];
    meat.target = self;
    NSMenuItem *greens = [foodMenu addItemWithTitle:@"Crunchy fern sprouts" action:@selector(feedGreens) keyEquivalent:@""];
    greens.target = self;
    NSMenuItem *sweet = [foodMenu addItemWithTitle:@"Moon sugar" action:@selector(feedSweet) keyEquivalent:@""];
    sweet.target = self;
    [menu setSubmenu:foodMenu forItem:feedRoot];
    NSMenuItem *home = [menu addItemWithTitle:self.insideHome ? @"Call out of burrow" : @"Send home" action:(self.insideHome ? @selector(leaveHome) : @selector(goHome)) keyEquivalent:@"h"];
    home.target = self;
    NSMenuItem *barHome = [menu addItemWithTitle:@"Use Menu Bar Burrow" action:@selector(toggleMenuBarBurrow) keyEquivalent:@""];
    barHome.target = self;
    barHome.state = self.menuBarHome ? NSControlStateValueOn : NSControlStateValueOff;
    NSMenuItem *habitat = [menu addItemWithTitle:@"Open burrow" action:@selector(openHabitat) keyEquivalent:@""];
    habitat.target = self;
    NSMenuItem *setup = [menu addItemWithTitle:@"Set up Snoot..." action:@selector(showOnboarding:) keyEquivalent:@""];
    setup.target = self;
    NSMenuItem *share = [menu addItemWithTitle:@"Share Snoot..." action:@selector(shareSnoot) keyEquivalent:@""];
    share.target = self;
    NSMenuItem *copy = [menu addItemWithTitle:@"Copy Share Image" action:@selector(copyShareImage) keyEquivalent:@""];
    copy.target = self;
    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *sound = [menu addItemWithTitle:@"Sound chirps" action:@selector(toggleSound) keyEquivalent:@""];
    sound.target = self;
    sound.state = self.soundOn ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *quit = [menu addItemWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@"q"];
    quit.target = self;
    return menu;
}

- (void)toggleSound { self.soundOn = !self.soundOn; }
- (void)quit { [NSApp terminate:nil]; }

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) DragonController *controller;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.controller = [[DragonController alloc] init];
    [self.controller show];
    [self.controller showOnboardingIfNeeded];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc >= 3 && strcmp(argv[1], "--export-landing-sprites") == 0) {
            NSString *path = [NSString stringWithUTF8String:argv[2]];
            if (!path.isAbsolutePath) {
                path = [NSFileManager.defaultManager.currentDirectoryPath stringByAppendingPathComponent:path];
            }
            DragonController *controller = [[DragonController alloc] init];
            NSURL *directoryURL = [NSURL fileURLWithPath:path isDirectory:YES];
            return [controller exportLandingSpritesToDirectory:directoryURL] ? 0 : 1;
        }

        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
