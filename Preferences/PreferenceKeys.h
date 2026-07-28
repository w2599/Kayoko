//
//  PreferenceKeys.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, ActivationMethod) {
    kActivationMethodPredictionBar = 1 << 0,
    kActivationMethodDictationKey = 1 << 1,
    kActivationMethodInputSwitcher = 1 << 2,
    kActivationMethodCalloutBar = 1 << 3
};

static NSString *const kPreferencesIdentifier = @"codes.aurora.kayoko.preferences";

static NSString *const kPreferenceKeyEnabled = @"Enabled";
static NSString *const kPreferenceKeyMaximumHistoryAmount = @"MaximumHistoryAmount";
static NSString *const kPreferenceKeySaveText = @"SaveText";
static NSString *const kPreferenceKeySaveImages = @"SaveImages";
static NSString *const kPreferenceKeyActivationMethod = @"ActivationMethod";
static NSString *const kPreferenceKeyAutomaticallyPaste = @"AutomaticallyPaste";
static NSString *const kPreferenceKeyDisablePasteTips = @"DisablePasteTips";
static NSString *const kPreferenceKeyIgnoreRemoteReplication = @"IgnoreRemoteReplication";
static NSString *const kPreferenceKeyAlwaysShowFavoritesOnShow = @"AlwaysShowFavoritesOnShow";
static NSString *const kPreferenceKeyShowRecordedTime = @"ShowRecordedTime";
static NSString *const kPreferenceKeyShowRecordedTimeInHistory = @"ShowRecordedTimeInHistory";
static NSString *const kPreferenceKeyShowRecordedTimeInFavorites = @"ShowRecordedTimeInFavorites";
static NSString *const kPreferenceKeyPlaySoundEffects = @"PlaySoundEffects";
static NSString *const kPreferenceKeyPlayHapticFeedback = @"PlayHapticFeedback";
static NSString *const kPreferenceKeyHeightInPoints = @"HeightInPoints";
static NSString *const kPreferenceKeyTableViewRowHeight = @"TableViewRowHeight";

static BOOL const kPreferenceKeyEnabledDefaultValue = YES;
static NSUInteger const kPreferenceKeyMaximumHistoryAmountDefaultValue = 200;
static BOOL const kPreferenceKeySaveTextDefaultValue = YES;
static BOOL const kPreferenceKeySaveImagesDefaultValue = YES;
static ActivationMethod const kPreferenceKeyActivationMethodDefaultValue = 0;
static BOOL const kPreferenceKeyAutomaticallyPasteDefaultValue = YES;
static BOOL const kPreferenceKeyDisablePasteTipsDefaultValue = NO;
static BOOL const kPreferenceKeyIgnoreRemoteReplicationDefaultValue = NO;
static BOOL const kPreferenceKeyAlwaysShowFavoritesOnShowDefaultValue = NO;
static BOOL const kPreferenceKeyShowRecordedTimeDefaultValue = NO;
static BOOL const kPreferenceKeyShowRecordedTimeInHistoryDefaultValue = NO;
static BOOL const kPreferenceKeyShowRecordedTimeInFavoritesDefaultValue = NO;
static BOOL const kPreferenceKeyPlaySoundEffectsDefaultValue = YES;
static BOOL const kPreferenceKeyPlayHapticFeedbackDefaultValue = YES;
static CGFloat const kPreferenceKeyHeightInPointsDefaultValue = 420;
static CGFloat const kPreferenceKeyTableViewRowHeightDefaultValue = 54.0;
