//
//  KayokoPreviewViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoPreviewView;
@class KayokoPreviewViewController;
@class KayokoTableView;
@class PasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoPreviewViewControllerDelegate <NSObject>

- (void)previewViewController:(KayokoPreviewViewController *)controller
                     showView:(UIView *)viewToShow
                     hideView:(UIView *)viewToHide
                      reverse:(BOOL)reverse;
- (void)previewViewController:(KayokoPreviewViewController *)controller
    hideContainerWithCompletion:(nullable void (^)(void))completion;
- (void)previewViewController:(KayokoPreviewViewController *)controller
    triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style;
- (void)previewViewControllerDidEndPreview:(KayokoPreviewViewController *)controller;

@end

@interface KayokoPreviewViewController : UIViewController

@property(nonatomic, weak, nullable) id<KayokoPreviewViewControllerDelegate> delegate;
@property(nonatomic, strong, readonly) KayokoPreviewView *previewView;
@property(nonatomic, weak, nullable, readonly) KayokoTableView *sourceTableView;
@property(nonatomic, copy, nullable, readonly) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readonly) PasteboardItem *previewItem;

- (instancetype)initWithFavoritesButton:(UIButton *)favoritesButton
                          backButton:(UIButton *)backButton
                         clearButton:(UIButton *)clearButton;

- (void)showPreviewWithItem:(PasteboardItem *)item
            sourceTableView:(KayokoTableView *)sourceTableView
           sourceHistoryKey:(NSString *)sourceHistoryKey
       enablesWordSelection:(BOOL)enablesWordSelection
         automaticallyPaste:(BOOL)automaticallyPaste;
- (void)hidePreview;
- (void)handleActionButtonWithAutomaticallyPaste:(BOOL)automaticallyPaste;
- (void)updateActionButtonState;
- (void)restoreSourceAfterAction;
- (void)resetPreviewState;

@end

NS_ASSUME_NONNULL_END
