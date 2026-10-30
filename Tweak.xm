#import <UIKit/UIKit.h>
#import <notify.h>
#import <sys/utsname.h>

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------

#define L16_DOMAIN @"com.michaelmelita1.little16withsettings"
#define L16_NOTIFY "com.michaelmelita1.little16withsettings/ReloadPrefs"

static BOOL pEnabled       = YES; // master switch
static BOOL pHomeGesture   = YES; // iPhone X home gesture
static BOOL pControlCenter = YES; // Control Center from the top edge
static BOOL pHideHomeBar   = YES; // hide the home grabber
static BOOL pIpadStatusBar = YES; // iPad style status bar
static BOOL pFloatingDock  = YES; // iPad floating dock
static BOOL pDockRecents   = YES; // recent / suggested apps in the dock
static BOOL pAppLibrary    = NO;  // App Library icon in the dock
static BOOL pQuickActions  = YES; // lockscreen flashlight / camera buttons
static BOOL pNotifFix      = YES; // lockscreen notification position fix
static NSInteger pRecentsCount = 3; // 1...5
static NSInteger pDockStyle    = 0; // 0 = floating (rounded), 1 = classic (edge to edge, square)
static NSInteger pDockIcons    = 4; // 4...6

#define L16_ON(flag) (pEnabled && (flag))

static BOOL L16Bool(NSUserDefaults *d, NSString *key) {
    return [d boolForKey:key];
}

// Classic (edge to edge) dock is only offered on devices with a Home button:
// iPhone 6s / 6s Plus / SE (1st) / 7 / 7 Plus / 8 / 8 Plus / SE (2020) / SE (2022)
static BOOL L16IsHomeButtonDevice(void) {
    static BOOL result = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        struct utsname u;
        uname(&u);
        NSString *m = [NSString stringWithUTF8String:u.machine];
        NSArray *ids = @[@"iPhone8,1", @"iPhone8,2", @"iPhone8,4",
                         @"iPhone9,1", @"iPhone9,2", @"iPhone9,3", @"iPhone9,4",
                         @"iPhone10,1", @"iPhone10,2", @"iPhone10,4", @"iPhone10,5",
                         @"iPhone12,8", @"iPhone14,6"];
        result = [ids containsObject:m];
    });
    return result;
}

static void L16LoadPrefs(void) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:L16_DOMAIN];
    [d registerDefaults:@{
        @"enabled": @YES,
        @"homeGesture": @YES,
        @"controlCenterTop": @YES,
        @"hideHomeBar": @YES,
        @"ipadStatusBar": @YES,
        @"floatingDock": @YES,
        @"dockRecents": @YES,
        @"appLibrary": @NO,
        @"quickActions": @YES,
        @"notifFix": @YES,
        @"recentsCount": @3,
        @"dockStyle": @0,
        @"dockIcons": @4,
    }];
    pEnabled       = L16Bool(d, @"enabled");
    pHomeGesture   = L16Bool(d, @"homeGesture");
    pControlCenter = L16Bool(d, @"controlCenterTop");
    pHideHomeBar   = L16Bool(d, @"hideHomeBar");
    pIpadStatusBar = L16Bool(d, @"ipadStatusBar");
    pFloatingDock  = L16Bool(d, @"floatingDock");
    pDockRecents   = L16Bool(d, @"dockRecents");
    pAppLibrary    = L16Bool(d, @"appLibrary");
    pQuickActions  = L16Bool(d, @"quickActions");
    pNotifFix      = L16Bool(d, @"notifFix");
    pRecentsCount  = MAX(1, MIN(5, [d integerForKey:@"recentsCount"]));
    pDockStyle     = ([d integerForKey:@"dockStyle"] == 1 && L16IsHomeButtonDevice()) ? 1 : 0;
    pDockIcons     = MAX(4, MIN(6, [d integerForKey:@"dockIcons"]));
}

static void L16PrefsChanged(CFNotificationCenterRef center, void *observer,
                            CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    L16LoadPrefs();
}

%ctor {
    L16LoadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    L16PrefsChanged, CFSTR(L16_NOTIFY), NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
}

// ---------------------------------------------------------------------------
// Lockscreen quick actions (flashlight / camera)
// ---------------------------------------------------------------------------

