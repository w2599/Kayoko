//
//  KayokoNoteEditorViewController.m
//  Kayoko
//

#import "KayokoNoteEditorViewController.h"

#import "KayokoApplicationMetadataProvider.h"
#import "KayokoNoteEditorView.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoTableViewCell.h"

@interface UIPeripheralHost : NSObject
+ (instancetype)sharedInstance;
+ (NSArray<NSValue *> *)allVisiblePeripheralFrames;
- (BOOL)isOnScreen;
@end

NS_ASSUME_NONNULL_BEGIN

@interface KayokoNoteEditorViewController () <UITextFieldDelegate>

@property(nonatomic, strong, readwrite) KayokoNoteEditorView *noteEditorView;
@property(nonatomic, strong, readwrite, nullable) KayokoPasteboardItem *item;
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;
@property(nonatomic, copy) NSString *sourceDisplayName;
@property(nonatomic, assign, getter=isSaving) BOOL saving;

@end


@implementation KayokoNoteEditorViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillChangeFrameNotification:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillHideNotification:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    KayokoNoteEditorView *noteEditorView = [[KayokoNoteEditorView alloc] initWithFrame:CGRectZero];
    [self setNoteEditorView:noteEditorView];
    [self setView:noteEditorView];

    NSBundle *bundle = [KayokoPasteboardManager localizationBundle];
    [[noteEditorView textField] setPlaceholder:[bundle localizedStringForKey:@"Note" value:nil table:@"Tweak"]];
    [[noteEditorView textField] setDelegate:self];
    [[noteEditorView textField] addTarget:self
                                   action:@selector(handleTextFieldEditingChanged:)
                         forControlEvents:UIControlEventEditingChanged];
    [[noteEditorView saveButton] setTitle:[bundle localizedStringForKey:@"Save" value:nil table:@"Tweak"]
                                  forState:UIControlStateNormal];
    [[noteEditorView saveButton] addTarget:self
                                    action:@selector(handleSaveButtonPressed)
                          forControlEvents:UIControlEventTouchUpInside];
}

- (nullable NSString *)normalizedNote {
    NSString *note = [[[self noteEditorView] textField].text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [note length] > 0 ? note : nil;
}

- (void)updatePreview {
    NSString *displayName = [self normalizedNote] ?: [self sourceDisplayName] ?: @"";
    UILabel *headerLabel = [[[self noteEditorView] previewCell] headerLabel];
    [headerLabel setAttributedText:nil];
    [headerLabel setText:displayName];
}

- (void)prepareForItem:(KayokoPasteboardItem *)item
      presentationCell:(KayokoTableViewCell *)presentationCell
            cellHeight:(CGFloat)cellHeight
    keyboardBottomInset:(CGFloat)keyboardBottomInset {
    [self loadViewIfNeeded];
    [self setItem:item];
    [self setSourceDisplayName:[[self metadataProvider] displayNameForBundleIdentifier:[item bundleIdentifier]]];
    [[[self noteEditorView] textField] setText:[item note] ?: @""];
    [[self noteEditorView] setPreviewCellHeight:cellHeight];
    [[self noteEditorView] setPreviewCell:presentationCell];
    [[self noteEditorView] setKeyboardBottomInset:keyboardBottomInset];
    [self setSaving:NO];
    [self updatePreview];
}

- (void)beginEditing {
    KayokoNoteEditorView *noteEditorView = [self noteEditorView];
    [noteEditorView layoutIfNeeded];

    UIWindow *window = [noteEditorView window];
    if (window && ![window isKeyWindow]) {
        [window makeKeyWindow];
    }

    Class hostClass = NSClassFromString(@"UIPeripheralHost");
    if (window && [hostClass respondsToSelector:@selector(sharedInstance)] &&
        [hostClass respondsToSelector:@selector(allVisiblePeripheralFrames)]) {
        UIPeripheralHost *host = [(id)hostClass sharedInstance];
        if ([host respondsToSelector:@selector(isOnScreen)] && [host isOnScreen]) {
            CGRect keyboardFrame = CGRectNull;
            for (NSValue *frameValue in [(id)hostClass allVisiblePeripheralFrames]) {
                CGRect frame = [frameValue CGRectValue];
                if (CGRectIsNull(frame) || CGRectIsEmpty(frame)) {
                    continue;
                }
                keyboardFrame = CGRectIsNull(keyboardFrame) ? frame : CGRectUnion(keyboardFrame, frame);
            }
            if (!CGRectIsNull(keyboardFrame) && !CGRectIsEmpty(keyboardFrame)) {
                CGRect keyboardFrameInWindow = [window convertRect:keyboardFrame fromWindow:nil];
                CGFloat keyboardBottomInset =
                    MAX(CGRectGetMaxY([window bounds]) - CGRectGetMinY(keyboardFrameInWindow), 0);
                [[self delegate]
                    noteEditorViewController:self
                    didUpdateKeyboardBottomInset:keyboardBottomInset
                    animationDuration:0.25
                    options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState |
                            UIViewAnimationOptionAllowUserInteraction];
            }
        }
    }

    UITextField *textField = [noteEditorView textField];
    if ([textField becomeFirstResponder]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (![self item] || [noteEditorView isHidden] || ![noteEditorView window] || [textField isFirstResponder]) {
          return;
      }
      [[noteEditorView window] makeKeyWindow];
      [textField becomeFirstResponder];
    });
}

