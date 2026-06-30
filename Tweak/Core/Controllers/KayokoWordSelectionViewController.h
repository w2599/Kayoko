//
//  KayokoWordSelectionViewController.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoWordSelectionView;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoWordSelectionViewController : NSObject

@property(nonatomic, copy, nullable) void (^selectionChangedHandler)(void);

- (instancetype)initWithWordSelectionView:(KayokoWordSelectionView *)wordSelectionView;

@end

NS_ASSUME_NONNULL_END