static BOOL ViewContainsClass(UIView *view, Class targetClass, int depth) {
    if (!view || depth > 20) return NO;
    if ([view isKindOfClass:targetClass]) return YES;
    for (UIView *sub in view.subviews) {
        if (ViewContainsClass(sub, targetClass, depth + 1)) return YES;
    }
    return NO;
}

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets orig = %orig;
    if (L16_ON(pQuickActions) && orig.bottom <= 0.0) {
        Class qaCls = NSClassFromString(@"CSQuickActionsButton");
        if (qaCls && ViewContainsClass(self, qaCls, 0)) {
            orig.bottom = 20;
        }
    }
    return orig;
}
%end

@interface CSQuickActionsView : UIView
- (UIEdgeInsets)_buttonOutsets;
@property (nonatomic, retain) UIControl *flashlightButton;
@property (nonatomic, retain) UIControl *cameraButton;
@end

%hook CSQuickActionsView

- (BOOL)wantsQuickActions {
    if (L16_ON(pQuickActions)) return YES;
    return %orig;
}

- (BOOL)_prototypingAllowsButtons {
    if (L16_ON(pQuickActions)) return YES;
    return %orig;
}

- (void)_layoutQuickActionButtons {
    if (!L16_ON(pQuickActions)) {
        %orig;
        return;
    }
    CGRect const screenBounds = [UIScreen mainScreen].bounds;
    CGFloat const y = screenBounds.size.height - 90 - [self _buttonOutsets].top;
    [self flashlightButton].frame = CGRectMake(46, y, 50, 50);
    [self cameraButton].frame = CGRectMake(screenBounds.size.width - 96, y, 50, 50);
}

%end

%hook CSQuickActionsViewController
+ (BOOL)deviceSupportsButtons {
    if (L16_ON(pQuickActions)) return YES;
    return %orig;
}
- (BOOL)hasCamera {
    if (L16_ON(pQuickActions)) return YES;
    return %orig;
}
- (BOOL)hasFlashlight {
    if (L16_ON(pQuickActions)) return YES;
    return %orig;
}
%end

// ---------------------------------------------------------------------------
// Floating dock
// ---------------------------------------------------------------------------

@interface SBIconListGridLayoutConfiguration : NSObject
@property (nonatomic) unsigned long long numberOfPortraitRows;
@property (nonatomic) unsigned long long numberOfPortraitColumns;
@end

@interface SBIconListView : UIView
@property (nonatomic, retain) NSString *iconLocation;
@end

@interface SBBestAppSuggestion : NSObject
- (BOOL)isHandoff;
@end

@interface SBFloatingDockSuggestionsModel : NSObject
@property (nonatomic,readonly) SBBestAppSuggestion * currentAppSuggestion;
@end

// Classic dock look: square, full width (edge to edge) background like the
// iPhone dock on devices with a Home button. The class / view names are private
// and resolved at runtime, so nothing happens if they differ on a given iOS.

@interface UIView (L16Private)
- (void)_setContinuousCornerRadius:(CGFloat)radius;
@end

@interface SBFloatingDockView : UIView
@end

@interface SBFloatingDockPlatterView : UIView
@end

static BOOL L16ClassicDock(void) {
    return L16_ON(pFloatingDock) && pDockStyle == 1;
}

static BOOL L16IsIconView(UIView *v) {
    NSString *n = NSStringFromClass([v class]);
    return [n containsString:@"Icon"] || [n containsString:@"Label"];
}

static void L16Flatten(UIView *v, int depth) {
    if (depth > 4 || L16IsIconView(v)) return;
    v.layer.cornerRadius = 0;
    if ([v respondsToSelector:@selector(_setContinuousCornerRadius:)]) {
        [v _setContinuousCornerRadius:0];
    }
    for (UIView *sub in v.subviews) L16Flatten(sub, depth + 1);
}

// ---------------------------------------------------------------------------
// Classic dock layout engine
//
// Rules:
//  * Nothing extra enabled: the dock icons use EXACTLY the same column pitch as
//    the icons of the home screen (measured at runtime), centred on the screen.
//  * Recent apps: the icons (and the bar height) shrink with the number of
//    items. The bar stays glued to the bottom edge of the screen.
//  * App Library: never shrinks the bar or the icons. The icons are simply
//    spaced a bit closer, and the library icon has the same size as the others.
// ---------------------------------------------------------------------------

#define L16_ICON_SIZE     60.0   // visual size of an icon at scale 1
#define L16_DOCK_PAD      18.0   // top / bottom padding -> 18 + 60 + 18 = 96
#define L16_SIDE_MARGIN    8.0   // minimum margin left / right of the icons
#define L16_MIN_GAP        4.0   // minimum gap between two icons
#define L16_DIVIDER_SLOT   0.4   // extra room (in pitches) around the divider

