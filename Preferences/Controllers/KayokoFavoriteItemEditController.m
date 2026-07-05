//
//  KayokoFavoriteItemEditController.m
//  Kayoko
//

#import "KayokoFavoriteItemEditController.h"

@interface KayokoFavoriteItemEditController () <UITextViewDelegate>

@property(nonatomic, strong) UITextField *remarkTextField;
@property(nonatomic, strong) UITextView *contentTextView;

@end

@implementation KayokoFavoriteItemEditController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    self.title = [bundle localizedStringForKey:@"Edit Item" value:nil table:@"Root"];

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:[bundle localizedStringForKey:@"Save" value:nil table:@"Root"]
                                          style:UIBarButtonItemStyleDone
                                         target:self
                                         action:@selector(saveButtonTapped)];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scrollView];

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 16;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stackView];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stackView.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:16],
        [stackView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-16],
        [stackView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:16],
        [stackView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-16],
        [stackView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-32]
    ]];

    UITextField *remarkTextField = nil;
    UIView *remarkGroup = [self groupWithLabelKey:@"Remark" bundle:bundle textField:&remarkTextField];
    remarkGroup.translatesAutoresizingMaskIntoConstraints = NO;
    [stackView addArrangedSubview:remarkGroup];
    self.remarkTextField = remarkTextField;
    self.remarkTextField.text = self.initialRemark ?: @"";

    if (!self.isImage) {
        UITextView *contentTextView = nil;
        UIView *contentGroup = [self groupWithLabelKey:@"Text" bundle:bundle textView:&contentTextView minimumLines:12];
        contentGroup.translatesAutoresizingMaskIntoConstraints = NO;
        [stackView addArrangedSubview:contentGroup];
        self.contentTextView = contentTextView;
        self.contentTextView.text = self.initialContent ?: @"";
        self.contentTextView.delegate = self;
    }
}

- (UIView *)groupWithLabelKey:(NSString *)labelKey bundle:(NSBundle *)bundle textField:(UITextField **)outTextField {
    UIView *container = [[UIView alloc] init];

    UILabel *label = [self labelWithLabelKey:labelKey bundle:bundle];
    [container addSubview:label];

    UITextField *textField = [[UITextField alloc] init];
    textField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    textField.borderStyle = UITextBorderStyleNone;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    textField.leftViewMode = UITextFieldViewModeAlways;
    textField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    textField.rightViewMode = UITextFieldViewModeAlways;
    textField.layer.cornerRadius = 10;
    if (@available(iOS 13.0, *)) {
        textField.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        textField.backgroundColor = [UIColor whiteColor];
    }
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:textField];

    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:container.topAnchor],
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [textField.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:6],
        [textField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [textField.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [textField.heightAnchor constraintEqualToConstant:44]
    ]];

    if (outTextField) {
        *outTextField = textField;
    }

    return container;
}

- (UIView *)groupWithLabelKey:(NSString *)labelKey
                       bundle:(NSBundle *)bundle
                     textView:(UITextView **)outTextView
                 minimumLines:(NSUInteger)minimumLines {
    UIView *container = [[UIView alloc] init];

    UILabel *label = [self labelWithLabelKey:labelKey bundle:bundle];
    [container addSubview:label];

    UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    UIEdgeInsets textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);

    UITextView *textView = [[UITextView alloc] init];
    textView.font = font;
    textView.layer.cornerRadius = 10;
    textView.textContainerInset = textContainerInset;
    if (@available(iOS 13.0, *)) {
        textView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        textView.backgroundColor = [UIColor whiteColor];
    }
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:textView];

    CGFloat minHeight = ceil(font.lineHeight * minimumLines) + textContainerInset.top + textContainerInset.bottom;

    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:container.topAnchor],
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [textView.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:6],
        [textView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [textView.heightAnchor constraintGreaterThanOrEqualToConstant:minHeight]
    ]];

    if (outTextView) {
        *outTextView = textView;
    }

    return container;
}

- (UILabel *)labelWithLabelKey:(NSString *)labelKey bundle:(NSBundle *)bundle {
    UILabel *label = [[UILabel alloc] init];
    label.text = [bundle localizedStringForKey:labelKey value:nil table:@"Root"];
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    if (@available(iOS 13.0, *)) {
        label.textColor = [UIColor secondaryLabelColor];
    }
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (void)saveButtonTapped {
    NSString *content = self.isImage ? (self.initialContent ?: @"") : (self.contentTextView.text ?: @"");
    NSString *remark = [self.remarkTextField.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (self.completionHandler) {
        self.completionHandler(content, remark);
    }

    [self.navigationController popViewControllerAnimated:YES];
}

@end