- (void)resignEditing {
    [[[self noteEditorView] textField] resignFirstResponder];
}

- (void)setSaving:(BOOL)saving {
    _saving = saving;
    [[[self noteEditorView] textField] setEnabled:!saving];
    [[[self noteEditorView] saveButton] setEnabled:!saving];
    [[[self noteEditorView] saveButton] setAlpha:saving ? 0.55 : 1.0];
}

- (void)reset {
    [self resignEditing];
    [self setSaving:NO];
    [self setItem:nil];
    [self setSourceDisplayName:@""];
    [[[self noteEditorView] textField] setText:@""];
    [[self noteEditorView] setKeyboardBottomInset:0];
    [[self noteEditorView] setPreviewCell:nil];
}

- (void)handleTextFieldEditingChanged:(UITextField *)textField {
    (void)textField;
    [self updatePreview];
}

- (void)requestSave {
    if ([self isSaving] || ![self item]) {
        return;
    }
    [self setSaving:YES];
    [[self delegate] noteEditorViewController:self didRequestSaveNote:[self normalizedNote]];
}

- (void)handleSaveButtonPressed {
    [self requestSave];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    (void)textField;
    [self requestSave];
    return NO;
}

- (BOOL)shouldHandleKeyboardNotification:(NSNotification *)notification {
    if (![self item] || [[[self noteEditorView] window] isHidden] || [[self noteEditorView] isHidden]) {
        return NO;
    }
    return [notification.userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
}

- (void)updateKeyboardBottomInset:(CGFloat)keyboardBottomInset
          withAnimationParametersFromNotification:(NSNotification *)notification {
    KayokoNoteEditorView *view = [self noteEditorView];
    keyboardBottomInset = MAX(keyboardBottomInset, 0);
    if (fabs([view keyboardBottomInset] - keyboardBottomInset) <= 0.5) {
        return;
    }

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve =
        (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)(curve << 16) |
                                     UIViewAnimationOptionBeginFromCurrentState |
                                     UIViewAnimationOptionAllowUserInteraction;
    [[self delegate] noteEditorViewController:self
               didUpdateKeyboardBottomInset:keyboardBottomInset
                          animationDuration:duration
                                    options:options];
}

- (void)handleKeyboardWillChangeFrameNotification:(NSNotification *)notification {
    if (![self shouldHandleKeyboardNotification:notification]) {
        return;
    }

    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIWindow *window = [[self noteEditorView] window] ?: [[[self noteEditorView] superview] window];
    if (!window) {
        return;
    }
    CGRect keyboardFrameInWindow = [window convertRect:keyboardEndFrame fromWindow:nil];
    CGFloat keyboardBottomInset =
        MAX(CGRectGetMaxY([window bounds]) - CGRectGetMinY(keyboardFrameInWindow), 0);
    [self updateKeyboardBottomInset:keyboardBottomInset withAnimationParametersFromNotification:notification];
}

- (void)handleKeyboardWillHideNotification:(NSNotification *)notification {
    if (![self item]) {
        return;
    }
    [self updateKeyboardBottomInset:0 withAnimationParametersFromNotification:notification];
}

@end

NS_ASSUME_NONNULL_END
