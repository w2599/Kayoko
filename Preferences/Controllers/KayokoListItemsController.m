//
//  KayokoListItemsController.m
//  Kayoko
//
//  Created by 82Flex
//

#import "KayokoListItemsController.h"
#import "KayokoPreferencesFileAccess.h"

#import <roothide.h>

#import "../NotificationKeys.h"
#import "../PreferenceKeys.h"

@implementation KayokoListItemsController {
    NSMutableSet *_selectedIndices;
    ActivationMethod _currentOptions;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (!_selectedIndices) {
        _selectedIndices = [NSMutableSet set];
    }

    // Read current configuration value (0 means "None")
    id value = KayokoPreferenceValueForSpecifier(self.specifier);
    _currentOptions = value ? [value integerValue] : kPreferenceKeyActivationMethodDefaultValue;

    // Initialize selected indices
    [_selectedIndices removeAllObjects];
    NSArray *validValues = [self.specifier propertyForKey:@"validValues"];
    NSUInteger noneIndex = [validValues indexOfObject:@0];
    if (_currentOptions == 0 && noneIndex != NSNotFound) {
        [_selectedIndices addObject:@(noneIndex)];
    } else {
        for (NSUInteger i = 0; i < validValues.count; i++) {
            NSNumber *value = validValues[i];
            NSInteger optionValue = [value integerValue];
            if (optionValue != 0 && (_currentOptions & optionValue)) {
                [_selectedIndices addObject:@(i)];
            }
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSUInteger selectedIndex = indexPath.row;

    NSArray *validValues = [self.specifier propertyForKey:@"validValues"];
    NSUInteger noneIndex = [validValues indexOfObject:@0];
    BOOL selectedNone = (noneIndex != NSNotFound) && (selectedIndex == noneIndex);

    // Check if this option is already selected
    NSNumber *indexNumber = @(selectedIndex);
    if (selectedNone) {
        if (![_selectedIndices containsObject:indexNumber]) {
            // "None" is exclusive
            [_selectedIndices removeAllObjects];
            [_selectedIndices addObject:indexNumber];
        } else {
            // Keep at least one option selected
            [tableView reloadData];
            return;
        }
    } else {
        // If a regular option is selected while "None" is active, disable "None".
        if (noneIndex != NSNotFound) {
            [_selectedIndices removeObject:@(noneIndex)];
        }

        if ([_selectedIndices containsObject:indexNumber]) {
            // If this is the last selected item, don't allow deselection
            if (_selectedIndices.count > 1) {
                [_selectedIndices removeObject:indexNumber];
            } else {
                // If only one option is selected, keep it selected
                [tableView reloadData];
                return;
            }
        } else {
            [_selectedIndices addObject:indexNumber];
        }
    }

    // Update options
    ActivationMethod newOptions = 0;
    if (noneIndex != NSNotFound && [_selectedIndices containsObject:@(noneIndex)]) {
        newOptions = 0;
    } else {
        for (NSNumber *index in _selectedIndices) {
            NSNumber *value = validValues[[index integerValue]];
            NSInteger optionValue = [value integerValue];
            if (optionValue != 0) {
                newOptions |= optionValue;
            }
        }
    }

    _currentOptions = newOptions;
    KayokoWritePreferenceValue([self.specifier propertyForKey:@"key"], @(newOptions));
    [(PSListController *)self.parentController reloadSpecifiers];

    // Post notification
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyPreferencesReload, nil, nil, YES);

    [tableView reloadData];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

    // Set selection mark
    if ([_selectedIndices containsObject:@(indexPath.row)]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

@end
