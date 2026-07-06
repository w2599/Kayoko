//
//  KayokoPreviewView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoPreviewView.h"

#import "KayokoMainView.h"

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

- (void)updateTextViewScrollInsets {
    CGFloat bottomInset = 0;
    KayokoMainView *mainView = [self mainView];
    if (mainView) {
        bottomInset = [mainView safeAreaBottomInsetForContentView:[self textView]];
    } else {
        bottomInset = MAX([[self textView] safeAreaInsets].bottom, 0);
    }

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
}

- (void)reset {
    [[self textView] setHidden:YES];
    [[self textView] setText:@""];
    [[self imageView] setHidden:YES];
    [[self imageView] setImage:nil];
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
    [self updateTextViewScrollInsets];
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self updateTextViewScrollInsets];
}

@end
