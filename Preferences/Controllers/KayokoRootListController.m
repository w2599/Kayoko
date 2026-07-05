//
//  KayokoRootListController.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoRootListController.h"
#import "KayokoPreferencesFileAccess.h"

#import "PasteboardItem.h"
#import "PasteboardManager.h"

#import <UIKit/UIKit.h>

#import <roothide.h>

#import "../NotificationKeys.h"
#import "../PreferenceKeys.h"

@implementation KayokoRootListController

/**
 * Loads the root specifiers.
 *
 * @return The specifiers.
 */
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

/**
 * Handles preference changes.
 *
 * @param value The new value for the changed option.
 * @param specifier The specifier that was interacted with.
 */
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    KayokoWritePreferenceValue(key, value);

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyPreferencesReload, nil, nil, YES);

    // Immediately shrink the history when the maximum amount is lowered, instead of waiting
    // for the next clipboard change to lazily trigger the truncation.
    if ([key isEqualToString:kPreferenceKeyMaximumHistoryAmount]) {
        [[PasteboardManager sharedInstance] truncateHistoryToMaximumAmount:[value unsignedIntegerValue]];
    }

    // Prompt to respring for options that require one to apply changes.
    if ([key isEqualToString:kPreferenceKeyEnabled] || [key isEqualToString:kPreferenceKeyActivationMethod] ||
        [key isEqualToString:kPreferenceKeyAutomaticallyPaste]) {
        [self promptToRespring];
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return KayokoPreferenceValueForSpecifier(specifier);
}

/**
 * Hides the keyboard when the "Return" key is pressed on focused text fields.
 *
 * @param notification The event notification.
 */
- (void)_returnKeyPressed:(NSConcreteNotification *)notification {
    [[self view] endEditing:YES];
    [super _returnKeyPressed:notification];
}

/**
 * Prompts the user to respring to apply changes.
 */
- (void)promptToRespring {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *resetAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:
                                             @"This option requires a respring to apply. Do you want to respring now?"
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Yes"
                                                                                      value:nil
                                                                                      table:@"Root"]
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
                                                        [self respring];
                                                      }];

    UIAlertAction *noAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"No"
                                                                                     value:nil
                                                                                     table:@"Root"]
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil];

    [resetAlert addAction:yesAction];
    [resetAlert addAction:noAction];

    [self presentViewController:resetAlert animated:YES completion:nil];
}

/**
 * Resprings the device.
 */
- (void)respring {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:jbroot(@"/usr/bin/killall")];
    [task setArguments:@[ @"backboardd" ]];
    [task launch];
}

/**
 * Prompts the user to reset their preferences.
 */
- (void)resetPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *resetAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Are you sure you want to reset your preferences?"
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Yes"
                                                                                      value:nil
                                                                                      table:@"Root"]
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
                                                        [self resetPreferences];
                                                      }];

    UIAlertAction *noAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"No"
                                                                                     value:nil
                                                                                     table:@"Root"]
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil];

    [resetAlert addAction:yesAction];
    [resetAlert addAction:noAction];

    [self presentViewController:resetAlert animated:YES completion:nil];
}

/**
 * Resets the preferences.
 */
- (void)resetPreferences {
    [[NSFileManager defaultManager] removeItemAtPath:KayokoPreferencesPath() error:nil];

    [self reloadSpecifiers];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyPreferencesReload, nil, nil, YES);
}

/**
 * Prompts the user to confirm adding random history items for testing purposes.
 */
- (void)addRandomHistoryItemsPrompt {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    UIAlertController *confirmAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:
                                             @"Do you want to add 2000 random items to your clipboard history? This is meant for testing."
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"Yes"
                                                                                      value:nil
                                                                                      table:@"Root"]
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
                                                        [self addRandomHistoryItems];
                                                      }];

    UIAlertAction *noAction = [UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"No"
                                                                                     value:nil
                                                                                     table:@"Root"]
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil];

    [confirmAlert addAction:yesAction];
    [confirmAlert addAction:noAction];

    [self presentViewController:confirmAlert animated:YES completion:nil];
}

/**
 * Generates and inserts 2000 pasteboard items with randomized content into the history, for testing purposes.
 */