// Distance between the bottom of the floating dock view and the bottom of the
// screen when the dock is shown. Cached so the hidden state (app switcher)
// does not overwrite it.
static CGFloat sL16DockBottomExtra = 0;

// Column pitch of the home screen icons, measured from the real home screen.
static CGFloat sL16HomePitch = 0;
static BOOL    sL16Applying  = NO;

static CGFloat L16HomePitch(CGFloat screenWidth) {
    if (sL16HomePitch > 0) return sL16HomePitch;
    return round(screenWidth * 0.232); // fallback (87pt on a 375pt wide screen)
}

static UIView *L16EnclosingDock(UIView *v) {
    Class dockCls = NSClassFromString(@"SBFloatingDockView");
    if (!dockCls) return nil;
    UIView *p = v.superview;
    for (int i = 0; p && i < 10; i++, p = p.superview) {
        if ([p isKindOfClass:dockCls]) return p;
    }
    return nil;
}

// Measure the distance between two neighbouring icons of the first row of the
// home screen page (in the list view's own coordinates, so it is not affected
// by any zoom animation on the parents).
static void L16MeasureHomePitch(UIView *list) {
    if (!CGAffineTransformIsIdentity(list.transform)) return;
    NSMutableArray<UIView *> *icons = [NSMutableArray array];
    CGFloat minY = CGFLOAT_MAX;
    for (UIView *s in list.subviews) {
        NSString *n = NSStringFromClass([s class]);
        if (s.hidden || ![n containsString:@"IconView"] || [n containsString:@"ListView"]) continue;
        [icons addObject:s];
        minY = MIN(minY, s.center.y);
    }
    NSMutableArray<UIView *> *row = [NSMutableArray array];
    for (UIView *s in icons) {
        if (fabs(s.center.y - minY) < 4.0) [row addObject:s];
    }
    if (row.count < 3) return;
    [row sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return a.center.x < b.center.x ? NSOrderedAscending : NSOrderedDescending;
    }];
    CGFloat step = row[1].center.x - row[0].center.x;
    if (step < 50.0 || step > 140.0) return;
    for (NSUInteger i = 1; i < row.count; i++) {
        if (fabs((row[i].center.x - row[i - 1].center.x) - step) > 1.0) return; // widget / gap in the row
        if (fabs(row[i].bounds.size.width - row[0].bounds.size.width) > 1.5) return;
    }
    sL16HomePitch = step;
}

static CGFloat L16XIn(UIView *v, UIView *dock) {
    return [v.superview convertPoint:v.center toView:dock].x;
}

// Visible icon views (dock icons, recents, app library) anywhere below `v`.
static void L16CollectItems(UIView *v, NSMutableArray<UIView *> *out, int depth) {
    if (depth > 8) return;
    for (UIView *sub in v.subviews) {
        if (sub.hidden || sub.alpha < 0.01) continue;
        NSString *n = NSStringFromClass([sub class]);
        BOOL listView = [n containsString:@"ListView"];
        BOOL iconView = [n containsString:@"IconView"] && !listView;
        BOOL libView  = [n containsString:@"Library"] && !listView &&
                        sub.bounds.size.width <= 100 && sub.bounds.size.height <= 100;
        if ((iconView || libView) && sub.bounds.size.width > 10) {
            [out addObject:sub];
        } else {
            L16CollectItems(sub, out, depth + 1);
        }
    }
}

static NSString *L16ListLocation(UIView *item, UIView *dock) {
    for (UIView *p = item.superview; p && p != dock; p = p.superview) {
        if ([p respondsToSelector:@selector(iconLocation)]) {
            return [(SBIconListView *)p iconLocation];
        }
    }
    return nil;
}

static UIView *L16FindByName(UIView *v, NSString *part, int depth) {
    if (depth > 4) return nil;
    for (UIView *sub in v.subviews) {
        NSString *n = NSStringFromClass([sub class]);
        if ([n containsString:part]) return sub;
        if ([n containsString:@"IconView"]) continue;
        UIView *r = L16FindByName(sub, part, depth + 1);
        if (r) return r;
    }
    return nil;
}

