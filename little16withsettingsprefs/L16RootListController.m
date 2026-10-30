#import "L16RootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <spawn.h>
#import <sys/utsname.h>

#define L16_DOMAIN @"com.michaelmelita1.little16withsettings"
#define L16_NOTIFY "com.michaelmelita1.little16withsettings/ReloadPrefs"

#if __has_include(<rootless.h>)
#import <rootless.h>
#endif
#ifndef ROOT_PATH
#define ROOT_PATH(path) "/var/jb" path
#endif

extern char **environ;

static BOOL L16Spawn(const char *path, char *const argv[]) {
    pid_t pid;
    return posix_spawn(&pid, path, NULL, NULL, argv, environ) == 0;
}

static BOOL L16IsHomeButtonDevice(void) {
    struct utsname u;
    uname(&u);
    NSString *m = [NSString stringWithUTF8String:u.machine];
    NSArray *ids = @[@"iPhone8,1", @"iPhone8,2", @"iPhone8,4",
                     @"iPhone9,1", @"iPhone9,2", @"iPhone9,3", @"iPhone9,4",
                     @"iPhone10,1", @"iPhone10,2", @"iPhone10,4", @"iPhone10,5",
                     @"iPhone12,8", @"iPhone14,6"];
    return [ids containsObject:m];
}

@implementation L16RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];
        if (!L16IsHomeButtonDevice()) {
            // Classic (edge to edge) dock is only available on Home button iPhones
            for (PSSpecifier *spec in [specs copy]) {
                if ([[spec propertyForKey:@"key"] isEqual:@"dockStyle"]) [specs removeObject:spec];
            }
        }
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)respring {
    char *const sbreload[] = { "sbreload", NULL };
    char *const killall[]  = { "killall", "-9", "SpringBoard", NULL };
    if (!L16Spawn(ROOT_PATH("/usr/bin/sbreload"), sbreload)) {
        L16Spawn(ROOT_PATH("/usr/bin/killall"), killall);
    }
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Reset settings"
                         message:@"Restore all Little16 With Settings options to their defaults?"
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:L16_DOMAIN];
        [d removePersistentDomainForName:L16_DOMAIN];
        [d synchronize];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFSTR(L16_NOTIFY), NULL, NULL, YES);
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
