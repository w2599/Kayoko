//
//  KayokoView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class KayokoTableView;
@class KayokoHistoryTableView;
@class KayokoFavoritesTableView;
@class KayokoPreviewView;
@class PasteboardItem;

static NSUInteger const kFavoritesButtonImageSize = 24;
static NSUInteger const kClearButtonImageSize = 20;
static NSUInteger const kBackButtonImageSize = 20;

@interface KayokoView : UIView {
    KayokoTableView *_previewSourceTableView;
    BOOL _isAnimating;
}
@property(nonatomic, strong) UIBlurEffect *blurEffect;
@property(nonatomic, strong) UIVisualEffectView *blurEffectView;
@property(nonatomic, strong) UIView *headerView;
@property(nonatomic, strong) NSLayoutConstraint *headerHeightConstraint;
@property(nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property(nonatomic, strong) UISegmentedControl *contentSegmentedControl;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *clearButton;
@property(nonatomic, strong) UIButton *sortButton;
@property(nonatomic, strong) UIButton *closeButton;
@property(nonatomic, strong) UIButton *backButton;
@property(nonatomic, strong) UIButton *favoritesButton;
@property(nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property(nonatomic, strong) KayokoHistoryTableView *historyTableView;
@property(nonatomic, strong) KayokoFavoritesTableView *favoritesTableView;
@property(nonatomic, strong) KayokoPreviewView *previewView;
@property(nonatomic, strong) UIImpactFeedbackGenerator *feedbackGenerator;
@property(nonatomic, weak) UIView *backdropView;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) BOOL shouldPlayFeedback;
@property(nonatomic, assign) BOOL alwaysShowFavoritesOnShow;
@property(nonatomic, assign) BOOL showRecordedTimeInHistory;
@property(nonatomic, assign) BOOL showRecordedTimeInFavorites;
@property(nonatomic, assign) BOOL cleaning;
- (instancetype)initWithFrame:(CGRect)frame rowHeight:(CGFloat)rowHeight;
- (void)showPreviewWithItem:(PasteboardItem *)item;
- (void)show;
- (void)hide;
- (void)reload;
@end
