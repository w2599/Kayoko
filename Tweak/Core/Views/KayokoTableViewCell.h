//
//  KayokoTableViewCell.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class PasteboardItem;

@interface KayokoTableViewCell : UITableViewCell
@property(nonatomic) UIImageView *iconImageView;
@property(nonatomic) UILabel *headerLabel;
@property(nonatomic) UILabel *remarkLabel;
@property(nonatomic) UIView *remarkContainer;
@property(nonatomic) UIImageView *contentImageView;
- (instancetype)initWithStyle:(UITableViewCellStyle)style
                      andItem:(PasteboardItem *)item
              showRecordedTime:(BOOL)showRecordedTime
                   historyKey:(NSString *)historyKey
              reuseIdentifier:(NSString *)reuseIdentifier;
- (void)configureWithItem:(PasteboardItem *)item showRecordedTime:(BOOL)showRecordedTime historyKey:(NSString *)historyKey;
// 在 cell 真正要展示时才去请求/缓存图片缩略图（预热阶段只构建文字/布局，不提前拉图）。
- (void)loadImageIfNeeded;
@end

@interface UIImage (Private)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale;
@end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (id)applicationWithBundleIdentifier:(id)arg1;
@end
