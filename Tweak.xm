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

%hook SBFloatingDockPlatterView
- (void)layoutSubviews {
    %orig;
    if (L16ClassicDock()) L16Flatten(self, 0);
}
%end

// Height of the real iPhone (Home button) dock background.
#define L16_CLASSIC_DOCK_HEIGHT 96.0

// Distance between the bottom of the floating dock view and the bottom of the
// screen when the dock is shown. Cached so the hidden state (app switcher)
// does not overwrite it.
static CGFloat sL16DockBottomExtra = 0;

// Union (in `root` coordinates) of all visible icon views below `v`.
static CGRect L16IconsUnion(UIView *v, UIView *root, int depth) {
    CGRect u = CGRectNull;
    if (!v || depth > 8 || v.hidden || v.alpha < 0.01) return u;
    NSString *n = NSStringFromClass([v class]);
    if ([n containsString:@"IconView"] && ![n containsString:@"ListView"]) {
        return [v convertRect:v.bounds toView:root];
    }
    for (UIView *sub in v.subviews) {
        CGRect r = L16IconsUnion(sub, root, depth + 1);
        if (!CGRectIsNull(r)) u = CGRectIsNull(u) ? r : CGRectUnion(u, r);
    }
    return u;
}

%hook SBFloatingDockView
- (void)setFrame:(CGRect)f { %orig; if (L16ClassicDock()) [self setNeedsLayout]; }
- (void)setCenter:(CGPoint)c { %orig; if (L16ClassicDock()) [self setNeedsLayout]; }
- (void)setTransform:(CGAffineTransform)t { %orig; if (L16ClassicDock()) [self setNeedsLayout]; }

- (void)layoutSubviews {
    %orig;
    if (!L16ClassicDock() || !self.window) return;

    UIView *platter = nil;
    for (UIView *sub in self.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"Platter"]) { platter = sub; break; }
    }
    if (!platter) {
        for (UIView *sub in self.subviews) {
            if ([NSStringFromClass([sub class]) containsString:@"Background"]) { platter = sub; break; }
        }
    }
    if (!platter) return;

    self.clipsToBounds = NO;

    UIScreen *scr = self.window.screen ?: [UIScreen mainScreen];
    CGRect screen = [scr.coordinateSpace convertRect:scr.bounds toCoordinateSpace:self];

    // When the dock is shown its bottom sits a few points above the screen
    // edge (floating margin). Remember that gap and stick the platter to the
    // real bottom edge. When the dock is hidden (app switcher) the gap is
    // negative, so keep the cached value: the platter keeps its fixed height
    // and slides down with the dock view instead of sticking out.
    CGFloat extra = CGRectGetMaxY(screen) - CGRectGetMaxY(self.bounds);
    if (extra >= 0 && extra < 80) sL16DockBottomExtra = extra;

    CGRect f = platter.frame;
    f.size.width  = screen.size.width;
    f.size.height = L16_CLASSIC_DOCK_HEIGHT;
    f.origin.x    = screen.origin.x;
    f.origin.y    = CGRectGetMaxY(self.bounds) + sL16DockBottomExtra - L16_CLASSIC_DOCK_HEIGHT;
    platter.frame = f;
    L16Flatten(platter, 0);

    // Center the icons in the dock (horizontally on the screen, vertically in the platter).
    CGRect u = L16IconsUnion(self, self, 0);
    if (CGRectIsNull(u)) return;
    CGFloat dx = CGRectGetMidX(screen) - CGRectGetMidX(u);
    CGFloat dy = CGRectGetMidY(f) - CGRectGetMidY(u);
    if (fabs(dx) < 0.5 && fabs(dy) < 0.5) return;

    NSMutableArray<UIView *> *targets = [NSMutableArray array];
    for (UIView *sub in self.subviews) {
        if (sub != platter && !CGRectIsNull(L16IconsUnion(sub, sub, 0))) [targets addObject:sub];
    }
    if (targets.count == 0) {
        for (UIView *sub in platter.subviews) {
            if (!CGRectIsNull(L16IconsUnion(sub, sub, 0))) [targets addObject:sub];
        }
    }
    for (UIView *sub in targets) {
        sub.center = CGPointMake(sub.center.x + dx, sub.center.y + dy);
    }
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
