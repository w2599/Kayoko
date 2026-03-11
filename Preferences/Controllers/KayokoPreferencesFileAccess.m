//
//  KayokoPreferencesFileAccess.m
//  Kayoko
//

#import "KayokoPreferencesFileAccess.h"

#import <roothide.h>

NSString *KayokoPreferencesPath(void) {
    NSString *preferencesPath = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kPreferencesIdentifier];
    return jbroot(preferencesPath);
}

NSDictionary *KayokoPreferencesDictionary(void) {
    return [NSDictionary dictionaryWithContentsOfFile:KayokoPreferencesPath()] ?: @{};
}

id KayokoPreferenceValueForSpecifier(PSSpecifier *specifier) {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) {
        return nil;
    }

    id value = KayokoPreferencesDictionary()[key];
    return value ?: [specifier propertyForKey:@"default"];
}

void KayokoWritePreferenceValue(NSString *key, id value) {
    if (!key) {
        return;
    }

    NSMutableDictionary *preferences = [KayokoPreferencesDictionary() mutableCopy] ?: [NSMutableDictionary dictionary];
    if (value) {
        preferences[key] = value;
    } else {
        [preferences removeObjectForKey:key];
    }

    [preferences writeToFile:KayokoPreferencesPath() atomically:YES];
}