static void L16ApplyClassicDockInner(UIView *dock) {
    UIView *platter = nil;
    for (UIView *sub in dock.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"Platter"]) { platter = sub; break; }
    }
    if (!platter) {
        for (UIView *sub in dock.subviews) {
            if ([NSStringFromClass([sub class]) containsString:@"Background"]) { platter = sub; break; }
        }
    }
    if (!platter) return;

    dock.clipsToBounds = NO;

    UIScreen *scr = dock.window.screen ?: [UIScreen mainScreen];
    CGRect screen = [scr.coordinateSpace convertRect:scr.bounds toCoordinateSpace:dock];

    // ---- 1. collect and group the items -----------------------------------
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    L16CollectItems(dock, items, 0);

    UIView *divider = L16FindByName(dock, @"Divider", 0);
    BOOL dividerVisible = divider && !divider.hidden && divider.alpha >= 0.01;
    CGFloat dividerX = dividerVisible ? L16XIn(divider, dock) : CGFLOAT_MAX;

    NSMutableArray<UIView *> *left  = [NSMutableArray array]; // user icons
    NSMutableArray<UIView *> *right = [NSMutableArray array]; // recents (+ app library)
    for (UIView *it in items) {
        NSString *loc = L16ListLocation(it, dock);
        BOOL isUser;
        if (loc) {
            isUser = [loc containsString:@"Dock"] && ![loc containsString:@"Suggest"] &&
                     ![loc containsString:@"Recent"] && ![loc containsString:@"Library"];
        } else {
            isUser = L16XIn(it, dock) < dividerX;
        }
        [(isUser ? left : right) addObject:it];
    }
    NSComparator byX = ^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat xa = L16XIn(a, dock), xb = L16XIn(b, dock);
        return xa < xb ? NSOrderedAscending : (xa > xb ? NSOrderedDescending : NSOrderedSame);
    };
    [left sortUsingComparator:byX];
    [right sortUsingComparator:byX];

    // The App Library icon is always the right-most item of the dock.
    if (pAppLibrary && right.count == 0 && left.count > 1) {
        UIView *last = left.lastObject;
        [left removeLastObject];
        [right addObject:last];
    }
    BOOL hasLibrary = pAppLibrary && right.count > 0;
    NSUInteger nLeft    = left.count;
    NSUInteger nRecents = right.count - (hasLibrary ? 1 : 0);
    NSUInteger nAll     = nLeft + right.count;

    // ---- 2. scale / pitch --------------------------------------------------
    CGFloat avail = screen.size.width - 2 * L16_SIDE_MARGIN;
    CGFloat P     = L16HomePitch(screen.size.width);

    // Scale is driven by user icons + recents only (NOT by the app library).
    NSUInteger nBase = MAX((NSUInteger)1, nLeft + nRecents);
    CGFloat baseGap  = (nLeft > 0 && nRecents > 0) ? L16_DIVIDER_SLOT : 0;
    CGFloat naturalW = ((CGFloat)(nBase - 1) + baseGap) * P + L16_ICON_SIZE;
    CGFloat s = MIN(1.0, avail / naturalW);
    CGFloat p = s * P;

    // The app library (if any) only tightens the spacing, icons keep their size.
    CGFloat gap   = (nLeft > 0 && right.count > 0) ? L16_DIVIDER_SLOT : 0;
    CGFloat slots = (nAll > 0 ? (CGFloat)(nAll - 1) : 0) + gap;
    if (slots > 0) {
        if (slots * p + L16_ICON_SIZE * s > avail) {
            p = (avail - L16_ICON_SIZE * s) / slots;
        }
        CGFloat minP = (L16_ICON_SIZE + L16_MIN_GAP) * s;
        if (p < minP) { // really too many items: last resort, shrink the icons
            s = avail / (slots * (L16_ICON_SIZE + L16_MIN_GAP) + L16_ICON_SIZE);
            p = (L16_ICON_SIZE + L16_MIN_GAP) * s;
        }
    }
    s = MAX(0.4, MIN(1.0, s));

    // ---- 3. the bar: full width, stuck to the bottom, height follows the scale
    CGFloat H = 2 * L16_DOCK_PAD + L16_ICON_SIZE * s;

    // When the dock is shown its bottom sits a few points above the screen
    // edge (floating margin). Remember that gap and stick the platter to the
    // real bottom edge. When the dock is hidden (app switcher) the gap is
    // negative, so keep the cached value.
    CGFloat extra = CGRectGetMaxY(screen) - CGRectGetMaxY(dock.bounds);
    if (extra >= 0 && extra < 80) sL16DockBottomExtra = extra;

    CGRect f = platter.frame;
    f.size.width  = screen.size.width;
    f.size.height = H;
    f.origin.x    = screen.origin.x;
    f.origin.y    = CGRectGetMaxY(dock.bounds) + sL16DockBottomExtra - H;
    if (!CGRectEqualToRect(platter.frame, f)) platter.frame = f;
    L16Flatten(platter, 0);

    if (nAll == 0) return;

    // ---- 4. place the icons ------------------------------------------------
    CGFloat totalW = slots * p + L16_ICON_SIZE * s;
    CGFloat startX = screen.origin.x + (screen.size.width - totalW) / 2.0 + L16_ICON_SIZE * s / 2.0;
    CGFloat y      = CGRectGetMidY(f);

    UIView *ref = left.firstObject ?: right.firstObject;
    CGFloat refW = MAX(1.0, ref.bounds.size.width);

    void (^place)(UIView *, CGFloat) = ^(UIView *it, CGFloat slot) {
        CGPoint c = [dock convertPoint:CGPointMake(startX + p * slot, y) toView:it.superview];
        CGFloat k = s * refW / MAX(1.0, it.bounds.size.width); // same size for every item
        it.center = c;
        it.transform = fabs(k - 1.0) < 0.001 ? CGAffineTransformIdentity
                                             : CGAffineTransformMakeScale(k, k);
    };
    for (NSUInteger i = 0; i < left.count; i++)  place(left[i], (CGFloat)i);
    for (NSUInteger j = 0; j < right.count; j++) place(right[j], (CGFloat)nLeft + gap + (CGFloat)j);

    if (dividerVisible && nLeft > 0 && right.count > 0) {
        CGFloat dslot = ((CGFloat)nLeft - 1.0) + (1.0 + gap) / 2.0;
        divider.center = [dock convertPoint:CGPointMake(startX + p * dslot, y) toView:divider.superview];
    }
}

