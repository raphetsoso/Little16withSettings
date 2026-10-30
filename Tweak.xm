#import <UIKit/UIKit.h>
#import <notify.h>

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
    pDockStyle     = ([d integerForKey:@"dockStyle"] == 1) ? 1 : 0;
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

%hook SBFloatingDockView
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
    CGRect screen = [self convertRect:self.window.bounds fromView:self.window];
    CGRect f = platter.frame;
    f.origin.x = screen.origin.x;
    f.size.width = screen.size.width;
    f.size.height = MAX(f.size.height, CGRectGetMaxY(screen) - f.origin.y); // down to the bottom edge
    platter.frame = f;
    L16Flatten(platter, 0);
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
