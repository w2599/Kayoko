//
//  KayokoPreviewView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPreviewView.h"

#import "KayokoMainView.h"
#import "KayokoTagChipBarView.h"

@interface KayokoPreviewView () <UITextViewDelegate>
@property(nonatomic, strong) KayokoTagChipBarView *tagChipBarView;
@end

@implementation KayokoPreviewView

- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        [self setName:name];

        [self setTextView:[[UITextView alloc] init]];
        [[self textView] setBackgroundColor:[UIColor clearColor]];
        [[self textView] setFont:[UIFont systemFontOfSize:14]];
        [[self textView] setEditable:NO];
        [[self textView] setSelectable:NO];
        [[self textView] setAutomaticallyAdjustsScrollIndicatorInsets:NO];
        [[self textView] setDelegate:self];
        [[self textView] setTextContainerInset:UIEdgeInsetsMake(8, 16, 8, 16)];
        [[[self textView] textContainer] setLineFragmentPadding:0];
        [[self textView] setHidden:YES];
        [self addSubview:[self textView]];

        [[self textView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self textView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self textView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self textView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self textView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setImageView:[[UIImageView alloc] init]];
        [[self imageView] setContentMode:UIViewContentModeScaleAspectFit];
        [[self imageView] setHidden:YES];
        [self addSubview:[self imageView]];

        [[self imageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self imageView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self imageView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self imageView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self imageView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setTagChipBarView:[[KayokoTagChipBarView alloc] initWithFrame:CGRectZero]];
        [self addSubview:[self tagChipBarView]];
    }

    return self;
}

- (nullable KayokoMainView *)mainView {
    UIView *view = [self superview];
    while (view) {
        if ([view isKindOfClass:[KayokoMainView class]]) {
            return (KayokoMainView *)view;
        }
        view = [view superview];
    }

    return nil;
}

- (CGFloat)bottomSafeAreaInsetForContentView:(UIView *)contentView {
    CGFloat bottomInset = 0;
    KayokoMainView *mainView = [self mainView];
    if (mainView) {
        bottomInset = [mainView safeAreaBottomInsetForContentView:contentView];
    } else {
        bottomInset = MAX([contentView safeAreaInsets].bottom, 0);
    }
    return bottomInset;
}

- (CGFloat)visibleTagBarHeight {
    return [[self tagChipBarView] isHidden] ? 0 : [KayokoTagChipBarView preferredHeight];
}

- (void)layoutTagChipBarView {
    CGFloat tagBarHeight = [self visibleTagBarHeight];
    if (tagBarHeight <= 0) {
        [[self tagChipBarView] setFrame:CGRectZero];
        return;
    }

    CGFloat bottomInset = [self bottomSafeAreaInsetForContentView:self];
    CGFloat width = CGRectGetWidth([self bounds]);
    CGFloat y = MAX(CGRectGetHeight([self bounds]) - bottomInset - tagBarHeight, 0);
    [UIView performWithoutAnimation:^{
      [[self tagChipBarView] setBottomMaterialExtension:bottomInset];
      [[self tagChipBarView] setFrame:CGRectMake(0, y, width, tagBarHeight)];
    }];
}

- (void)updateTagBarFloatingProgressAnimated:(BOOL)animated {
    if ([[self tagChipBarView] isHidden]) {
        return;
    }

    CGFloat floatingProgress = 0.0;
    if (![[self textView] isHidden]) {
        floatingProgress = [KayokoTagChipBarView floatingProgressForScrollView:[self textView]];
    }

    [[self tagChipBarView] setFloatingProgress:floatingProgress animated:animated];
}

- (void)updateTextViewScrollInsets {
    CGFloat bottomInset = [self bottomSafeAreaInsetForContentView:[self textView]] + [self visibleTagBarHeight];

    UIEdgeInsets contentInset = [[self textView] contentInset];
    contentInset.bottom = bottomInset;
    [[self textView] setContentInset:contentInset];

    UIEdgeInsets indicatorInsets = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    [[self textView] setVerticalScrollIndicatorInsets:indicatorInsets];
}

- (void)showText:(NSString *)text {
    [[self textView] setText:text];
    [[self textView] setHidden:NO];
    [[self imageView] setHidden:YES];
    [self updateTextViewScrollInsets];
    [self updateTagBarFloatingProgressAnimated:NO];
}

- (void)configureTagBarWithTags:(NSArray<KayokoTag *> *)tags
                selectedTagUUID:(NSString *)selectedTagUUID
               selectionHandler:(void (^)(NSString *_Nullable tagUUID))selectionHandler {
    [[self tagChipBarView] setSelectionHandler:selectionHandler];
    [[self tagChipBarView] configureWithTags:tags ?: @[] selectedTagUUID:selectedTagUUID];
    [self layoutTagChipBarView];
    [self updateTextViewScrollInsets];
    [self updateTagBarFloatingProgressAnimated:NO];
}

- (void)setSelectedTagUUID:(NSString *)selectedTagUUID {
    [[self tagChipBarView] setSelectedTagUUID:selectedTagUUID];
}

- (void)reset {
    [[self textView] setHidden:YES];
    [[self textView] setText:@""];
    [[self imageView] setHidden:YES];
    [[self imageView] setImage:nil];
    [[self tagChipBarView] configureWithTags:@[] selectedTagUUID:nil];
    [[self tagChipBarView] setSelectionHandler:nil];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    if ([[self textView] isHidden]) {
        return;
    }

    CGPoint contentOffset = [[self textView] contentOffset];
    contentOffset.y = -[[self textView] adjustedContentInset].top;
    [[self textView] setContentOffset:contentOffset animated:animated];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layoutTagChipBarView];
    [self updateTextViewScrollInsets];
    [self updateTagBarFloatingProgressAnimated:NO];
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self layoutTagChipBarView];
    [self updateTextViewScrollInsets];
    [self updateTagBarFloatingProgressAnimated:NO];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == [self textView]) {
        [self updateTagBarFloatingProgressAnimated:NO];
    }
}

@end
