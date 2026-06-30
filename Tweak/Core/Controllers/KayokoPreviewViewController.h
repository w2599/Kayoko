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

@interface KayokoPreviewViewController : NSObject

@property(nonatomic, weak, nullable) id<KayokoPreviewViewControllerDelegate> delegate;
@property(nonatomic, weak, nullable, readonly) KayokoTableView *sourceTableView;
@property(nonatomic, strong, nullable, readonly) PasteboardItem *previewItem;

- (instancetype)initWithPreviewView:(KayokoPreviewView *)previewView
                     favoritesButton:(UIButton *)favoritesButton
                          backButton:(UIButton *)backButton
                         clearButton:(UIButton *)clearButton;

- (void)showPreviewWithItem:(PasteboardItem *)item
            sourceTableView:(KayokoTableView *)sourceTableView
       enablesWordSelection:(BOOL)enablesWordSelection
         automaticallyPaste:(BOOL)automaticallyPaste;
- (void)hidePreview;
- (void)handleActionButtonWithAutomaticallyPaste:(BOOL)automaticallyPaste;
- (void)updateActionButtonState;
- (void)restoreSourceAfterAction;

@end

NS_ASSUME_NONNULL_END
