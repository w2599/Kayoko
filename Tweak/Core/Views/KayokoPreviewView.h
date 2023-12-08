//
//  KayokoPreviewVie.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface KayokoPreviewView : UIView <WKNavigationDelegate>
@property(nonatomic, retain)UITextView* textView;
@property(nonatomic, retain)UIImageView* imageView;
@property(nonatomic, retain)WKWebView* webView;
- (void)reset;
@end
