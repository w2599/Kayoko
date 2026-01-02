//
//  KayokoPreferencesFileAccess.h
//  Kayoko
//

#import <Foundation/Foundation.h>
#import <Preferences/PSSpecifier.h>

#import "../PreferenceKeys.h"

FOUNDATION_EXTERN NSString *KayokoPreferencesPath(void);
FOUNDATION_EXTERN NSDictionary *KayokoPreferencesDictionary(void);
FOUNDATION_EXTERN id KayokoPreferenceValueForSpecifier(PSSpecifier *specifier);
FOUNDATION_EXTERN void KayokoWritePreferenceValue(NSString *key, id value);