- (void)addRandomHistoryItems {
    NSDictionary *preferences = KayokoPreferencesDictionary();
    id storedAmount = preferences[kPreferenceKeyMaximumHistoryAmount];
    NSUInteger maximumHistoryAmount =
        storedAmount ? [storedAmount unsignedIntegerValue] : kPreferenceKeyMaximumHistoryAmountDefaultValue;

    PasteboardManager *manager = [PasteboardManager sharedInstance];
    [manager setMaximumHistoryAmount:MAX(maximumHistoryAmount, 2000)];

    NSArray<NSString *> *sampleWords = @[
        @"Lorem", @"ipsum", @"dolor", @"sit", @"amet", @"consectetur", @"adipiscing", @"elit", @"kayoko",
        @"clipboard", @"paste", @"random", @"sample", @"item", @"snippet", @"test", @"history", @"note"
    ];

    for (NSUInteger i = 0; i < 2000; i++) {
        NSUInteger wordCount = 3 + arc4random_uniform(6);
        NSMutableArray<NSString *> *words = [NSMutableArray arrayWithCapacity:wordCount];
        for (NSUInteger w = 0; w < wordCount; w++) {
            [words addObject:sampleWords[arc4random_uniform((uint32_t)[sampleWords count])]];
        }

        NSString *content = [NSString stringWithFormat:@"%@ #%lu-%08x", [words componentsJoinedByString:@" "],
                                                        (unsigned long)i, arc4random()];

        PasteboardItem *item = [[PasteboardItem alloc] initWithBundleIdentifier:@"com.apple.springboard"
                                                                     andContent:content
                                                                 withImageNamed:nil
                                                                         remark:@""];
        [manager addPasteboardItem:item toHistoryWithKey:kHistoryKeyHistory];
    }

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIAlertController *doneAlert = [UIAlertController
        alertControllerWithTitle:[bundle localizedStringForKey:@"Kayoko" value:nil table:@"Root"]
                         message:[bundle localizedStringForKey:@"Added 2000 random items to your clipboard history."
                                                         value:nil
                                                         table:@"Root"]
                  preferredStyle:UIAlertControllerStyleAlert];
    [doneAlert addAction:[UIAlertAction actionWithTitle:[bundle localizedStringForKey:@"OK" value:nil table:@"Root"]
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
    [self presentViewController:doneAlert animated:YES completion:nil];
}

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
    if ([key isEqualToString:@"PSLinkListCell"]) {
        NSString *detail = [specifier propertyForKey:@"detail"];
        if ([detail isEqualToString:@"KayokoListItemsController"]) {
            UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            
            // Get the current activation methods (0 means "None")
            NSDictionary *preferences = KayokoPreferencesDictionary();
            id storedValue = preferences[kPreferenceKeyActivationMethod];
            ActivationMethod currentOptions =
                storedValue ? [storedValue unsignedIntegerValue] : kPreferenceKeyActivationMethodDefaultValue;
            
            // Get valid values and titles
            NSArray *validValues = [specifier propertyForKey:@"validValues"];
            NSArray *validTitles = [specifier propertyForKey:@"validTitles"];
            
            // Find selected options
            NSMutableArray *selectedTitles = [NSMutableArray array];
            if (currentOptions == 0) {
                [selectedTitles addObject:[bundle localizedStringForKey:@"None" value:nil table:@"Root"]];
            } else {
                for (NSUInteger i = 0; i < validValues.count; i++) {
                    NSNumber *value = validValues[i];
                    NSInteger optionValue = [value integerValue];
                    if (optionValue != 0 && (currentOptions & optionValue)) {
                        [selectedTitles addObject:[bundle localizedStringForKey:validTitles[i] value:nil table:@"Root"]];
                    }
                }
            }
            
            // Format the detail text based on the number of selected options
            NSString *detailText;
            if (selectedTitles.count == 1) {
                // Only one option - display its name
                detailText = selectedTitles[0];
            } else if (selectedTitles.count == 2) {
                // Two options - display "Option A and Option B"
                NSString *format = [bundle localizedStringForKey:@"%@ and %@" value:nil table:@"Root"];
                detailText = [NSString stringWithFormat:format, selectedTitles[0], selectedTitles[1]];
            } else if (selectedTitles.count > 2) {
                // Three or more options - display "Option A and X others"
                NSString *format = [bundle localizedStringForKey:@"%@ and %d others" value:nil table:@"Root"];
                detailText = [NSString stringWithFormat:format, selectedTitles[0], (int)selectedTitles.count - 1];
            } else {
                detailText = @"";
            }
            
            cell.detailTextLabel.text = detailText;
            return cell;
        }
    }
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

@end
