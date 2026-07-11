//
//  KayokoAdvancedOptionsListController.m
//  Kayoko
//

#import "KayokoAdvancedOptionsListController.h"
#import "KayokoNotificationKeys.h"
#import "KayokoPreferenceKeys.h"
#import "KayokoPurchaseAuthorization.h"
#import "KayokoRespringControllerSupport.h"
#import "KayokoStatusOverlayView.h"
#import "KayokoTagStore.h"

#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <roothide.h>

static NSString *const kKayokoDataDirectoryPath = @"/var/mobile/Library/com.82flex.kayoko";
static NSString *const kKayokoCopyVaultDataDirectoryPath = @"/var/mobile/Documents/CopyVault";

@interface NSTask : NSObject
- (void)setLaunchPath:(NSString *)launchPath;
- (void)setArguments:(NSArray<NSString *> *)arguments;
- (void)setStandardOutput:(id)standardOutput;
- (void)setStandardError:(id)standardError;
- (void)launch;
- (void)waitUntilExit;
- (int)terminationStatus;
@end

@interface KayokoAdvancedOptionsListController ()
- (NSString *)localizedCopyVaultImportFailureDetail:(NSString *)detail;
@end

@implementation KayokoAdvancedOptionsListController {
    KayokoStatusOverlayView *_copyVaultImportOverlayView;
    BOOL _copyVaultImportInProgress;
}

#pragma mark - Specifiers

- (NSArray<PSSpecifier *> *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"AdvancedOptions" target:self];
    }

    return _specifiers;
}

#pragma mark - Preference Writing

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    if ([[specifier propertyForKey:@"key"] isEqualToString:kKayokoPreferenceKeyGestureRecognizerMode]) {
        [self promptToRespring];
    }
}

#pragma mark - Prompts

- (void)resetPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *resetAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Are you sure you want to reset your "
                                                               @"preferences?"
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Reset"
                                                                                        value:nil
                                                                                        table:@"AdvancedOptions"]
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction *action) {
                                                          [self resetPreferences];
                                                        }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [resetAlert addAction:resetAction];
    [resetAlert addAction:cancelAction];

    [self presentViewController:resetAlert animated:YES completion:nil];
}

- (void)clearFavoritesPrompt {
    [self presentClearConfirmationWithMessageKey:
              @"Are you sure you want to clear all favorite items? This action cannot be undone."
                                  actionTitleKey:@"Clear Favorites"
                                notificationName:kKayokoNotificationKeyCoreClearFavorites];
}

- (void)clearHistoryPrompt {
    [self presentClearConfirmationWithMessageKey:
              @"Are you sure you want to clear all history items? This action cannot be undone."
                                  actionTitleKey:@"Clear History"
                                notificationName:kKayokoNotificationKeyCoreClearHistory];
}

- (void)deactivateAuthorizationPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *deactivateAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:
                                             @"Are you sure you want to deactivate Kayoko on this device? "
                                             @"This removes Kayoko’s mirrored Havoc credentials and "
                                             @"local authorization state."
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deactivateAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Deactivate"
                                                                                             value:nil
                                                                                             table:@"AdvancedOptions"]
                                                               style:UIAlertActionStyleDestructive
                                                             handler:^(UIAlertAction *action) {
                                                               (void)action;
                                                               [self deactivateAuthorization];
                                                             }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [deactivateAlert addAction:deactivateAction];
    [deactivateAlert addAction:cancelAction];

    [self presentViewController:deactivateAlert animated:YES completion:nil];
}

- (void)restoreTagsPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *restoreAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Are you sure you want to restore the default tags? "
                                                               @"Existing tags will be replaced. This action cannot be "
                                                               @"undone."
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *restoreAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Restore Tags"
                                                                                          value:nil
                                                                                          table:@"AdvancedOptions"]
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action) {
                                                            (void)action;
                                                            [self restoreTags];
                                                          }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [restoreAlert addAction:restoreAction];
    [restoreAlert addAction:cancelAction];

    [self presentViewController:restoreAlert animated:YES completion:nil];
}

