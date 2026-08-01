//
//  KayokoNotificationKeys.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

static NSString *const kKayokoNotificationKeyCoreShow = @"com.zqbb.kayoko.core.show";
static NSString *const kKayokoLegacyNotificationKeyCoreShow = @"dev.traurige.kayoko.core.show";
static NSString *const kKayokoNotificationKeyCoreHide = @"com.zqbb.kayoko.core.hide";
static NSString *const kKayokoLegacyNotificationKeyCoreHide = @"dev.traurige.kayoko.core.hide";
static NSString *const kKayokoNotificationKeyCoreReload = @"com.zqbb.kayoko.core.reload";
static NSString *const kKayokoNotificationKeyFavoritesEditorRequest = @"com.zqbb.kayoko.favorites-editor.request";
static NSString *const kKayokoNotificationKeyFavoritesEditorResponse = @"com.zqbb.kayoko.favorites-editor.response";
static NSString *const kKayokoFavoritesEditorRequestPath = @"/var/mobile/Library/com.zqbb.kayoko/favorites-editor-request.plist";
static NSString *const kKayokoFavoritesEditorResponsePath = @"/var/mobile/Library/com.zqbb.kayoko/favorites-editor-response.plist";
static NSString *const kKayokoNotificationKeyCoreCheckpointHistory = @"com.zqbb.kayoko.core.checkpoint-history";
static NSString *const kKayokoNotificationKeyCorePrepareMaintenance = @"com.zqbb.kayoko.core.prepare-maintenance";
static NSString *const kKayokoNotificationKeyCoreResetThumbnailMemoryCache =
    @"com.zqbb.kayoko.core.reset-thumbnail-memory-cache";
static NSString *const kKayokoNotificationKeyCoreClearFavorites = @"com.zqbb.kayoko.core.clear-favorites";
static NSString *const kKayokoNotificationKeyCoreClearHistory = @"com.zqbb.kayoko.core.clear-history";
static NSString *const kKayokoNotificationKeyCoreAddRandomImageItems =
    @"com.zqbb.kayoko.core.add-random-image-items";
static NSString *const kKayokoNotificationKeyCoreImportLegacyFavorites =
    @"com.zqbb.kayoko.core.import-legacy-favorites";
static NSString *const kKayokoNotificationKeyCopyVaultHistoryShow = @"com.squidforce.copyvault/history/show";
static NSString *const kKayokoNotificationKeyCopyVaultFavouriteShow = @"com.squidforce.copyvault/favourite/show";
static NSString *const kKayokoNotificationKeyHelperPaste = @"com.zqbb.kayoko.helper.paste";
static NSString *const kKayokoNotificationKeyHelperRestoreFocus = @"com.zqbb.kayoko.helper.restore-focus";
static NSString *const kKayokoNotificationKeyPreferencesReload = @"com.zqbb.kayoko.preferences.reload";
static NSString *const kKayokoNotificationKeyPreferencesHeightReload = @"com.zqbb.kayoko.preferences.height.reload";
static NSString *const kKayokoNotificationKeyExternalImportRequiresRestart =
    @"com.zqbb.kayoko.preferences.external-import-requires-restart";
static NSString *const kKayokoNotificationUserInfoKeyExternalImportSucceeded = @"succeeded";
static NSString *const kKayokoNotificationUserInfoKeyExternalImportSource = @"source";
static NSString *const kKayokoExternalImportSourceCopyLog = @"CopyLog";
static NSString *const kKayokoExternalImportSourceCopyVault = @"CopyVault";
static NSString *const kKayokoNotificationKeyPasteWillStart = @"com.zqbb.kayoko.paste.willstart";
static NSString *const kKayokoNotificationKeyPasteFeedback = @"com.zqbb.kayoko.paste.feedback";
