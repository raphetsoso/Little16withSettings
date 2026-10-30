#import "L16RootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <spawn.h>

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

@implementation L16RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
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