- (void)resetThumbnailCachePrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:
                                             @"Are you sure you want to reset the thumbnail cache? Thumbnails will "
                                             @"be regenerated as needed."
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Reset Thumbnail Cache"
                                                                                        value:nil
                                                                                        table:@"AdvancedOptions"]
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
                                                          (void)action;
                                                          [self resetThumbnailCache];
                                                        }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:resetAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)importCopyVaultPrompt {
    if (_copyVaultImportInProgress) {
        return;
    }

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL directoryExists = [fileManager fileExistsAtPath:kKayokoCopyVaultDataDirectoryPath isDirectory:&isDirectory];
    if (!directoryExists || !isDirectory || ![fileManager isReadableFileAtPath:kKayokoCopyVaultDataDirectoryPath]) {
        UIAlertController *unavailableAlert = [UIAlertController
            alertControllerWithTitle:[bundle localizedStringForKey:@"Data Unavailable"
                                                             value:nil
                                                             table:@"AdvancedOptions"]
                             message:[bundle localizedStringForKey:
                                                 @"The CopyVault data directory could not be found or read."
                                                             value:nil
                                                             table:@"AdvancedOptions"]
                      preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"OK"
                                                                                       value:nil
                                                                                       table:@"AdvancedOptions"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil];
        [unavailableAlert addAction:action];
        [self presentViewController:unavailableAlert animated:YES completion:nil];
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Import from CopyVault"
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                         message:[bundle localizedStringForKey:
                                             @"Kayoko will merge CopyVault history and archived items with your "
                                              "current data. Existing Kayoko items will be kept. SpringBoard must "
                                              "restart when the import finishes."
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *importAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Import"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                           (void)action;
                                                           [self importCopyVault];
                                                         }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:importAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentClearConfirmationWithMessageKey:(NSString *)messageKey
                                actionTitleKey:(NSString *)actionTitleKey
                              notificationName:(NSString *)notificationName {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *clearAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:messageKey value:nil table:@"AdvancedOptions"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *clearAction =
        [UIAlertAction actionWithTitle:[bundle localizedStringForKey:actionTitleKey value:nil table:@"AdvancedOptions"]
                                 style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action) {
                                 CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                                      (CFStringRef)notificationName, nil, nil, YES);
                               }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [clearAlert addAction:clearAction];
    [clearAlert addAction:cancelAction];

    [self presentViewController:clearAlert animated:YES completion:nil];
}

#pragma mark - Data Directory

- (void)checkDataDirectory {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kKayokoNotificationKeyCoreCheckpointHistory, nil, nil, YES);

    NSURL *filzaURL = [self filzaURLForDataDirectoryPath:[self dataDirectoryPath]];
    if (!filzaURL) {
        [self presentDataDirectoryPathAlert];
        return;
    }

    [[UIApplication sharedApplication] openURL:filzaURL
                                       options:@{}
                             completionHandler:^(BOOL success) {
                               if (!success) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                     [self presentDataDirectoryPathAlert];
                                   });
                               }
                             }];
}

- (NSString *)dataDirectoryPath {
    return jbroot(kKayokoDataDirectoryPath);
}