static void L16ApplyClassicDock(UIView *dock) {
    if (sL16Applying || !dock.window) return;
    sL16Applying = YES;
    @try {
        L16ApplyClassicDockInner(dock);
    } @finally {
        sL16Applying = NO;
    }
}

// Called every time an icon list lays out: measures the home screen and keeps
// the dock icons in place when the list re-positions them.
static void L16ListDidLayout(SBIconListView *list) {
    if (!L16ClassicDock()) return;
    NSString *loc = list.iconLocation;
    if (!loc) return;
    if ([loc isEqualToString:@"SBIconLocationRoot"]) {
        L16MeasureHomePitch(list);
    } else if ([loc containsString:@"Dock"]) {
        UIView *dock = L16EnclosingDock(list);
        if (dock) L16ApplyClassicDock(dock);
    }
}

%hook SBFloatingDockPlatterView
- (void)layoutSubviews {
    %orig;
    if (!L16ClassicDock()) return;
    L16Flatten(self, 0);
    UIView *dock = L16EnclosingDock(self);
    if (dock) L16ApplyClassicDock(dock);
}
%end

%hook SBFloatingDockView
- (void)setFrame:(CGRect)f { %orig; if (L16ClassicDock()) [self setNeedsLayout]; }
- (void)setCenter:(CGPoint)c { %orig; if (L16ClassicDock()) [self setNeedsLayout]; }
- (void)setTransform:(CGAffineTransform)t { %orig; if (L16ClassicDock()) [self setNeedsLayout]; }

- (void)layoutSubviews {
    %orig;
    if (L16ClassicDock()) L16ApplyClassicDock(self);
}
%end

%hook SBFloatingDockController
+ (BOOL)isFloatingDockSupported {
    if (L16_ON(pFloatingDock)) return YES;
    return %orig;
}
- (void)_configureFloatingDockBehaviorAssertionForOpenFolder:(id)arg1 atLevel:(NSUInteger)arg2 {
    if (L16_ON(pFloatingDock)) return;
    %orig;
}
%end

%hook SBFloatingDockDefaults
- (void)setRecentsEnabled:(BOOL)arg1 {
    if (L16_ON(pFloatingDock)) {
        %orig(pDockRecents);
    } else {
        %orig;
    }
}
- (BOOL)recentsEnabled {
    if (L16_ON(pFloatingDock)) return pDockRecents;
    return %orig;
}
- (void)setAppLibraryEnabled:(BOOL)arg1 {
    if (L16_ON(pFloatingDock)) {
        %orig(pAppLibrary);
    } else {
        %orig;
    }
}
- (BOOL)appLibraryEnabled {
    if (L16_ON(pFloatingDock)) return pAppLibrary;
    return %orig;
}
%end

