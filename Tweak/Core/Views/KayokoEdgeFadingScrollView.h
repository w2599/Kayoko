//
//  KayokoEdgeFadingScrollView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoEdgeFadingScrollView : UIScrollView
@property(nonatomic, assign) CGFloat edgeFadeWidth;
@property(nonatomic, assign, getter=isEdgeFadeEnabled) BOOL edgeFadeEnabled;
- (void)updateEdgeFadeMask;
@end

NS_ASSUME_NONNULL_END
