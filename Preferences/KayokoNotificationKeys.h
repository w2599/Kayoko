//
//  KayokoNotificationKeys.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

static NSString *const kKayokoNotificationKeyCoreShow = @"com.82flex.kayoko.core.show";
static NSString *const kKayokoLegacyNotificationKeyCoreShow = @"dev.traurige.kayoko.core.show";
static NSString *const kKayokoNotificationKeyCoreHide = @"com.82flex.kayoko.core.hide";
static NSString *const kKayokoLegacyNotificationKeyCoreHide = @"dev.traurige.kayoko.core.hide";
static NSString *const kKayokoNotificationKeyCoreReload = @"com.82flex.kayoko.core.reload";
static NSString *const kKayokoNotificationKeyFavoritesEditorRequest = @"com.82flex.kayoko.favorites-editor.request";
static NSString *const kKayokoNotificationKeyFavoritesEditorResponse = @"com.82flex.kayoko.favorites-editor.response";
static NSString *const kKayokoFavoritesEditorRequestPath = @"/var/mobile/Library/com.82flex.kayoko/favorites-editor-request.plist";
static NSString *const kKayokoFavoritesEditorResponsePath = @"/var/mobile/Library/com.82flex.kayoko/favorites-editor-response.plist";
static NSString *const kKayokoNotificationKeyCoreCheckpointHistory = @"com.82flex.kayoko.core.checkpoint-history";
static NSString *const kKayokoNotificationKeyCorePrepareMaintenance = @"com.82flex.kayoko.core.prepare-maintenance";
static NSString *const kKayokoNotificationKeyCoreResetThumbnailMemoryCache =
    @"com.82flex.kayoko.core.reset-thumbnail-memory-cache";
static NSString *const kKayokoNotificationKeyCoreClearFavorites = @"com.82flex.kayoko.core.clear-favorites";
static NSString *const kKayokoNotificationKeyCoreClearHistory = @"com.82flex.kayoko.core.clear-history";
static NSString *const kKayokoNotificationKeyCoreAddRandomImageItems =
    @"com.82flex.kayoko.core.add-random-image-items";
static NSString *const kKayokoNotificationKeyCoreImportLegacyFavorites =
    @"com.82flex.kayoko.core.import-legacy-favorites";
static NSString *const kKayokoNotificationKeyCopyVaultHistoryShow = @"com.squidforce.copyvault/history/show";
static NSString *const kKayokoNotificationKeyCopyVaultFavouriteShow = @"com.squidforce.copyvault/favourite/show";
static NSString *const kKayokoNotificationKeyHelperPaste = @"com.82flex.kayoko.helper.paste";
static NSString *const kKayokoNotificationKeyHelperRestoreFocus = @"com.82flex.kayoko.helper.restore-focus";
static NSString *const kKayokoNotificationKeyPreferencesReload = @"com.82flex.kayoko.preferences.reload";
static NSString *const kKayokoNotificationKeyPreferencesHeightReload = @"com.82flex.kayoko.preferences.height.reload";
static NSString *const kKayokoNotificationKeyExternalImportRequiresRestart =
    @"com.82flex.kayoko.preferences.external-import-requires-restart";
static NSString *const kKayokoNotificationUserInfoKeyExternalImportSucceeded = @"succeeded";
static NSString *const kKayokoNotificationUserInfoKeyExternalImportSource = @"source";
static NSString *const kKayokoExternalImportSourceCopyLog = @"CopyLog";
static NSString *const kKayokoExternalImportSourceCopyVault = @"CopyVault";
static NSString *const kKayokoNotificationKeyPasteWillStart = @"com.82flex.kayoko.paste.willstart";
static NSString *const kKayokoNotificationKeyPasteFeedback = @"com.82flex.kayoko.paste.feedback";
