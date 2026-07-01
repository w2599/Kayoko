//
//  KayokoHistoryChangeNotifier.m
//  Kayoko
//

#import "KayokoHistoryChangeNotifier.h"
#import "NotificationKeys.h"
#import "PasteboardManager.h"

@implementation KayokoHistoryChangeNotifier

- (void)postReloadNotificationWithObject:(id)object {
    [self postChangeNotificationForHistoryKey:nil
                                   changeType:kPasteboardManagerHistoryChangeTypeReload
                               itemDictionary:nil
                                        limit:0
                                       object:object];
}

- (void)postChangeNotificationForHistoryKey:(NSString *)historyKey
                                 changeType:(NSString *)changeType
                             itemDictionary:(NSDictionary<NSString *, id> *)itemDictionary
                                      limit:(NSUInteger)limit
                                     object:(id)object {
    NSDictionary<NSString *, id> *userInfo = [self userInfoWithChangeType:changeType
                                                                historyKey:historyKey
                                                            itemDictionary:itemDictionary
                                                                     limit:limit];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter] postNotificationName:kPasteboardManagerHistoryDidChangeNotification
                                                          object:object
                                                        userInfo:userInfo];
    });
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kNotificationKeyCoreReload, nil, nil, YES);
}

- (NSDictionary<NSString *, id> *)userInfoWithChangeType:(NSString *)changeType
                                              historyKey:(NSString *)historyKey
                                          itemDictionary:(NSDictionary<NSString *, id> *)itemDictionary
                                                   limit:(NSUInteger)limit {
    NSMutableDictionary<NSString *, id> *userInfo = [[NSMutableDictionary alloc] init];
    userInfo[kPasteboardManagerHistoryChangeTypeKey] = changeType ?: kPasteboardManagerHistoryChangeTypeReload;
    if ([historyKey length] > 0) {
        userInfo[kPasteboardManagerHistoryChangeHistoryKeyKey] = historyKey;
        userInfo[kPasteboardManagerHistoryChangeLimitKey] = @(limit);
    }
    if (itemDictionary) {
        userInfo[kPasteboardManagerHistoryChangeItemKey] = itemDictionary;
    }
    return userInfo;
}

@end
