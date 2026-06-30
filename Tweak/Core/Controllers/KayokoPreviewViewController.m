//
//  KayokoPreviewViewController.m
//  Kayoko
//

#import "KayokoPreviewViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoPreviewView.h"
#import "KayokoTableView.h"
#import "KayokoWordSelectionView.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPreviewViewController ()
@property(nonatomic, strong, readwrite) KayokoPreviewView *previewView;
@property(nonatomic, weak) UIButton *favoritesButton;
@property(nonatomic, weak) UIButton *backButton;
@property(nonatomic, weak) UIButton *clearButton;
@property(nonatomic, weak, nullable, readwrite) KayokoTableView *sourceTableView;
@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) PasteboardItem *previewItem;

- (void)restoreHeaderButtonsForSourceHistoryKey:(nullable NSString *)historyKey;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPreviewViewController

- (instancetype)initWithFavoritesButton:(UIButton *)favoritesButton
                          backButton:(UIButton *)backButton
                         clearButton:(UIButton *)clearButton {
    self = [super init];
    if (self) {
        _previewView = [[KayokoPreviewView alloc]
            initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                 value:nil
                                                                                 table:@"Tweak"]];
        _favoritesButton = favoritesButton;
        _backButton = backButton;
        _clearButton = clearButton;
        [self setView:_previewView];
        __weak typeof(self) weakSelf = self;
        [[_previewView wordSelectionView] setSelectionChangedHandler:^{
          [weakSelf updateActionButtonState];
        }];
    }
    return self;
}

- (void)updateStyleForHeaderButton:(UIButton *)button
                      withImageName:(NSString *)imageName
                       andImageSize:(NSUInteger)imageSize
                       andTintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName] ?: [UIImage systemImageNamed:@"doc.on.doc"];
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

- (void)showPreviewWithItem:(PasteboardItem *)item
            sourceTableView:(KayokoTableView *)sourceTableView
           sourceHistoryKey:(NSString *)sourceHistoryKey
       enablesWordSelection:(BOOL)enablesWordSelection
         automaticallyPaste:(BOOL)automaticallyPaste {
    [self setPreviewItem:item];
    [self setSourceTableView:sourceTableView];
    [self setSourceHistoryKey:sourceHistoryKey];

    if (![[item imageName] isEqualToString:@""]) {
        NSData *imageData = [[NSFileManager defaultManager]
            contentsAtPath:[NSString
                               stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]]];
        [[[self previewView] imageView] setImage:[UIImage imageWithData:imageData]];
        [[[self previewView] imageView] setHidden:NO];
    } else {
        [[self previewView] showText:[item content] enablesWordSelection:enablesWordSelection];
    }

    [[self delegate] previewViewController:self showView:[self previewView] hideView:sourceTableView reverse:NO];

    [self updateStyleForHeaderButton:[self favoritesButton]
                        withImageName:@"arrowshape.turn.up.backward"
                         andImageSize:kFavoritesButtonImageSize
                         andTintColor:[UIColor labelColor]];
    [self updateStyleForHeaderButton:[self backButton]
                        withImageName:(automaticallyPaste ? @"doc.on.clipboard" : @"doc.on.doc.fill")
                         andImageSize:kBackButtonImageSize
                         andTintColor:[UIColor labelColor]];
    [[self favoritesButton] setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                                          value:nil
                                                                                                          table:@"Tweak"]];
    [[self backButton] setAccessibilityLabel:[[PasteboardManager localizationBundle]
                                                 localizedStringForKey:(automaticallyPaste ? @"Paste" : @"Copy")
                                                                 value:nil
                                                                 table:@"Tweak"]];
    [[self clearButton] setHidden:YES];
    [[self backButton] setHidden:![[self previewView] showingWordSelection]];
    [self updateActionButtonState];

    [[self delegate] previewViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)hidePreview {
    if ([[self previewView] isHidden]) {
        return;
    }

    [[self delegate] previewViewController:self showView:[self sourceTableView] hideView:[self previewView] reverse:YES];
    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    [self setPreviewItem:nil];

    [self restoreHeaderButtonsForSourceHistoryKey:[self sourceHistoryKey]];
    [[self favoritesButton] setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                                          value:nil
                                                                                                          table:@"Tweak"]];
    [[self previewView] reset];
    [[self delegate] previewViewControllerDidEndPreview:self];
}

- (void)handleActionButtonWithAutomaticallyPaste:(BOOL)automaticallyPaste {
    PasteboardItem *previewItem = [self previewItem];
    if (!previewItem || [[self previewView] isHidden] || ![[self previewView] showingWordSelection] ||
        ![[self previewView] hasSelectedText]) {
        return;
    }

    NSString *text = [[self previewView] selectedText];
    PasteboardItem *selectedItem = [[PasteboardItem alloc] initWithBundleIdentifier:[previewItem bundleIdentifier]
                                                                         andContent:text
                                                                     withImageNamed:@""];
    NSString *historyKey = [self sourceHistoryKey] ?: kHistoryKeyHistory;
    if (automaticallyPaste) {
        [[PasteboardManager sharedInstance] performDirectPasteWithPasteboardItem:selectedItem
                                                                     historyItem:previewItem
                                                              fromHistoryWithKey:historyKey
                                                                 shouldAutoPaste:YES];
    } else {
        PasteboardManager *pasteboardManager = [PasteboardManager sharedInstance];
        if ([pasteboardManager copyPasteboardItemToPasteboard:selectedItem]) {
            [pasteboardManager addPasteboardItem:selectedItem toHistoryWithKey:kHistoryKeyHistory];
        }
    }

    [[self delegate] previewViewController:self
               hideContainerWithCompletion:^{
                 [self restoreSourceAfterAction];
               }];
    [[self delegate] previewViewController:self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)restoreSourceAfterAction {
    [self resetPreviewState];
}

- (void)resetPreviewState {
    BOOL wasShowingPreview = ![[self previewView] isHidden] || [self previewItem] != nil;
    [[self previewView] reset];
    [[self previewView] setHidden:YES];
    [[self sourceTableView] setHidden:NO];
    [[self sourceTableView] setAlpha:1];
    [[self sourceTableView] setTransform:CGAffineTransformIdentity];
    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    [self restoreHeaderButtonsForSourceHistoryKey:[self sourceHistoryKey]];
    [[self favoritesButton] setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                                          value:nil
                                                                                                          table:@"Tweak"]];
    [self setPreviewItem:nil];

    if (wasShowingPreview) {
        [[self delegate] previewViewControllerDidEndPreview:self];
    }
}

- (void)restoreHeaderButtonsForSourceHistoryKey:(nullable NSString *)historyKey {
    BOOL showingFavorites = [historyKey isEqualToString:kHistoryKeyFavorites];
    NSString *imageName = showingFavorites ? @"heart.fill" : @"heart";
    UIColor *tintColor = showingFavorites ? [UIColor systemPinkColor] : [UIColor labelColor];
    [self updateStyleForHeaderButton:[self favoritesButton]
                        withImageName:imageName
                         andImageSize:kFavoritesButtonImageSize
                         andTintColor:tintColor];
}

- (void)updateActionButtonState {
    BOOL enabled = [[self previewView] showingWordSelection] && [[self previewView] hasSelectedText];
    [[self backButton] setEnabled:enabled];
    [[self backButton] setAlpha:enabled ? 1.0 : 0.35];
}

@end