- (NSURL *)filzaURLForDataDirectoryPath:(NSString *)dataDirectoryPath {
    NSString *encodedPath = [dataDirectoryPath
        stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    NSString *pathComponent = encodedPath ?: dataDirectoryPath;
    NSString *URLString = [@"filza://view" stringByAppendingString:pathComponent];
    return [NSURL URLWithString:URLString];
}

- (void)presentDataDirectoryPathAlert {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *dataDirectoryPath = [self dataDirectoryPath];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[bundle localizedStringForKey:@"Unable to Open Filza"
                                                                            value:nil
                                                                            table:@"AdvancedOptions"]
                                            message:dataDirectoryPath
                                     preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Cancel"
                                                                                         value:nil
                                                                                         table:@"AdvancedOptions"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Copy Path"
                                                                                       value:nil
                                                                                       table:@"AdvancedOptions"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
                                                         [UIPasteboard generalPasteboard].string = dataDirectoryPath;
                                                       }];

    [alert addAction:cancelAction];
    [alert addAction:copyAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Authorization

- (void)deactivateAuthorization {
    NSError *error = nil;
    if (![KayokoPurchaseAuthorization clearAuthorizationStateWithError:&error]) {
        [self presentDeactivateAuthorizationError:error];
        return;
    }

    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)presentDeactivateAuthorizationError:(NSError *)error {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *message = [error localizedDescription]
                            ?: [bundle localizedStringForKey:@"Unable to Deactivate"
                                                       value:nil
                                                       table:@"AdvancedOptions"];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[bundle localizedStringForKey:@"Unable to Deactivate"
                                                                            value:nil
                                                                            table:@"AdvancedOptions"]
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"OK"
                                                                                   value:nil
                                                                                   table:@"AdvancedOptions"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Maintenance Actions

- (void)importCopyVault {
    if (_copyVaultImportInProgress) {
        return;
    }
    _copyVaultImportInProgress = YES;
    self.navigationController.view.userInteractionEnabled = NO;

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    KayokoStatusOverlayView *overlayView = [self copyVaultImportOverlayView];
    overlayView.tapHandler = nil;
    [overlayView setLoadingTitle:[bundle localizedStringForKey:@"Importing from CopyVault…"
                                                         value:nil
                                                         table:@"AdvancedOptions"]
                        subtitle:nil];
    [overlayView animateAppearance];

    NSString *updaterPath = [self kayokoUpdaterPath];
    if ([updaterPath length] == 0) {
        _copyVaultImportInProgress = NO;
        [self showCopyVaultImportFailureReason:[bundle localizedStringForKey:@"The import could not be completed."
                                                                       value:nil
                                                                       table:@"AdvancedOptions"]
                              requiresRespring:NO];
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      @autoreleasepool {
          BOOL launched = NO;
          int terminationStatus = -1;
          NSString *output = nil;
          @try {
              NSPipe *outputPipe = [NSPipe pipe];
              NSTask *task = [[NSTask alloc] init];
              [task setLaunchPath:updaterPath];
              [task setArguments:@[ @"import-copyvault" ]];
              [task setStandardOutput:outputPipe];
              [task setStandardError:outputPipe];
              [task launch];
              launched = YES;

              NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
              [task waitUntilExit];
              terminationStatus = [task terminationStatus];
              if ([outputData length] > 0) {
                  output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
                  output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
              }
          } @catch (NSException *exception) {
              output = [exception reason];
          }

          dispatch_async(dispatch_get_main_queue(), ^{
            self->_copyVaultImportInProgress = NO;
            if (launched && terminationStatus == 0) {
                [self showCopyVaultImportSuccess];
                return;
            }

            NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
            NSString *reason = [output length] > 0
                                   ? output
                                   : [mainBundle localizedStringForKey:@"The import could not be completed."
                                                                 value:nil
                                                                 table:@"AdvancedOptions"];
            [self showCopyVaultImportFailureReason:[self localizedCopyVaultImportFailureReason:reason]
                                  requiresRespring:launched];
          });
      }
    });
}

- (KayokoStatusOverlayView *)copyVaultImportOverlayView {
    if (!_copyVaultImportOverlayView) {
        _copyVaultImportOverlayView = [[KayokoStatusOverlayView alloc] initWithFrame:CGRectZero];
        _copyVaultImportOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    if (!_copyVaultImportOverlayView.superview) {
        _copyVaultImportOverlayView.alpha = 0.0;
        [self.view addSubview:_copyVaultImportOverlayView];
        [NSLayoutConstraint activateConstraints:@[
            [_copyVaultImportOverlayView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [_copyVaultImportOverlayView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [_copyVaultImportOverlayView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [_copyVaultImportOverlayView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
        ]];
    }
    return _copyVaultImportOverlayView;
}

- (NSString *)localizedCopyVaultImportFailureReason:(NSString *)reason {
    if ([reason length] == 0) {
        return reason;
    }

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *localizedReason = [bundle localizedStringForKey:reason value:reason table:@"Tweak"];
    if (![localizedReason isEqualToString:reason]) {
        return localizedReason;
    }

    NSArray<NSString *> *formatKeys = @[
        @"CopyVault contains unsupported content: %@", @"CopyVault data is invalid: %@",
        @"Unable to read CopyVault data: %@"
    ];
    for (NSString *formatKey in formatKeys) {
        NSRange placeholderRange = [formatKey rangeOfString:@"%@"];
        NSString *prefix = [formatKey substringToIndex:placeholderRange.location];
        if (![reason hasPrefix:prefix]) {
            continue;
        }

        NSString *detail = [reason substringFromIndex:[prefix length]];
        NSString *localizedFormat = [bundle localizedStringForKey:formatKey value:formatKey table:@"Tweak"];
        return [NSString stringWithFormat:localizedFormat, [self localizedCopyVaultImportFailureDetail:detail]];
    }
    return reason;
}

- (NSString *)localizedCopyVaultImportFailureDetail:(NSString *)detail {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *localizedDetail = [bundle localizedStringForKey:detail value:detail table:@"Tweak"];
    if (![localizedDetail isEqualToString:detail]) {
        return localizedDetail;
    }

    NSArray<NSString *> *formatKeys = @[
        @"%@ contains an invalid item", @"%@ contains an invalid payload", @"%@ has no contents", @"%@ is not an array",
        @"conflicting image %@", @"image %@ already contains different data", @"invalid %@ timestamp",
        @"invalid item path %@", @"invalid timestamp %@"
    ];
    for (NSString *formatKey in formatKeys) {
        NSRange placeholderRange = [formatKey rangeOfString:@"%@"];
        NSString *prefix = [formatKey substringToIndex:placeholderRange.location];
        NSString *suffix = [formatKey substringFromIndex:NSMaxRange(placeholderRange)];
        if (![detail hasPrefix:prefix] || ![detail hasSuffix:suffix] ||
            [detail length] < [prefix length] + [suffix length]) {
            continue;
        }

        NSRange valueRange = NSMakeRange([prefix length], [detail length] - [prefix length] - [suffix length]);
        NSString *value = [detail substringWithRange:valueRange];
        NSString *localizedFormat = [bundle localizedStringForKey:formatKey value:formatKey table:@"Tweak"];
        return [NSString stringWithFormat:localizedFormat, value];
    }
    return detail;
}

- (void)showCopyVaultImportSuccess {
    self.navigationController.view.userInteractionEnabled = YES;
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    KayokoStatusOverlayView *overlayView = [self copyVaultImportOverlayView];
    [overlayView
        setSuccessTitle:[bundle localizedStringForKey:@"Import Complete" value:nil table:@"AdvancedOptions"]
               subtitle:[bundle localizedStringForKey:@"Tap the screen to restart SpringBoard and finish importing."
                                                value:nil
                                                table:@"AdvancedOptions"]
          actionEnabled:YES];
    __weak typeof(self) weakSelf = self;
    overlayView.tapHandler = ^{
      [weakSelf dismissCopyVaultImportOverlayWithCompletion:^{
        [weakSelf respring];
      }];
    };
}

- (void)showCopyVaultImportFailureReason:(NSString *)reason requiresRespring:(BOOL)requiresRespring {
    self.navigationController.view.userInteractionEnabled = YES;
    if (requiresRespring) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kKayokoNotificationKeyCopyVaultImportRequiresRestart
                                                            object:nil];
    }
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *actionMessage =
        [bundle localizedStringForKey:(requiresRespring ? @"Tap the screen to restart SpringBoard and restore Kayoko."
                                                        : @"Tap the screen to close.")
                                value:nil
                                table:@"AdvancedOptions"];
    NSString *subtitle = [NSString stringWithFormat:@"%@\n\n%@", reason, actionMessage];
    KayokoStatusOverlayView *overlayView = [self copyVaultImportOverlayView];
    [overlayView setFailureTitle:[bundle localizedStringForKey:@"Unable to Import" value:nil table:@"AdvancedOptions"]
                        subtitle:subtitle
                   actionEnabled:YES];
    __weak typeof(self) weakSelf = self;
    overlayView.tapHandler = ^{
      if (requiresRespring) {
          [weakSelf dismissCopyVaultImportOverlayWithCompletion:^{
            [weakSelf respring];
          }];
      } else {
          [weakSelf dismissCopyVaultImportOverlay];
      }
    };
}

- (void)dismissCopyVaultImportOverlay {
    [self dismissCopyVaultImportOverlayWithCompletion:nil];
}

- (void)dismissCopyVaultImportOverlayWithCompletion:(void (^)(void))completion {
    KayokoStatusOverlayView *overlayView = _copyVaultImportOverlayView;
    if (!overlayView) {
        if (completion) {
            completion();
        }
        return;
    }
    [overlayView animateDisappearanceWithCompletion:^{
      [overlayView removeFromSuperview];
      if (self->_copyVaultImportOverlayView == overlayView) {
          self->_copyVaultImportOverlayView = nil;
      }
      if (completion) {
          completion();
      }
    }];
}

- (void)resetThumbnailCache {
    NSString *updaterPath = [self kayokoUpdaterPath];
    if ([updaterPath length] == 0) {
        NSLog(@"Kayoko: Unable to reset thumbnail cache because kayoko_updater is unavailable");
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      @try {
          NSTask *task = [[NSTask alloc] init];
          [task setLaunchPath:updaterPath];
          [task setArguments:@[ @"reset-thumbnail-cache" ]];
          [task setStandardOutput:[NSPipe pipe]];
          [task setStandardError:[NSPipe pipe]];
          [task launch];
          [task waitUntilExit];
      } @catch (NSException *exception) {
          NSLog(@"Kayoko: Unable to launch thumbnail cache reset: %@", exception);
      }
    });
}

- (NSString *)kayokoUpdaterPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *candidatePaths = @[
        jbroot(@"/usr/local/libexec/kayoko_updater"), @"/var/jb/usr/local/libexec/kayoko_updater",
        @"/usr/local/libexec/kayoko_updater"
    ];
    for (NSString *path in candidatePaths) {
        if ([fileManager isExecutableFileAtPath:path]) {
            return path;
        }
    }
    return nil;
}

- (void)resetPreferences {
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kKayokoPreferencesIdentifier];
    for (NSString *key in [userDefaults dictionaryRepresentation]) {
        [userDefaults removeObjectForKey:key];
    }

    [self reloadSpecifiers];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kKayokoNotificationKeyPreferencesReload, nil, nil, YES);
}

