//
//  KayokoClearConfirmationViewController.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoClearConfirmationView;
@class KayokoClearConfirmationViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoClearConfirmationViewControllerDelegate <NSObject>

- (void)clearConfirmationViewControllerDidCancel:(KayokoClearConfirmationViewController *)controller;
- (void)clearConfirmationViewControllerDidClearHistoryKey:(NSString *)historyKey;
- (void)clearConfirmationViewController:(KayokoClearConfirmationViewController *)controller
         didFailClearingHistoryKey:(NSString *)historyKey;

@end

@interface KayokoClearConfirmationViewController : NSObject

@property(nonatomic, weak, nullable) id<KayokoClearConfirmationViewControllerDelegate> delegate;
@property(nonatomic, copy, nullable) NSString *historyKey;

- (instancetype)initWithView:(KayokoClearConfirmationView *)view;
- (void)beginWithHistoryKey:(NSString *)historyKey;
- (void)handleCancel;
- (void)handleConfirm;

@end

NS_ASSUME_NONNULL_END
