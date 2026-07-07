//
//  KayokoTagEditorViewController.m
//  Kayoko
//

#import "KayokoTagEditorViewController.h"
#import "KayokoTag.h"

#import <math.h>

static UIColor *KayokoTagEditorColorFromHex(NSString *hexColor);
static NSString *KayokoTagEditorHexColorFromColor(UIColor *color);

@interface KayokoTagEditorViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property(nonatomic, strong) KayokoTag *tag;
@property(nonatomic, strong) NSBundle *localizationBundle;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UITextField *titleTextField;
@property(nonatomic, strong) UIColorWell *colorWell;
@end

static UIColor *KayokoTagEditorColorFromHex(NSString *hexColor) {
    NSString *candidate = [KayokoTag normalizedHexColorFromString:hexColor] ?: @"#00000000";
    NSString *valueString = [candidate substringFromIndex:1];
    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:valueString];
    [scanner scanHexLongLong:&value];

    CGFloat red = (CGFloat)((value >> 24) & 0xFF) / 255.0;
    CGFloat green = (CGFloat)((value >> 16) & 0xFF) / 255.0;
    CGFloat blue = (CGFloat)((value >> 8) & 0xFF) / 255.0;
    CGFloat alpha = (CGFloat)(value & 0xFF) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

static NSString *KayokoTagEditorHexColorFromColor(UIColor *color) {
    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat alpha = 0.0;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return @"#00000000";
    }

    NSInteger redValue = (NSInteger)lrint(MAX(0.0, MIN(1.0, red)) * 255.0);
    NSInteger greenValue = (NSInteger)lrint(MAX(0.0, MIN(1.0, green)) * 255.0);
    NSInteger blueValue = (NSInteger)lrint(MAX(0.0, MIN(1.0, blue)) * 255.0);
    NSInteger alphaValue = (NSInteger)lrint(MAX(0.0, MIN(1.0, alpha)) * 255.0);
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX%02lX", (long)redValue, (long)greenValue,
                                      (long)blueValue, (long)alphaValue];
}

@implementation KayokoTagEditorViewController

- (instancetype)initWithTag:(KayokoTag *)tag localizationBundle:(NSBundle *)localizationBundle {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _tag = [tag copy];
        _localizationBundle = localizationBundle ?: [NSBundle mainBundle];
        [self setModalPresentationStyle:UIModalPresentationPageSheet];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[self view] setBackgroundColor:[UIColor systemGroupedBackgroundColor]];
    [self setTitle:[self localizedStringForKey:@"Edit Tag"]];

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Cancel"]
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(cancelEditing)];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Done"]
                                                                   style:UIBarButtonItemStyleDone
                                                                  target:self
                                                                  action:@selector(finishEditing)];
    [[self navigationItem] setLeftBarButtonItem:cancelButton];
    [[self navigationItem] setRightBarButtonItem:doneButton];

    [self configureTableView];
}

- (void)configureTableView {
    _titleTextField = [[UITextField alloc] init];
    [_titleTextField setText:[[self tag] title]];
    [_titleTextField setBorderStyle:UITextBorderStyleNone];
    [_titleTextField setClearButtonMode:UITextFieldViewModeNever];
    [_titleTextField setReturnKeyType:UIReturnKeyDone];
    [_titleTextField setDelegate:self];
    [_titleTextField setTextAlignment:NSTextAlignmentRight];
    [_titleTextField setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

    _colorWell = [[UIColorWell alloc] init];
    [_colorWell setSupportsAlpha:YES];
    [_colorWell setSelectedColor:KayokoTagEditorColorFromHex([[self tag] hexColor])];
    [_colorWell setFrame:CGRectMake(0.0, 0.0, 44.0, 44.0)];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    [_tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setKeyboardDismissMode:UIScrollViewKeyboardDismissModeInteractive];
    [[self view] addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [[_tableView topAnchor] constraintEqualToAnchor:[[self view] topAnchor]],
        [[_tableView leadingAnchor] constraintEqualToAnchor:[[self view] leadingAnchor]],
        [[_tableView trailingAnchor] constraintEqualToAnchor:[[self view] trailingAnchor]],
        [[_tableView bottomAnchor] constraintEqualToAnchor:[[self view] bottomAnchor]]
    ]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const reuseIdentifier = @"KayokoTagEditorCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }

    [[cell textLabel] setTextColor:[UIColor labelColor]];
    [[cell detailTextLabel] setText:nil];
    [cell setAccessoryView:nil];

    if ([indexPath row] == 0) {
        [[cell textLabel] setText:[self localizedStringForKey:@"Title"]];
        CGRect frame = CGRectMake(0.0, 0.0, 190.0, 36.0);
        [[self titleTextField] setFrame:frame];
        [cell setAccessoryView:[self titleTextField]];
    } else {
        [[cell textLabel] setText:[self localizedStringForKey:@"Color"]];
        [cell setAccessoryView:[self colorWell]];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([indexPath row] == 0) {
        [[self titleTextField] becomeFirstResponder];
    }
}

- (void)cancelEditing {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)finishEditing {
    NSString *title = [[[self titleTextField] text] stringByTrimmingCharactersInSet:
                                                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([title length] == 0) {
        title = [self localizedStringForKey:@"Untitled"];
    }

    KayokoTag *updatedTag = [[KayokoTag alloc] initWithUUID:[[self tag] uuid]
                                                      title:title
                                                   hexColor:KayokoTagEditorHexColorFromColor([[self colorWell]
                                                                                                 selectedColor])];
    if ([self completionHandler]) {
        [self completionHandler](updatedTag);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)localizedStringForKey:(NSString *)key {
    return [[self localizationBundle] localizedStringForKey:key value:key table:@"Tags"] ?: key;
}

@end