%hook SBIconListGridLayoutConfiguration
- (unsigned long long)numberOfPortraitColumns {
    unsigned long long o = %orig;
    if (L16_ON(pFloatingDock) && [self numberOfPortraitRows] == 1 && o == 4) {
        return (unsigned long long)pDockIcons;
    }
    return o;
}
%end

%hook SBIconListView
- (unsigned long long)maximumIconCount {
    if (L16_ON(pFloatingDock) && [self.iconLocation isEqual:@"SBIconLocationDock"]) {
        return (unsigned long long)pDockIcons;
    }
    return %orig;
}
- (void)layoutSubviews {
    %orig;
    L16ListDidLayout(self);
}
- (void)layoutIconsNow {
    %orig;
    L16ListDidLayout(self);
}
%end

%hook SBFloatingDockSuggestionsModel
-(BOOL)recentDisplayItemsController:(id)arg1 shouldAddItem:(id)arg2 {
    if (L16_ON(pFloatingDock) && [self.currentAppSuggestion isHandoff]) return NO;
    return %orig;
}

- (id)initWithMaximumNumberOfSuggestions:(NSUInteger)arg1 iconController:(id)arg2 recentsController:(id)arg3 recentsDataStore:(id)arg4 recentsDefaults:(id)arg5 floatingDockDefaults:(id)arg6 appSuggestionManager:(id)arg7 applicationController:(id)arg8 {
    if (L16_ON(pFloatingDock)) {
        return %orig((NSUInteger)pRecentsCount,arg2,arg3,arg4,arg5,arg6,arg7,arg8);
    }
    return %orig;
}
-(unsigned long long)maxSuggestions {
    if (L16_ON(pFloatingDock)) return (unsigned long long)pRecentsCount;
    return %orig;
}
%end

%hook SBFloatingDockSuggestionsViewController
-(id)initWithNumberOfRecents:(unsigned long long)arg1 iconController:(id)arg2 applicationController:(id)arg3 layoutStateTransitionCoordinator:(id)arg4 suggestionsModel:(id)arg5 iconViewProvider:(id)arg6 {
    if (L16_ON(pFloatingDock)) {
        return %orig((unsigned long long)pRecentsCount,arg2,arg3,arg4,arg5,arg6);
    }
    return %orig;
}
%end

// ---------------------------------------------------------------------------
// Gestures
// ---------------------------------------------------------------------------

%hook SBHomeGestureSettings
- (bool)isHomeGestureEnabled {
    if (L16_ON(pHomeGesture)) return 1;
    return %orig;
}
%end

%hook CCSControlCenterDefaults
- (unsigned long long)_defaultPresentationGesture {
    if (L16_ON(pControlCenter)) return 1;
    return %orig;
}
%end

%hook SBControlCenterController
- (unsigned long long)presentingEdge {
    if (L16_ON(pControlCenter)) return 1;
    return %orig;
}
%end

%hook SBFHomeGrabberSettings
-(BOOL)isEnabled {
    if (L16_ON(pHideHomeBar)) return NO;
    return %orig;
}

-(void)setEnabled:(BOOL)arg1 {
    if (L16_ON(pHideHomeBar)) {
        %orig(NO);
    } else {
        %orig;
    }
}
%end

// ---------------------------------------------------------------------------
// Status bar
// ---------------------------------------------------------------------------

%hook _UIStatusBarVisualProvider_iOS
+ (Class)class {
    if (L16_ON(pIpadStatusBar)) {
        return %c(_UIStatusBarVisualProvider_Pad_ForcedCellular);
    }
    return %orig;
}
%end

// ---------------------------------------------------------------------------
// Lockscreen notification position fixes
// ---------------------------------------------------------------------------

@interface NCNotificationListView : UIView
@end

%hook NCNotificationListView
- (void)setFrame:(CGRect)frame {
    if (L16_ON(pNotifFix) &&
        [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){16, 0, 0}]) {
        frame = CGRectMake(0, -100, frame.size.width, frame.size.height);
    }
    %orig(frame);
}
%end

@interface CSFullscreenNotificationView : UIView
@end

%hook CSFullscreenNotificationView
- (void)setFrame:(CGRect)frame {
    if (L16_ON(pNotifFix)) {
        frame = CGRectMake(0, -50, frame.size.width, frame.size.height);
    }
    %orig(frame);
}
%end
