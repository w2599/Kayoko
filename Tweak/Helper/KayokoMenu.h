//
//  KayokoMenu.h
//  Kayoko
//
//  Created by 82Flex on 2025/3/15.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *KayokoAppleMenuIdentifier(void);

FOUNDATION_EXTERN UIMenuItem *KayokoMenuItem(void);
FOUNDATION_EXTERN UICommand *KayokoMenuItemUICommand(void);

FOUNDATION_EXTERN BOOL KayokoMenuItemIsWritingTool(id input);

NS_ASSUME_NONNULL_END