- (void)restoreTags {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    KayokoTagStore *tagStore = [[KayokoTagStore alloc] initWithTagsPath:[KayokoTagStore defaultTagsPath]
                                                     localizationBundle:bundle];

    NSError *error = nil;
    if (![tagStore restoreDefaultTagsWithError:&error]) {
        [self presentRestoreTagsError:error];
    }
}

- (void)presentRestoreTagsError:(NSError *)error {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *message = [error localizedDescription]
                            ?: [bundle localizedStringForKey:@"Unable to Restore Tags"
                                                       value:nil
                                                       table:@"AdvancedOptions"];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[bundle localizedStringForKey:@"Unable to Restore Tags"
                                                                            value:nil
                                                                            table:@"AdvancedOptions"]
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"OK"
                                                                                   value:nil
                                                                                   table:@"AdvancedOptions"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSString *key = [specifier propertyForKey:@"cell"];
    if ([key isEqualToString:@"PSButtonCell"]) {
        UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
        NSNumber *isDestructiveValue = [specifier propertyForKey:@"isDestructive"];
        BOOL isDestructive = [isDestructiveValue boolValue];
        cell.textLabel.textColor = isDestructive ? [UIColor systemRedColor] : [UIColor systemBlueColor];
        cell.textLabel.highlightedTextColor = isDestructive ? [UIColor systemRedColor] : [UIColor systemBlueColor];
        return cell;
    }

    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

@end
