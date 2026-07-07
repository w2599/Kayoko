//
//  PasteboardItem.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

static NSString *const kItemKeyBundleIdentifier = @"bundle_identifier";
static NSString *const kItemKeyContent = @"content";
static NSString *const kItemKeyImageName = @"image_name";
static NSString *const kItemKeyRemark = @"remark";
static NSString *const kItemKeyHasLink = @"has_link";
static NSString *const kItemKeyRecordedAt = @"recorded_at";
static NSString *const kItemKeyRowId = @"row_id";

@interface PasteboardItem : NSObject

@property(nonatomic, copy) NSString *bundleIdentifier;
@property(nonatomic, copy) NSString *displayName;
@property(nonatomic, copy) NSString *content;
@property(nonatomic, copy) NSString *imageName;
@property(nonatomic, copy) NSString *remark;
@property(nonatomic, assign) BOOL hasLink;
@property(nonatomic, assign) NSTimeInterval recordedAt;
@property(nonatomic, assign) long long rowId;

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              andContent:(NSString *)content
                          withImageNamed:(NSString *)imageName
                                  remark:(NSString *)remark;
+ (PasteboardItem *)itemFromDictionary:(NSDictionary *)dictionary;

@end
