//
//  PreferenceKeys.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ActivationMethod) {
    kActivationMethodPredictionBar = 0,
    kActivationMethodDictationKey = 1,
    kActivationMethodInputSwitcher = 2,
    kActivationMethodCalloutBar = 3
};

static NSString *const kPreferencesIdentifier = @"codes.aurora.kayoko.preferences";

static NSString *const kPreferenceKeyEnabled = @"Enabled";
static NSString *const kPreferenceKeyMaximumHistoryAmount = @"MaximumHistoryAmount";
static NSString *const kPreferenceKeySaveText = @"SaveText";
static NSString *const kPreferenceKeySaveImages = @"SaveImages";
static NSString *const kPreferenceKeyActivationMethod = @"ActivationMethod";
static NSString *const kPreferenceKeyAutomaticallyPaste = @"AutomaticallyPaste";
static NSString *const kPreferenceKeyDisablePasteTips = @"DisablePasteTips";
static NSString *const kPreferenceKeyPlaySoundEffects = @"PlaySoundEffects";
static NSString *const kPreferenceKeyPlayHapticFeedback = @"PlayHapticFeedback";
static NSString *const kPreferenceKeyHeightInPoints = @"HeightInPoints";

static BOOL const kPreferenceKeyEnabledDefaultValue = YES;
static NSUInteger const kPreferenceKeyMaximumHistoryAmountDefaultValue = 200;
static BOOL const kPreferenceKeySaveTextDefaultValue = YES;
static BOOL const kPreferenceKeySaveImagesDefaultValue = YES;
static ActivationMethod const kPreferenceKeyActivationMethodDefaultValue = kActivationMethodPredictionBar;
static BOOL const kPreferenceKeyAutomaticallyPasteDefaultValue = YES;
static BOOL const kPreferenceKeyDisablePasteTipsDefaultValue = NO;
static BOOL const kPreferenceKeyPlaySoundEffectsDefaultValue = YES;
static BOOL const kPreferenceKeyPlayHapticFeedbackDefaultValue = YES;
static CGFloat const kPreferenceKeyHeightInPointsDefaultValue = 420;
