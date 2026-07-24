// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class LZh extends L {
  LZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'R-Shop';

  @override
  String get settings_language => '語言';

  @override
  String get settings_languageSystem => '系統預設';

  @override
  String get common_back => '返回';

  @override
  String get common_close => '關閉';

  @override
  String get common_cancel => '取消';

  @override
  String get common_cancelUpper => '取消';

  @override
  String get common_select => '選擇';

  @override
  String get common_search => '搜尋';

  @override
  String get common_searchEllipsis => '搜尋...';

  @override
  String get common_menu => '選單';

  @override
  String get common_navigate => '導航';

  @override
  String get common_toggle => '切換';

  @override
  String get common_clear => '清除';

  @override
  String get common_done => '完成';

  @override
  String get common_save => '儲存';

  @override
  String get common_connect => '連線';

  @override
  String get common_retry => '重試';

  @override
  String get common_remove => '移除';

  @override
  String get common_favorite => '收藏';

  @override
  String get common_unfavorite => '取消收藏';

  @override
  String get common_downloads => '下載項目';

  @override
  String get common_installed => '已安裝';

  @override
  String get common_move => '移動';

  @override
  String get common_drop => '放下';

  @override
  String get common_grab => '抓取';

  @override
  String get confirm_deleteTitle => '刪除 ROM？';

  @override
  String confirm_deleteMessage(String gameTitle) {
    return '您真的要刪除 $gameTitle 的這個版本嗎？';
  }

  @override
  String get confirm_exitTitle => '結束應用程式？';

  @override
  String get confirm_exitMessage => '您真的要結束 Retro eShop 嗎？';

  @override
  String get confirm_resetTitle => '重設應用程式？';

  @override
  String get confirm_resetMessage => '這將返回初始設定畫面。';

  @override
  String get confirm_deleteButton => '刪除';

  @override
  String get confirm_exitButton => '結束';

  @override
  String get confirm_resetButton => '重設';

  @override
  String get confirm_gamepadHint => '← → 選擇   A 確認   B 取消';

  @override
  String get exit_title => '結束應用程式';

  @override
  String get exit_message => '確定要退出嗎？';

  @override
  String get exit_confirmButton => '結束';

  @override
  String get exit_cancelButton => '留在這裡';

  @override
  String get downloads_title => '下載項目';

  @override
  String downloads_activeCount(int count) {
    return '$count 個進行中';
  }

  @override
  String get downloads_noDownloads => '無下載項目';

  @override
  String get downloads_sectionDownloading => '正在下載';

  @override
  String get downloads_sectionQueued => '等待中';

  @override
  String get downloads_sectionComplete => '已完成';

  @override
  String get downloads_actionCancel => '取消';

  @override
  String get downloads_actionRetry => '重試';

  @override
  String get downloads_actionRemove => '移除';

  @override
  String get downloads_actionClear => '清除';

  @override
  String get downloads_clearDone => '清除已完成項目';

  @override
  String get downloadStatus_downloading => '正在下載...';

  @override
  String get downloadStatus_extracting => '正在解壓縮...';

  @override
  String get downloadStatus_installing => '正在安裝...';

  @override
  String get downloadStatus_waiting => '等待中...';

  @override
  String get downloadStatus_complete => '已完成';

  @override
  String get downloadStatus_cancelled => '已取消';

  @override
  String get downloadStatus_failed => '失敗';

  @override
  String storage_free(String size) {
    return '剩餘 $size';
  }

  @override
  String storage_veryLow(String freeSpace) {
    return '儲存空間極低：$freeSpace';
  }

  @override
  String storage_gettingLow(String freeSpace) {
    return '儲存空間不足：$freeSpace';
  }

  @override
  String sync_progress(int completed, int total) {
    return '同步中 $completed/$total';
  }

  @override
  String sync_singleSystemFailed(String system) {
    return '$system 同步失敗';
  }

  @override
  String sync_multipleSystemsFailed(int count) {
    return '$count 個系統同步失敗';
  }

  @override
  String sync_raProgress(int completed, int total) {
    return '成就同步中 $completed/$total';
  }

  @override
  String get sync_raFailed => 'RA 同步失敗';

  @override
  String get toast_addedToQueue => '已加入下載佇列';

  @override
  String get toast_configRecovered => '已從備份復原設定';

  @override
  String gameCard_variantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個變體',
      one: '1 個變體',
    );
    return '$_temp0';
  }

  @override
  String get gameDetail_achievements => '成就';

  @override
  String get gameDetail_mastered => '已達成';

  @override
  String get gameDetail_noAchievementsFound => '找不到成就';

  @override
  String get gameDetail_retroachievements => 'RETROACHIEVEMENTS';

  @override
  String get gameDetail_romVerified => 'ROM 已驗證';

  @override
  String get gameDetail_incompatibleRom => '不相容的 ROM';

  @override
  String get gameDetail_gameHasAchievements => '此遊戲支援成就';

  @override
  String get gameDetail_viewAchievements => '查看成就';

  @override
  String get gameDetail_versions => '版本';

  @override
  String get gameDetail_download => '下載';

  @override
  String get gameDetail_adding => '正在加入...';

  @override
  String get gameDetail_queued => '等待中';

  @override
  String get gameDetail_extracting => '正在解壓縮...';

  @override
  String get gameDetail_delete => '刪除';

  @override
  String get gameDetail_manageFiles => '檔案管理';

  @override
  String get gameDetail_unavailable => '不可用';

  @override
  String get gameDetail_installedLabel => '已安裝';

  @override
  String get gameDetail_notFound => '找不到';

  @override
  String get gameDetail_details => '詳情';

  @override
  String get gameDetail_screenshots => '螢幕截圖';

  @override
  String get gameDetail_otherVersions => '其他版本';

  @override
  String get gameDetail_readMore => '閱讀更多...';

  @override
  String get gameDetail_showLess => '收起內容';

  @override
  String get gameDetail_standard => '標準';

  @override
  String get gameDetail_franchise => '系列';

  @override
  String get gameDetail_gameModes => '遊戲模式';

  @override
  String get gameDetail_perspective => '視角';

  @override
  String get gameDetail_ageRating => '分級';

  @override
  String get gameDetail_themes => '主題';

  @override
  String get gameDetail_fileTags => '檔案標籤';

  @override
  String get gameDetail_tagVersion => '版本';

  @override
  String get gameDetail_tagBuild => '組建';

  @override
  String get gameDetail_tagDisc => '光碟';

  @override
  String get gameDetail_tagQuality => '品質';

  @override
  String get gameDetail_tagInfo => '資訊';

  @override
  String get gameDetail_tagTechnical => '技術資訊';

  @override
  String get gameDetail_gameInfo => '遊戲資訊';

  @override
  String get gameDetail_showTitle => '顯示標題';

  @override
  String get gameDetail_showFilename => '顯示檔案名稱';

  @override
  String gameDetail_fromProvider(String provider) {
    return '來自 $provider';
  }

  @override
  String get gameDetail_addToShelf => '加入收藏架';

  @override
  String get gameDetail_removeFromShelf => '從收藏架移除';

  @override
  String get gameDetail_removeFromShelfTitle => '從收藏架移除';

  @override
  String get gameDetail_gameNotInstalled => '遊戲尚未安裝';

  @override
  String get gameDetail_couldNotShare => '無法分享遊戲檔案';

  @override
  String get gameDetail_pressAPickVersion => '按 A 選擇版本';

  @override
  String get gameDetail_pressAManage => '按 A 進行管理';

  @override
  String get gameDetail_pressADownload => '按 A 下載';

  @override
  String gameDetail_errorPrefix(String error) {
    return '錯誤：$error';
  }

  @override
  String get settings_title => '設定';

  @override
  String get settings_tabGeneral => '一般';

  @override
  String get settings_tabAudio => '音效';

  @override
  String get settings_tabAdvanced => '進階';

  @override
  String get settings_tabAbout => '關於';

  @override
  String get settings_previousTab => '上一個分頁';

  @override
  String get settings_nextTab => '下一個分頁';

  @override
  String get settings_resetApp => '重設應用程式';

  @override
  String get settings_resetDialogTitle => '重設應用程式';

  @override
  String get settings_resetDialogMessage => '這將刪除所有設定並重新開始設定流程。';

  @override
  String get settings_resetDialogConfirm => '重設';

  @override
  String get settings_resetDialogCancel => '取消';

  @override
  String get settings_sectionLibrary => '媒體庫';

  @override
  String get settings_sectionDisplay => '顯示';

  @override
  String get settings_mySources => '我的來源';

  @override
  String get settings_mySourcesSubtitle => '新增或管理 RomM, SMB, FTP 伺服器';

  @override
  String get settings_consoleSettings => '主機設定';

  @override
  String get settings_consoleSettingsSubtitle => '資料夾路徑、解壓縮、各系統選項';

  @override
  String get settings_retroAchievements => 'RetroAchievements';

  @override
  String get settings_retroAchievementsSubtitle => '成就追蹤與 ROM 驗證';

  @override
  String get settings_homeLayout => '主畫面佈局';

  @override
  String get settings_homeLayoutGrid => '網格檢視';

  @override
  String get settings_homeLayoutCarousel => '橫向輪播';

  @override
  String get settings_hideEmptyConsoles => '隱藏空的主機';

  @override
  String get settings_hideEmptyConsolesSubtitle => '僅顯示含有遊戲的系統';

  @override
  String get settings_controllerButtons => '控制器按鈕';

  @override
  String get settings_controllerNintendo => 'Nintendo (預設)';

  @override
  String get settings_controllerXbox => 'XBOX';

  @override
  String get settings_controllerPs => 'PS';

  @override
  String get settings_controllerNin => 'NIN';

  @override
  String get settings_sectionFeedback => '回饋';

  @override
  String get settings_vibration => '震動';

  @override
  String get settings_vibrationSubtitle => '按鈕按下時震動';

  @override
  String get settings_soundEffects => '音效';

  @override
  String get settings_soundEffectsSubtitle => '選單操作時播放音效';

  @override
  String get settings_sectionVolume => '音量';

  @override
  String get settings_music => '音樂';

  @override
  String get settings_musicSubtitle => '環境背景音樂';

  @override
  String get settings_effects => '音效';

  @override
  String get settings_effectsSubtitle => '介面音效';

  @override
  String get settings_sectionDownloads => '下載';

  @override
  String get settings_simultaneousDownloads => '同時下載數';

  @override
  String get settings_simultaneousDownloadsSubtitle => '可同時下載的檔案數量';

  @override
  String get settings_downloadAllCovers => '下載所有封面';

  @override
  String get settings_downloadingCovers => '正在下載封面...';

  @override
  String get settings_sectionSync => '同步';

  @override
  String get settings_syncTimeout => '同步逾時';

  @override
  String get settings_syncTimeoutSubtitle => '等待每個伺服器的最長時間';

  @override
  String get settings_autoSyncInterval => '自動同步間隔';

  @override
  String get settings_autoSyncIntervalSubtitle => '自動同步之間的最小間隔時間';

  @override
  String get settings_sectionDebug => '除錯';

  @override
  String get settings_allowInsecure => '允許不安全連線';

  @override
  String get settings_allowInsecureSubtitle => '為不支援 HTTPS 的伺服器啟用 HTTP';

  @override
  String get settings_exportErrorLog => '匯出錯誤日誌';

  @override
  String get settings_exportErrorLogSubtitle => '分享當機日誌以供排錯';

  @override
  String get settings_sectionInfo => '資訊';

  @override
  String get settings_sectionLinks => '連結';

  @override
  String get settings_github => 'GitHub';

  @override
  String get settings_githubSubtitle => '在 GitHub 上查看原始碼';

  @override
  String get settings_issues => '問題回報';

  @override
  String get settings_issuesSubtitle => '回報 Bug 或要求新功能';

  @override
  String get settings_tagline => 'INTENSIV, AGGRESSIV, MUTIG';

  @override
  String get settings_deviceMemoryLow => '低';

  @override
  String get settings_deviceMemoryStandard => '標準';

  @override
  String get settings_deviceMemoryHigh => '高';

  @override
  String get settings_fetchingCovers => '正在擷取封面...';

  @override
  String settings_coversResult(int ok, int failed) {
    return '封面：$ok 成功, $failed 失敗';
  }

  @override
  String settings_coversLoaded(int count) {
    return '已載入 $count 張封面！';
  }

  @override
  String get settings_noErrorLog => '無可用錯誤日誌';

  @override
  String get settings_configImported => '設定已匯入！';

  @override
  String get settings_controllerXboxFull => 'Xbox (A/B 與 X/Y 反轉)';

  @override
  String get settings_controllerPlaystationFull => 'PlayStation (✕ ○ □ △)';

  @override
  String get settings_allCoversCached => '所有封面皆已快取';

  @override
  String get settings_downloadCoverArt => '下載所有遊戲的封面圖';

  @override
  String settings_coverCacheInfo(String size, int count) {
    return '$size ($count 個已快取)';
  }

  @override
  String settings_coversRemaining(int count, String size) {
    return '剩餘 $count 個 (~$size MB)';
  }

  @override
  String settings_coversProgress(int completed, int total) {
    return '$completed / $total 款遊戲';
  }

  @override
  String get configMode_title => '主機設定';

  @override
  String get configMode_globalTitle => '全域設定';

  @override
  String get configMode_noFolderSet => '尚未設定資料夾';

  @override
  String get configMode_notConfigured => '未配置';

  @override
  String get configMode_export => '匯出';

  @override
  String get configMode_import => '匯入';

  @override
  String get systemDetail_sectionStorage => '儲存空間';

  @override
  String get systemDetail_selectRomFolder => '選擇 ROM 資料夾';

  @override
  String get systemDetail_tapToChangeFolder => '點擊以變更資料夾';

  @override
  String get systemDetail_sectionBehavior => '行為';

  @override
  String get systemDetail_autoExtractZips => '自動解壓縮 ZIP';

  @override
  String get systemDetail_autoExtractEnabled => '下載後自動解壓縮 ZIP 格式的 ROM';

  @override
  String get systemDetail_autoExtractDisabled => '下載後保持 ZIP 格式';

  @override
  String get systemDetail_autoSyncOnLaunch => '啟動時自動同步';

  @override
  String get systemDetail_autoSyncEnabled => '自動同步（遵循冷卻時間）';

  @override
  String get systemDetail_autoSyncDisabled => '僅透過 Start 選單手動同步';

  @override
  String get systemDetail_sectionSources => '來源';

  @override
  String get sources_title => '來源';

  @override
  String get sources_noSourcesConfigured => '尚未配置來源';

  @override
  String get sources_noSourcesYet => '目前無來源';

  @override
  String get sources_noSourcesDescription => '配對 RomM 伺服器以開始下載遊戲。';

  @override
  String get sources_addSource => '新增來源';

  @override
  String get sources_whereDoGamesComeFrom => '您的遊戲來自哪裡？';

  @override
  String get sources_sourceTypeRomm => 'RomM 伺服器';

  @override
  String get sources_sourceTypeRommHint => '透過 QR 或 8 位代碼配對';

  @override
  String get sources_sourceTypeRommLegacy => 'RomM 登入（舊版伺服器）';

  @override
  String get sources_sourceTypeSmb => 'SMB 分享';

  @override
  String get sources_sourceTypeFtp => 'FTP 伺服器';

  @override
  String get sources_sourceTypeWeb => 'Web 鏡像';

  @override
  String get sources_sourceTypeWebHint => 'HTTPS 目錄列表';

  @override
  String get sources_expired => '已過期';

  @override
  String get sources_borrowed => '已借用';

  @override
  String get sources_off => '關閉';

  @override
  String get sources_noPlatforms => '無平台';

  @override
  String get sources_rePair => '重新配對';

  @override
  String get sources_editMappings => '編輯對應';

  @override
  String get sources_disable => '停用';

  @override
  String get sources_enable => '啟用';

  @override
  String get manualSource_defaultNameSmb => '我的 NAS';

  @override
  String get manualSource_defaultNameFtp => '我的 FTP';

  @override
  String get manualSource_defaultNameWeb => 'Web 鏡像';

  @override
  String get manualSource_defaultNameOther => '來源';

  @override
  String get manualSource_name => '名稱';

  @override
  String get manualSource_url => 'URL';

  @override
  String get manualSource_urlHint => 'https://example.com/roms';

  @override
  String get manualSource_host => '主機';

  @override
  String get manualSource_hostHint => 'nas.local 或 192.168.1.10';

  @override
  String get manualSource_port => '連接埠';

  @override
  String get manualSource_share => '分享名稱';

  @override
  String get manualSource_shareHint => 'roms';

  @override
  String get manualSource_usernameOptional => '使用者名稱 (選填)';

  @override
  String get manualSource_usernameHint => '訪客請保持空白';

  @override
  String get manualSource_passwordOptional => '密碼 (選填)';

  @override
  String get manualSource_nameRequired => '名稱為必填';

  @override
  String get manualSource_urlRequired => 'URL 為必填';

  @override
  String get manualSource_hostRequired => '主機為必填';

  @override
  String get manualSource_shareRequired => '分享名稱為必填';

  @override
  String get manualSource_saveSource => '儲存來源';

  @override
  String get manualSource_smb => 'SMB';

  @override
  String get manualSource_ftp => 'FTP';

  @override
  String get manualSource_web => 'Web';

  @override
  String get manualSource_searchingNetwork => '正在搜尋網路...';

  @override
  String get manualSource_foundOnNetwork => '在您的網路中找到';

  @override
  String get sourceMappings_title => '系統對應';

  @override
  String get sourceMappings_instruction => '輸入每個系統對應的遠端資料夾。留空則跳過。';

  @override
  String get sourceMappings_save => '儲存對應';

  @override
  String get library_title => '媒體庫';

  @override
  String get library_tabAll => '全部';

  @override
  String get library_tabInstalled => '已安裝';

  @override
  String get library_tabFavorites => '我的收藏';

  @override
  String get library_sortSystem => '按系統排序';

  @override
  String get library_sortManual => '手動排序';

  @override
  String get library_sortAZ => '按 A-Z 排序';

  @override
  String get library_sortIndicatorAZ => 'A-Z';

  @override
  String get library_sortIndicatorBySystem => '按系統';

  @override
  String get library_sortIndicatorManual => '手動';

  @override
  String get library_searchHint => '搜尋媒體庫...';

  @override
  String get library_zoomIn => '放大';

  @override
  String get library_zoomOut => '縮小';

  @override
  String get library_newShelf => '新增收藏架';

  @override
  String get library_editShelf => '編輯收藏架';

  @override
  String get library_addToShelf => '加入收藏架';

  @override
  String get library_removeFromShelf => '從收藏架移除';

  @override
  String get library_reorderGames => '重新排列遊戲';

  @override
  String library_noResults(String query) {
    return '找不到與「$query」相關的結果';
  }

  @override
  String get library_tryShorterSearch => '請嘗試更短的搜尋詞';

  @override
  String get library_noInstalledGames => '目前無已安裝的遊戲';

  @override
  String get library_downloadGamesToSee => '下載遊戲後會顯示在這裡';

  @override
  String get library_noFavoritesYet => '尚未收藏任何遊戲';

  @override
  String get library_pressFavoriteHint => '對著遊戲按 SELECT 即可加入收藏';

  @override
  String get library_noGamesInShelf => '此收藏架內無遊戲';

  @override
  String get library_addGamesViaEditor => '透過收藏架編輯器新增遊戲';

  @override
  String get library_noGamesInLibrary => '媒體庫中無遊戲';

  @override
  String get library_gamesAfterSync => '同步完成後遊戲將會出現';

  @override
  String get shelfEdit_title => '編輯收藏架';

  @override
  String get shelfEdit_titleNew => '新增收藏架';

  @override
  String get shelfEdit_nameSection => '名稱';

  @override
  String get shelfEdit_shelfName => '收藏架名稱';

  @override
  String get shelfEdit_filterText => '過濾文字';

  @override
  String get shelfEdit_tapToSet => '點擊以設定...';

  @override
  String get shelfEdit_filterRules => '過濾規則';

  @override
  String get shelfEdit_resetManualOrder => '重設手動排序';

  @override
  String get shelfEdit_saveButton => '儲存';

  @override
  String get shelfEdit_deleteShelf => '刪除收藏架';

  @override
  String get shelfEdit_anyText => '任何文字';

  @override
  String get shelfEdit_allSystems => '所有系統';

  @override
  String get shelfPicker_title => '加入收藏架';

  @override
  String get systemSelector_title => '選擇系統';

  @override
  String get textInput_hint => '輸入文字...';

  @override
  String get textInput_ok => '確定';

  @override
  String get gameListOverlay_hiddenGames => '隱藏的遊戲';

  @override
  String get gameListOverlay_addedGames => '已新增的遊戲';

  @override
  String get gameListOverlay_restore => '還原';

  @override
  String get gameListOverlay_noGames => '無遊戲';

  @override
  String get gameListOverlay_clearAll => '全部清除';

  @override
  String get home_allGames => '所有遊戲';

  @override
  String get home_library => '媒體庫';

  @override
  String get home_noConsoles => '尚未配置主機';

  @override
  String get home_pressStartForMenu => '按 Start 開啟選單';

  @override
  String get home_settings => '設定';

  @override
  String home_syncSystem(String system) {
    return '同步 $system';
  }

  @override
  String get home_syncAll => '同步全部';

  @override
  String get home_lastSyncNever => '從未同步';

  @override
  String get home_lastSyncJustNow => '剛剛同步';

  @override
  String home_lastSyncMinutes(int minutes) {
    return '$minutes 分鐘前同步';
  }

  @override
  String home_lastSyncHours(int hours) {
    return '$hours 小時前同步';
  }

  @override
  String home_lastSyncDays(int days) {
    return '$days 天前同步';
  }

  @override
  String get common_exit => '結束';

  @override
  String gameList_gamesCount(int count) {
    return '$count 款遊戲';
  }

  @override
  String get gameList_offline => '離線';

  @override
  String get gameList_zoomIn => '放大';

  @override
  String get gameList_zoomOut => '縮小';

  @override
  String get gameList_filterActive => '過濾器 (啟用中)';

  @override
  String get gameList_filter => '過濾器';

  @override
  String gameList_noGamesMatchSearch(String query) {
    return '找不到符合「$query」的遊戲';
  }

  @override
  String get gameList_tryShorterSearch => '請嘗試更短的搜尋詞';

  @override
  String get gameList_noGamesMatchFilters => '沒有符合當前過濾條件的遊戲';

  @override
  String get gameList_changeFilters => '請在選單中更改或重設過濾器';

  @override
  String gameList_noRomsFound(String folder) {
    return '在 $folder 中找不到 ROM';
  }

  @override
  String get gameList_addRomFiles => '請將 ROM 檔案加入此資料夾並重新整理';

  @override
  String get gameList_couldNotLoadGames => '無法載入遊戲';

  @override
  String get gameList_checkConnection => '請檢查您的連線並再試一次';

  @override
  String get gameList_errorLoadingGames => '載入遊戲時發生錯誤';

  @override
  String get gameList_gamesAppearShortly => '遊戲很快就會出現';

  @override
  String get gameList_syncingLibrary => '正在同步媒體庫...';

  @override
  String get gameList_localFilesOnly => '僅限本地檔案 · 新增來源以獲得更多';

  @override
  String get gameList_pressMenuHint => '按 + 開啟選單';

  @override
  String filter_activeCount(int count) {
    return '$count 個已啟用';
  }

  @override
  String get shelfEdit_addFilter => '+ 新增過濾器';

  @override
  String shelfEdit_hiddenGamesCount(int count) {
    return '隱藏的遊戲 ($count)';
  }

  @override
  String shelfEdit_addedGamesCount(int count) {
    return '已新增的遊戲 ($count)';
  }

  @override
  String get shelfEdit_textHint => '← 文字  系統 →';

  @override
  String gameListOverlay_gameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 款遊戲',
      one: '1 款遊戲',
    );
    return '$_temp0';
  }

  @override
  String gameListOverlay_actionHint(String action) {
    return 'A: $action';
  }

  @override
  String systemSelector_selectedCount(int count) {
    return '已選擇 $count 個';
  }

  @override
  String get filter_favoritesOnly => '僅收藏項目';

  @override
  String get filter_installedOnly => '僅已安裝項目';

  @override
  String get filter_regions => '地區';

  @override
  String get filter_languages => '語言';

  @override
  String get filter_title => '過濾器';

  @override
  String get onboarding_welcomeTitle => '歡迎使用 R-Shop';

  @override
  String get onboarding_welcomeSubtitle => '您的遊戲來自哪裡？';

  @override
  String get onboarding_pairQrTitle => '透過 QR 配對 RomM';

  @override
  String get onboarding_pairQrSubtitle => '掃描 RomM 伺服器提供的 QR Code';

  @override
  String get onboarding_legacyLoginTitle => 'RomM 登入（舊版伺服器）';

  @override
  String get onboarding_legacyLoginSubtitle => 'RomM < 4.8 版的使用者名稱與密碼';

  @override
  String get onboarding_addServerTitle => '新增我自己的伺服器';

  @override
  String get onboarding_addServerSubtitle => 'SMB, FTP 或 Web 鏡像 — 手動對應系統';

  @override
  String get onboarding_localOnlyTitle => '僅限本地遊戲';

  @override
  String get onboarding_localOnlySubtitle => '已在此設備上的 ROM';

  @override
  String get onboarding_working => '運作中...';

  @override
  String get onboarding_scanningFolders => '正在掃描本地 ROM 資料夾...';

  @override
  String get onboarding_discoveringPlatforms => '正在搜尋平台...';

  @override
  String get onboarding_savingSource => '正在儲存來源...';

  @override
  String get onboarding_allSet => '一切就緒';

  @override
  String get onboarding_noSystems => '尚未配置系統 — 您稍後可以從「設定」新增來源。';

  @override
  String onboarding_systemsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個系統已可瀏覽',
      one: '1 個系統已可瀏覽',
    );
    return '$_temp0';
  }

  @override
  String get onboarding_jumpIn => '開始使用';

  @override
  String get onboarding_jumpInSubtitle => '開啟主畫面並開始同步';

  @override
  String get onboarding_retroachievements => 'RetroAchievements';

  @override
  String get onboarding_retroachievementsSubtitle => '追蹤您的復古遊戲成就';

  @override
  String get onboarding_exportConfig => '匯出設定';

  @override
  String get onboarding_exportConfigSubtitle => '在另一台設備上重複使用此設定';

  @override
  String get onboarding_importConfig => '匯入設定';

  @override
  String get onboarding_configImported => '設定已匯入！';

  @override
  String onboarding_exportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String onboarding_invalidConfig(String error) {
    return '無效設定：$error';
  }

  @override
  String onboarding_failedToSave(String error) {
    return '儲存失敗：$error';
  }

  @override
  String get onboarding_selectFolderPrompt => '選擇儲存 ROM 的資料夾';

  @override
  String get onboarding_serverType => '伺服器類型';

  @override
  String get onboarding_hangOn => '請稍候，正在測試連線...';

  @override
  String get onboarding_foundConsole => '我在您的 RomM 伺服器上找到了這個主機！請確認或選擇另一個。';

  @override
  String get onboarding_pickPlatform => '從您的 RomM 伺服器選擇對應的平台。';

  @override
  String get onboarding_couldNotReach => '無法連線至您的 RomM 伺服器。請檢查 URL 並再試一次。';

  @override
  String get onboarding_connectionGood => '連線狀況良好！您可以儲存此來源了。';

  @override
  String get onboarding_couldNotConnect => '嗯... 無法連線。請再次確認網址與憑據。';

  @override
  String get onboarding_whatKindOfSource => '這是哪種類型的來源？請選擇連線類型。';

  @override
  String get onboarding_lookingGood => '看起來不錯！您可以新增更多來源，或者在就緒後按「完成」。';

  @override
  String get onboarding_localCollection => '這是本地收藏。您可以新增來源來下載更多遊戲，或直接按「完成」！';

  @override
  String get onboarding_addMoreSources => '現在請至少新增一個來源，好讓我知道去哪裡找 ROM。';

  @override
  String get onboarding_letsSetUp => '讓我們來設定您的主機！選擇任一系統即可開始。';

  @override
  String get onboarding_romFolder => 'ROM 資料夾';

  @override
  String get onboarding_options => '選項';

  @override
  String get onboarding_autoExtractZips => '自動解壓縮 ZIP 格式 ROM';

  @override
  String get onboarding_autoSyncLabel => '啟動時自動同步';

  @override
  String get onboarding_autoSyncEnabled => '自動同步（遵循冷卻時間）';

  @override
  String get onboarding_autoSyncDisabled => '僅透過 Start 選單手動同步';

  @override
  String get onboarding_selectFolder => '選擇資料夾...';

  @override
  String get providerForm_addSource => '新增來源';

  @override
  String get providerForm_editSource => '編輯來源';

  @override
  String get providerForm_url => 'URL';

  @override
  String get providerForm_urlPlaceholder => 'https://...';

  @override
  String get providerForm_path => '路徑';

  @override
  String get providerForm_pathPlaceholder => '/roms/nes/ (選填)';

  @override
  String get providerForm_username => '使用者名稱';

  @override
  String get providerForm_usernameOptional => '(選填)';

  @override
  String get providerForm_password => '密碼';

  @override
  String get providerForm_host => '主機';

  @override
  String get providerForm_hostPlaceholder => '192.168.1.100';

  @override
  String get providerForm_port => '連接埠';

  @override
  String get providerForm_share => '分享名稱';

  @override
  String get providerForm_sharePlaceholder => 'roms';

  @override
  String get providerForm_domain => '網域';

  @override
  String get providerForm_domainOptional => '(選填)';

  @override
  String get providerForm_rommUrl => 'URL';

  @override
  String get providerForm_rommUrlPlaceholder => 'https://romm.example.com';

  @override
  String get providerForm_apiKey => 'API Key';

  @override
  String get providerForm_apiKeyOptional => '(選填)';

  @override
  String get providerForm_httpBlocked =>
      '非本地伺服器的 HTTP 已被封鎖。請使用 HTTPS，或稍後在「設定」中啟用。';

  @override
  String get providerForm_httpWarning => '憑據將透過未加密的 HTTP 傳送';

  @override
  String get providerForm_testingConnection => '正在測試連線...';

  @override
  String get providerForm_connectionSuccessful => '連線成功！';

  @override
  String get providerForm_fetchingPlatforms => '正在擷取平台...';

  @override
  String get providerForm_noPlatformsFound => '在此 RomM 伺服器上找不到任何平台。';

  @override
  String get providerForm_platform => '平台';

  @override
  String get providerForm_pickPlatform => '選擇平台...';

  @override
  String get providerForm_testAndSave => '測試並儲存';

  @override
  String get providerForm_connectionFailed => '連線失敗';

  @override
  String get providerForm_hostMissing => '主機';

  @override
  String get providerForm_portMissing => '連接埠';

  @override
  String get providerForm_pathMissing => '路徑';

  @override
  String get providerForm_shareMissing => '分享名稱';

  @override
  String get providerForm_urlMissing => 'URL';

  @override
  String get rommLogin_title => '登入 RomM';

  @override
  String get rommLogin_name => '名稱';

  @override
  String get rommLogin_nameDefault => '我的 RomM';

  @override
  String get rommLogin_serverUrl => '伺服器 URL';

  @override
  String get rommLogin_username => '使用者名稱';

  @override
  String get rommLogin_usernameHint => 'admin';

  @override
  String get rommLogin_password => '密碼';

  @override
  String get rommLogin_passwordHint => '••••••••';

  @override
  String get rommLogin_nameRequired => '名稱為必填';

  @override
  String get rommLogin_serverUrlRequired => '伺服器 URL 為必填';

  @override
  String get rommLogin_credentialsRequired => '使用者名稱或密碼為必填';

  @override
  String get ra_title => 'RetroAchievements';

  @override
  String get ra_subtitle => '追蹤您的復古遊戲成就。';

  @override
  String get ra_usernameLabel => '使用者名稱';

  @override
  String get ra_usernameHint => '您的 RA 使用者名稱';

  @override
  String get ra_apiKeyLabel => 'API Key';

  @override
  String get ra_apiKeyHint => '從 retroachievements.org 貼上';

  @override
  String get ra_usernameRequired => '使用者名稱為必填';

  @override
  String get ra_apiKeyRequired => 'API Key 為必填';

  @override
  String get ra_connectionFailed => '連線失敗';

  @override
  String get ra_disconnect => '斷開連線';

  @override
  String get ra_syncNow => '立即同步成就';

  @override
  String get ra_skipForNow => '暫時跳過';

  @override
  String get pairing_scanQrTitle => '掃描 QR Code';

  @override
  String get pairing_scanQrHint => '將 QR Code 置於框架內';

  @override
  String get pairing_enterManually => '手動輸入代碼';

  @override
  String get pairing_invalidQr => '此 QR Code 不是有效的 RomM 配對連結';

  @override
  String get pairing_manualTitle => '手動配對';

  @override
  String get pairing_manualInstructions => '請在 RomM 網頁版 UI 的設定中產生代碼';

  @override
  String get pairing_serverUrl => '伺服器 URL';

  @override
  String get pairing_pairingCode => '配對代碼';

  @override
  String get pairing_pairingCodeHint => 'ABCD-1234';

  @override
  String get pairing_probingServer => '正在探測伺服器...';

  @override
  String get pairing_serverNotReachable => '伺服器無法連線或非 RomM 執行實體';

  @override
  String get pairing_serverUrlRequired => '伺服器 URL 與代碼均為必填';

  @override
  String get pairing_successTitle => '配對成功';

  @override
  String get pairing_server => '伺服器';

  @override
  String get pairing_token => 'Token';

  @override
  String get pairing_userId => '使用者 ID';

  @override
  String get pairing_expiry => '有效期至';

  @override
  String get pairing_neverExpires => '永久有效';

  @override
  String get pairing_alreadyExpired => '已過期';

  @override
  String get pairing_permissions => '權限';

  @override
  String get pairing_addServer => '新增伺服器';

  @override
  String get service_notificationTitle => 'R-Shop';

  @override
  String get service_channelName => '下載項目';

  @override
  String get service_channelDescription => '顯示下載遊戲的進度';

  @override
  String get service_downloadComplete => '下載完成';

  @override
  String service_downloading(String details) {
    return '正在下載：$details';
  }

  @override
  String service_activeCount(int count) {
    return '$count 個下載中';
  }

  @override
  String service_queuedCount(int count) {
    return '$count 個等待中';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class LZhTw extends LZh {
  LZhTw() : super('zh_TW');

  @override
  String get appTitle => 'R-Shop';

  @override
  String get settings_language => '語言';

  @override
  String get settings_languageSystem => '系統預設';

  @override
  String get common_back => '返回';

  @override
  String get common_close => '關閉';

  @override
  String get common_cancel => '取消';

  @override
  String get common_cancelUpper => '取消';

  @override
  String get common_select => '選擇';

  @override
  String get common_search => '搜尋';

  @override
  String get common_searchEllipsis => '搜尋...';

  @override
  String get common_menu => '選單';

  @override
  String get common_navigate => '導航';

  @override
  String get common_toggle => '切換';

  @override
  String get common_clear => '清除';

  @override
  String get common_done => '完成';

  @override
  String get common_save => '儲存';

  @override
  String get common_connect => '連線';

  @override
  String get common_retry => '重試';

  @override
  String get common_remove => '移除';

  @override
  String get common_favorite => '收藏';

  @override
  String get common_unfavorite => '取消收藏';

  @override
  String get common_downloads => '下載項目';

  @override
  String get common_installed => '已安裝';

  @override
  String get common_move => '移動';

  @override
  String get common_drop => '放下';

  @override
  String get common_grab => '抓取';

  @override
  String get confirm_deleteTitle => '刪除 ROM？';

  @override
  String confirm_deleteMessage(String gameTitle) {
    return '您真的要刪除 $gameTitle 的這個版本嗎？';
  }

  @override
  String get confirm_exitTitle => '結束應用程式？';

  @override
  String get confirm_exitMessage => '您真的要結束 Retro eShop 嗎？';

  @override
  String get confirm_resetTitle => '重設應用程式？';

  @override
  String get confirm_resetMessage => '這將返回初始設定畫面。';

  @override
  String get confirm_deleteButton => '刪除';

  @override
  String get confirm_exitButton => '結束';

  @override
  String get confirm_resetButton => '重設';

  @override
  String get confirm_gamepadHint => '← → 選擇   A 確認   B 取消';

  @override
  String get exit_title => '結束應用程式';

  @override
  String get exit_message => '確定要退出嗎？';

  @override
  String get exit_confirmButton => '結束';

  @override
  String get exit_cancelButton => '留在這裡';

  @override
  String get downloads_title => '下載項目';

  @override
  String downloads_activeCount(int count) {
    return '$count 個進行中';
  }

  @override
  String get downloads_noDownloads => '無下載項目';

  @override
  String get downloads_sectionDownloading => '正在下載';

  @override
  String get downloads_sectionQueued => '等待中';

  @override
  String get downloads_sectionComplete => '已完成';

  @override
  String get downloads_actionCancel => '取消';

  @override
  String get downloads_actionRetry => '重試';

  @override
  String get downloads_actionRemove => '移除';

  @override
  String get downloads_actionClear => '清除';

  @override
  String get downloads_clearDone => '清除已完成項目';

  @override
  String get downloadStatus_downloading => '正在下載...';

  @override
  String get downloadStatus_extracting => '正在解壓縮...';

  @override
  String get downloadStatus_installing => '正在安裝...';

  @override
  String get downloadStatus_waiting => '等待中...';

  @override
  String get downloadStatus_complete => '已完成';

  @override
  String get downloadStatus_cancelled => '已取消';

  @override
  String get downloadStatus_failed => '失敗';

  @override
  String storage_free(String size) {
    return '剩餘 $size';
  }

  @override
  String storage_veryLow(String freeSpace) {
    return '儲存空間極低：$freeSpace';
  }

  @override
  String storage_gettingLow(String freeSpace) {
    return '儲存空間不足：$freeSpace';
  }

  @override
  String sync_progress(int completed, int total) {
    return '同步中 $completed/$total';
  }

  @override
  String sync_singleSystemFailed(String system) {
    return '$system 同步失敗';
  }

  @override
  String sync_multipleSystemsFailed(int count) {
    return '$count 個系統同步失敗';
  }

  @override
  String sync_raProgress(int completed, int total) {
    return '成就同步中 $completed/$total';
  }

  @override
  String get sync_raFailed => 'RA 同步失敗';

  @override
  String get toast_addedToQueue => '已加入下載佇列';

  @override
  String get toast_configRecovered => '已從備份復原設定';

  @override
  String gameCard_variantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個變體',
      one: '1 個變體',
    );
    return '$_temp0';
  }

  @override
  String get gameDetail_achievements => '成就';

  @override
  String get gameDetail_mastered => '已達成';

  @override
  String get gameDetail_noAchievementsFound => '找不到成就';

  @override
  String get gameDetail_retroachievements => 'RETROACHIEVEMENTS';

  @override
  String get gameDetail_romVerified => 'ROM 已驗證';

  @override
  String get gameDetail_incompatibleRom => '不相容的 ROM';

  @override
  String get gameDetail_gameHasAchievements => '此遊戲支援成就';

  @override
  String get gameDetail_viewAchievements => '查看成就';

  @override
  String get gameDetail_versions => '版本';

  @override
  String get gameDetail_download => '下載';

  @override
  String get gameDetail_adding => '正在加入...';

  @override
  String get gameDetail_queued => '等待中';

  @override
  String get gameDetail_extracting => '正在解壓縮...';

  @override
  String get gameDetail_delete => '刪除';

  @override
  String get gameDetail_manageFiles => '檔案管理';

  @override
  String get gameDetail_unavailable => '不可用';

  @override
  String get gameDetail_installedLabel => '已安裝';

  @override
  String get gameDetail_notFound => '找不到';

  @override
  String get gameDetail_details => '詳情';

  @override
  String get gameDetail_screenshots => '螢幕截圖';

  @override
  String get gameDetail_otherVersions => '其他版本';

  @override
  String get gameDetail_readMore => '閱讀更多...';

  @override
  String get gameDetail_showLess => '收起內容';

  @override
  String get gameDetail_standard => '標準';

  @override
  String get gameDetail_franchise => '系列';

  @override
  String get gameDetail_gameModes => '遊戲模式';

  @override
  String get gameDetail_perspective => '視角';

  @override
  String get gameDetail_ageRating => '分級';

  @override
  String get gameDetail_themes => '主題';

  @override
  String get gameDetail_fileTags => '檔案標籤';

  @override
  String get gameDetail_tagVersion => '版本';

  @override
  String get gameDetail_tagBuild => '組建';

  @override
  String get gameDetail_tagDisc => '光碟';

  @override
  String get gameDetail_tagQuality => '品質';

  @override
  String get gameDetail_tagInfo => '資訊';

  @override
  String get gameDetail_tagTechnical => '技術資訊';

  @override
  String get gameDetail_gameInfo => '遊戲資訊';

  @override
  String get gameDetail_showTitle => '顯示標題';

  @override
  String get gameDetail_showFilename => '顯示檔案名稱';

  @override
  String gameDetail_fromProvider(String provider) {
    return '來自 $provider';
  }

  @override
  String get gameDetail_addToShelf => '加入收藏架';

  @override
  String get gameDetail_removeFromShelf => '從收藏架移除';

  @override
  String get gameDetail_removeFromShelfTitle => '從收藏架移除';

  @override
  String get gameDetail_gameNotInstalled => '遊戲尚未安裝';

  @override
  String get gameDetail_couldNotShare => '無法分享遊戲檔案';

  @override
  String get gameDetail_pressAPickVersion => '按 A 選擇版本';

  @override
  String get gameDetail_pressAManage => '按 A 進行管理';

  @override
  String get gameDetail_pressADownload => '按 A 下載';

  @override
  String gameDetail_errorPrefix(String error) {
    return '錯誤：$error';
  }

  @override
  String get settings_title => '設定';

  @override
  String get settings_tabGeneral => '一般';

  @override
  String get settings_tabAudio => '音效';

  @override
  String get settings_tabAdvanced => '進階';

  @override
  String get settings_tabAbout => '關於';

  @override
  String get settings_previousTab => '上一個分頁';

  @override
  String get settings_nextTab => '下一個分頁';

  @override
  String get settings_resetApp => '重設應用程式';

  @override
  String get settings_resetDialogTitle => '重設應用程式';

  @override
  String get settings_resetDialogMessage => '這將刪除所有設定並重新開始設定流程。';

  @override
  String get settings_resetDialogConfirm => '重設';

  @override
  String get settings_resetDialogCancel => '取消';

  @override
  String get settings_sectionLibrary => '媒體庫';

  @override
  String get settings_sectionDisplay => '顯示';

  @override
  String get settings_mySources => '我的來源';

  @override
  String get settings_mySourcesSubtitle => '新增或管理 RomM, SMB, FTP 伺服器';

  @override
  String get settings_consoleSettings => '主機設定';

  @override
  String get settings_consoleSettingsSubtitle => '資料夾路徑、解壓縮、各系統選項';

  @override
  String get settings_retroAchievements => 'RetroAchievements';

  @override
  String get settings_retroAchievementsSubtitle => '成就追蹤與 ROM 驗證';

  @override
  String get settings_homeLayout => '主畫面佈局';

  @override
  String get settings_homeLayoutGrid => '網格檢視';

  @override
  String get settings_homeLayoutCarousel => '橫向輪播';

  @override
  String get settings_hideEmptyConsoles => '隱藏空的主機';

  @override
  String get settings_hideEmptyConsolesSubtitle => '僅顯示含有遊戲的系統';

  @override
  String get settings_controllerButtons => '控制器按鈕';

  @override
  String get settings_controllerNintendo => 'Nintendo (預設)';

  @override
  String get settings_controllerXbox => 'XBOX';

  @override
  String get settings_controllerPs => 'PS';

  @override
  String get settings_controllerNin => 'NIN';

  @override
  String get settings_sectionFeedback => '回饋';

  @override
  String get settings_vibration => '震動';

  @override
  String get settings_vibrationSubtitle => '按鈕按下時震動';

  @override
  String get settings_soundEffects => '音效';

  @override
  String get settings_soundEffectsSubtitle => '選單操作時播放音效';

  @override
  String get settings_sectionVolume => '音量';

  @override
  String get settings_music => '音樂';

  @override
  String get settings_musicSubtitle => '環境背景音樂';

  @override
  String get settings_effects => '音效';

  @override
  String get settings_effectsSubtitle => '介面音效';

  @override
  String get settings_sectionDownloads => '下載';

  @override
  String get settings_simultaneousDownloads => '同時下載數';

  @override
  String get settings_simultaneousDownloadsSubtitle => '可同時下載的檔案數量';

  @override
  String get settings_downloadAllCovers => '下載所有封面';

  @override
  String get settings_downloadingCovers => '正在下載封面...';

  @override
  String get settings_sectionSync => '同步';

  @override
  String get settings_syncTimeout => '同步逾時';

  @override
  String get settings_syncTimeoutSubtitle => '等待每個伺服器的最長時間';

  @override
  String get settings_autoSyncInterval => '自動同步間隔';

  @override
  String get settings_autoSyncIntervalSubtitle => '自動同步之間的最小間隔時間';

  @override
  String get settings_sectionDebug => '除錯';

  @override
  String get settings_allowInsecure => '允許不安全連線';

  @override
  String get settings_allowInsecureSubtitle => '為不支援 HTTPS 的伺服器啟用 HTTP';

  @override
  String get settings_exportErrorLog => '匯出錯誤日誌';

  @override
  String get settings_exportErrorLogSubtitle => '分享當機日誌以供排錯';

  @override
  String get settings_sectionInfo => '資訊';

  @override
  String get settings_sectionLinks => '連結';

  @override
  String get settings_github => 'GitHub';

  @override
  String get settings_githubSubtitle => '在 GitHub 上查看原始碼';

  @override
  String get settings_issues => '問題回報';

  @override
  String get settings_issuesSubtitle => '回報 Bug 或要求新功能';

  @override
  String get settings_tagline => 'INTENSIV, AGGRESSIV, MUTIG';

  @override
  String get settings_deviceMemoryLow => '低';

  @override
  String get settings_deviceMemoryStandard => '標準';

  @override
  String get settings_deviceMemoryHigh => '高';

  @override
  String get settings_fetchingCovers => '正在擷取封面...';

  @override
  String settings_coversResult(int ok, int failed) {
    return '封面：$ok 成功, $failed 失敗';
  }

  @override
  String settings_coversLoaded(int count) {
    return '已載入 $count 張封面！';
  }

  @override
  String get settings_noErrorLog => '無可用錯誤日誌';

  @override
  String get settings_configImported => '設定已匯入！';

  @override
  String get settings_controllerXboxFull => 'Xbox (A/B 與 X/Y 反轉)';

  @override
  String get settings_controllerPlaystationFull => 'PlayStation (✕ ○ □ △)';

  @override
  String get settings_allCoversCached => '所有封面皆已快取';

  @override
  String get settings_downloadCoverArt => '下載所有遊戲的封面圖';

  @override
  String settings_coverCacheInfo(String size, int count) {
    return '$size ($count 個已快取)';
  }

  @override
  String settings_coversRemaining(int count, String size) {
    return '剩餘 $count 個 (~$size MB)';
  }

  @override
  String settings_coversProgress(int completed, int total) {
    return '$completed / $total 款遊戲';
  }

  @override
  String get configMode_title => '主機設定';

  @override
  String get configMode_globalTitle => '全域設定';

  @override
  String get configMode_noFolderSet => '尚未設定資料夾';

  @override
  String get configMode_notConfigured => '未配置';

  @override
  String get configMode_export => '匯出';

  @override
  String get configMode_import => '匯入';

  @override
  String get systemDetail_sectionStorage => '儲存空間';

  @override
  String get systemDetail_selectRomFolder => '選擇 ROM 資料夾';

  @override
  String get systemDetail_tapToChangeFolder => '點擊以變更資料夾';

  @override
  String get systemDetail_sectionBehavior => '行為';

  @override
  String get systemDetail_autoExtractZips => '自動解壓縮 ZIP';

  @override
  String get systemDetail_autoExtractEnabled => '下載後自動解壓縮 ZIP 格式的 ROM';

  @override
  String get systemDetail_autoExtractDisabled => '下載後保持 ZIP 格式';

  @override
  String get systemDetail_autoSyncOnLaunch => '啟動時自動同步';

  @override
  String get systemDetail_autoSyncEnabled => '自動同步（遵循冷卻時間）';

  @override
  String get systemDetail_autoSyncDisabled => '僅透過 Start 選單手動同步';

  @override
  String get systemDetail_sectionSources => '來源';

  @override
  String get sources_title => '來源';

  @override
  String get sources_noSourcesConfigured => '尚未配置來源';

  @override
  String get sources_noSourcesYet => '目前無來源';

  @override
  String get sources_noSourcesDescription => '配對 RomM 伺服器以開始下載遊戲。';

  @override
  String get sources_addSource => '新增來源';

  @override
  String get sources_whereDoGamesComeFrom => '您的遊戲來自哪裡？';

  @override
  String get sources_sourceTypeRomm => 'RomM 伺服器';

  @override
  String get sources_sourceTypeRommHint => '透過 QR 或 8 位代碼配對';

  @override
  String get sources_sourceTypeRommLegacy => 'RomM 登入（舊版伺服器）';

  @override
  String get sources_sourceTypeSmb => 'SMB 分享';

  @override
  String get sources_sourceTypeFtp => 'FTP 伺服器';

  @override
  String get sources_sourceTypeWeb => 'Web 鏡像';

  @override
  String get sources_sourceTypeWebHint => 'HTTPS 目錄列表';

  @override
  String get sources_expired => '已過期';

  @override
  String get sources_borrowed => '已借用';

  @override
  String get sources_off => '關閉';

  @override
  String get sources_noPlatforms => '無平台';

  @override
  String get sources_rePair => '重新配對';

  @override
  String get sources_editMappings => '編輯對應';

  @override
  String get sources_disable => '停用';

  @override
  String get sources_enable => '啟用';

  @override
  String get manualSource_defaultNameSmb => '我的 NAS';

  @override
  String get manualSource_defaultNameFtp => '我的 FTP';

  @override
  String get manualSource_defaultNameWeb => 'Web 鏡像';

  @override
  String get manualSource_defaultNameOther => '來源';

  @override
  String get manualSource_name => '名稱';

  @override
  String get manualSource_url => 'URL';

  @override
  String get manualSource_urlHint => 'https://example.com/roms';

  @override
  String get manualSource_host => '主機';

  @override
  String get manualSource_hostHint => 'nas.local 或 192.168.1.10';

  @override
  String get manualSource_port => '連接埠';

  @override
  String get manualSource_share => '分享名稱';

  @override
  String get manualSource_shareHint => 'roms';

  @override
  String get manualSource_usernameOptional => '使用者名稱 (選填)';

  @override
  String get manualSource_usernameHint => '訪客請保持空白';

  @override
  String get manualSource_passwordOptional => '密碼 (選填)';

  @override
  String get manualSource_nameRequired => '名稱為必填';

  @override
  String get manualSource_urlRequired => 'URL 為必填';

  @override
  String get manualSource_hostRequired => '主機為必填';

  @override
  String get manualSource_shareRequired => '分享名稱為必填';

  @override
  String get manualSource_saveSource => '儲存來源';

  @override
  String get manualSource_smb => 'SMB';

  @override
  String get manualSource_ftp => 'FTP';

  @override
  String get manualSource_web => 'Web';

  @override
  String get manualSource_searchingNetwork => '正在搜尋網路...';

  @override
  String get manualSource_foundOnNetwork => '在您的網路中找到';

  @override
  String get sourceMappings_title => '系統對應';

  @override
  String get sourceMappings_instruction => '輸入每個系統對應的遠端資料夾。留空則跳過。';

  @override
  String get sourceMappings_save => '儲存對應';

  @override
  String get library_title => '媒體庫';

  @override
  String get library_tabAll => '全部';

  @override
  String get library_tabInstalled => '已安裝';

  @override
  String get library_tabFavorites => '我的收藏';

  @override
  String get library_sortSystem => '按系統排序';

  @override
  String get library_sortManual => '手動排序';

  @override
  String get library_sortAZ => '按 A-Z 排序';

  @override
  String get library_sortIndicatorAZ => 'A-Z';

  @override
  String get library_sortIndicatorBySystem => '按系統';

  @override
  String get library_sortIndicatorManual => '手動';

  @override
  String get library_searchHint => '搜尋媒體庫...';

  @override
  String get library_zoomIn => '放大';

  @override
  String get library_zoomOut => '縮小';

  @override
  String get library_newShelf => '新增收藏架';

  @override
  String get library_editShelf => '編輯收藏架';

  @override
  String get library_addToShelf => '加入收藏架';

  @override
  String get library_removeFromShelf => '從收藏架移除';

  @override
  String get library_reorderGames => '重新排列遊戲';

  @override
  String library_noResults(String query) {
    return '找不到與「$query」相關的結果';
  }

  @override
  String get library_tryShorterSearch => '請嘗試更短的搜尋詞';

  @override
  String get library_noInstalledGames => '目前無已安裝的遊戲';

  @override
  String get library_downloadGamesToSee => '下載遊戲後會顯示在這裡';

  @override
  String get library_noFavoritesYet => '尚未收藏任何遊戲';

  @override
  String get library_pressFavoriteHint => '對著遊戲按 SELECT 即可加入收藏';

  @override
  String get library_noGamesInShelf => '此收藏架內無遊戲';

  @override
  String get library_addGamesViaEditor => '透過收藏架編輯器新增遊戲';

  @override
  String get library_noGamesInLibrary => '媒體庫中無遊戲';

  @override
  String get library_gamesAfterSync => '同步完成後遊戲將會出現';

  @override
  String get shelfEdit_title => '編輯收藏架';

  @override
  String get shelfEdit_titleNew => '新增收藏架';

  @override
  String get shelfEdit_nameSection => '名稱';

  @override
  String get shelfEdit_shelfName => '收藏架名稱';

  @override
  String get shelfEdit_filterText => '過濾文字';

  @override
  String get shelfEdit_tapToSet => '點擊以設定...';

  @override
  String get shelfEdit_filterRules => '過濾規則';

  @override
  String get shelfEdit_resetManualOrder => '重設手動排序';

  @override
  String get shelfEdit_saveButton => '儲存';

  @override
  String get shelfEdit_deleteShelf => '刪除收藏架';

  @override
  String get shelfEdit_anyText => '任何文字';

  @override
  String get shelfEdit_allSystems => '所有系統';

  @override
  String get shelfPicker_title => '加入收藏架';

  @override
  String get systemSelector_title => '選擇系統';

  @override
  String get textInput_hint => '輸入文字...';

  @override
  String get textInput_ok => '確定';

  @override
  String get gameListOverlay_hiddenGames => '隱藏的遊戲';

  @override
  String get gameListOverlay_addedGames => '已新增的遊戲';

  @override
  String get gameListOverlay_restore => '還原';

  @override
  String get gameListOverlay_noGames => '無遊戲';

  @override
  String get gameListOverlay_clearAll => '全部清除';

  @override
  String get home_allGames => '所有遊戲';

  @override
  String get home_library => '媒體庫';

  @override
  String get home_noConsoles => '尚未配置主機';

  @override
  String get home_pressStartForMenu => '按 Start 開啟選單';

  @override
  String get home_settings => '設定';

  @override
  String home_syncSystem(String system) {
    return '同步 $system';
  }

  @override
  String get home_syncAll => '同步全部';

  @override
  String get home_lastSyncNever => '從未同步';

  @override
  String get home_lastSyncJustNow => '剛剛同步';

  @override
  String home_lastSyncMinutes(int minutes) {
    return '$minutes 分鐘前同步';
  }

  @override
  String home_lastSyncHours(int hours) {
    return '$hours 小時前同步';
  }

  @override
  String home_lastSyncDays(int days) {
    return '$days 天前同步';
  }

  @override
  String get common_exit => '結束';

  @override
  String gameList_gamesCount(int count) {
    return '$count 款遊戲';
  }

  @override
  String get gameList_offline => '離線';

  @override
  String get gameList_zoomIn => '放大';

  @override
  String get gameList_zoomOut => '縮小';

  @override
  String get gameList_filterActive => '過濾器 (啟用中)';

  @override
  String get gameList_filter => '過濾器';

  @override
  String gameList_noGamesMatchSearch(String query) {
    return '找不到符合「$query」的遊戲';
  }

  @override
  String get gameList_tryShorterSearch => '請嘗試更短的搜尋詞';

  @override
  String get gameList_noGamesMatchFilters => '沒有符合當前過濾條件的遊戲';

  @override
  String get gameList_changeFilters => '請在選單中更改或重設過濾器';

  @override
  String gameList_noRomsFound(String folder) {
    return '在 $folder 中找不到 ROM';
  }

  @override
  String get gameList_addRomFiles => '請將 ROM 檔案加入此資料夾並重新整理';

  @override
  String get gameList_couldNotLoadGames => '無法載入遊戲';

  @override
  String get gameList_checkConnection => '請檢查您的連線並再試一次';

  @override
  String get gameList_errorLoadingGames => '載入遊戲時發生錯誤';

  @override
  String get gameList_gamesAppearShortly => '遊戲很快就會出現';

  @override
  String get gameList_syncingLibrary => '正在同步媒體庫...';

  @override
  String get gameList_localFilesOnly => '僅限本地檔案 · 新增來源以獲得更多';

  @override
  String get gameList_pressMenuHint => '按 + 開啟選單';

  @override
  String filter_activeCount(int count) {
    return '$count 個已啟用';
  }

  @override
  String get shelfEdit_addFilter => '+ 新增過濾器';

  @override
  String shelfEdit_hiddenGamesCount(int count) {
    return '隱藏的遊戲 ($count)';
  }

  @override
  String shelfEdit_addedGamesCount(int count) {
    return '已新增的遊戲 ($count)';
  }

  @override
  String get shelfEdit_textHint => '← 文字  系統 →';

  @override
  String gameListOverlay_gameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 款遊戲',
      one: '1 款遊戲',
    );
    return '$_temp0';
  }

  @override
  String gameListOverlay_actionHint(String action) {
    return 'A: $action';
  }

  @override
  String systemSelector_selectedCount(int count) {
    return '已選擇 $count 個';
  }

  @override
  String get filter_favoritesOnly => '僅收藏項目';

  @override
  String get filter_installedOnly => '僅已安裝項目';

  @override
  String get filter_regions => '地區';

  @override
  String get filter_languages => '語言';

  @override
  String get filter_title => '過濾器';

  @override
  String get onboarding_welcomeTitle => '歡迎使用 R-Shop';

  @override
  String get onboarding_welcomeSubtitle => '您的遊戲來自哪裡？';

  @override
  String get onboarding_pairQrTitle => '透過 QR 配對 RomM';

  @override
  String get onboarding_pairQrSubtitle => '掃描 RomM 伺服器提供的 QR Code';

  @override
  String get onboarding_legacyLoginTitle => 'RomM 登入（舊版伺服器）';

  @override
  String get onboarding_legacyLoginSubtitle => 'RomM < 4.8 版的使用者名稱與密碼';

  @override
  String get onboarding_addServerTitle => '新增我自己的伺服器';

  @override
  String get onboarding_addServerSubtitle => 'SMB, FTP 或 Web 鏡像 — 手動對應系統';

  @override
  String get onboarding_localOnlyTitle => '僅限本地遊戲';

  @override
  String get onboarding_localOnlySubtitle => '已在此設備上的 ROM';

  @override
  String get onboarding_working => '運作中...';

  @override
  String get onboarding_scanningFolders => '正在掃描本地 ROM 資料夾...';

  @override
  String get onboarding_discoveringPlatforms => '正在搜尋平台...';

  @override
  String get onboarding_savingSource => '正在儲存來源...';

  @override
  String get onboarding_allSet => '一切就緒';

  @override
  String get onboarding_noSystems => '尚未配置系統 — 您稍後可以從「設定」新增來源。';

  @override
  String onboarding_systemsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個系統已可瀏覽',
      one: '1 個系統已可瀏覽',
    );
    return '$_temp0';
  }

  @override
  String get onboarding_jumpIn => '開始使用';

  @override
  String get onboarding_jumpInSubtitle => '開啟主畫面並開始同步';

  @override
  String get onboarding_retroachievements => 'RetroAchievements';

  @override
  String get onboarding_retroachievementsSubtitle => '追蹤您的復古遊戲成就';

  @override
  String get onboarding_exportConfig => '匯出設定';

  @override
  String get onboarding_exportConfigSubtitle => '在另一台設備上重複使用此設定';

  @override
  String get onboarding_importConfig => '匯入設定';

  @override
  String get onboarding_configImported => '設定已匯入！';

  @override
  String onboarding_exportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String onboarding_invalidConfig(String error) {
    return '無效設定：$error';
  }

  @override
  String onboarding_failedToSave(String error) {
    return '儲存失敗：$error';
  }

  @override
  String get onboarding_selectFolderPrompt => '選擇儲存 ROM 的資料夾';

  @override
  String get onboarding_serverType => '伺服器類型';

  @override
  String get onboarding_hangOn => '請稍候，正在測試連線...';

  @override
  String get onboarding_foundConsole => '我在您的 RomM 伺服器上找到了這個主機！請確認或選擇另一個。';

  @override
  String get onboarding_pickPlatform => '從您的 RomM 伺服器選擇對應的平台。';

  @override
  String get onboarding_couldNotReach => '無法連線至您的 RomM 伺服器。請檢查 URL 並再試一次。';

  @override
  String get onboarding_connectionGood => '連線狀況良好！您可以儲存此來源了。';

  @override
  String get onboarding_couldNotConnect => '嗯... 無法連線。請再次確認網址與憑據。';

  @override
  String get onboarding_whatKindOfSource => '這是哪種類型的來源？請選擇連線類型。';

  @override
  String get onboarding_lookingGood => '看起來不錯！您可以新增更多來源，或者在就緒後按「完成」。';

  @override
  String get onboarding_localCollection => '這是本地收藏。您可以新增來源來下載更多遊戲，或直接按「完成」！';

  @override
  String get onboarding_addMoreSources => '現在請至少新增一個來源，好讓我知道去哪裡找 ROM。';

  @override
  String get onboarding_letsSetUp => '讓我們來設定您的主機！選擇任一系統即可開始。';

  @override
  String get onboarding_romFolder => 'ROM 資料夾';

  @override
  String get onboarding_options => '選項';

  @override
  String get onboarding_autoExtractZips => '自動解壓縮 ZIP 格式 ROM';

  @override
  String get onboarding_autoSyncLabel => '啟動時自動同步';

  @override
  String get onboarding_autoSyncEnabled => '自動同步（遵循冷卻時間）';

  @override
  String get onboarding_autoSyncDisabled => '僅透過 Start 選單手動同步';

  @override
  String get onboarding_selectFolder => '選擇資料夾...';

  @override
  String get providerForm_addSource => '新增來源';

  @override
  String get providerForm_editSource => '編輯來源';

  @override
  String get providerForm_url => 'URL';

  @override
  String get providerForm_urlPlaceholder => 'https://...';

  @override
  String get providerForm_path => '路徑';

  @override
  String get providerForm_pathPlaceholder => '/roms/nes/ (選填)';

  @override
  String get providerForm_username => '使用者名稱';

  @override
  String get providerForm_usernameOptional => '(選填)';

  @override
  String get providerForm_password => '密碼';

  @override
  String get providerForm_host => '主機';

  @override
  String get providerForm_hostPlaceholder => '192.168.1.100';

  @override
  String get providerForm_port => '連接埠';

  @override
  String get providerForm_share => '分享名稱';

  @override
  String get providerForm_sharePlaceholder => 'roms';

  @override
  String get providerForm_domain => '網域';

  @override
  String get providerForm_domainOptional => '(選填)';

  @override
  String get providerForm_rommUrl => 'URL';

  @override
  String get providerForm_rommUrlPlaceholder => 'https://romm.example.com';

  @override
  String get providerForm_apiKey => 'API Key';

  @override
  String get providerForm_apiKeyOptional => '(選填)';

  @override
  String get providerForm_httpBlocked =>
      '非本地伺服器的 HTTP 已被封鎖。請使用 HTTPS，或稍後在「設定」中啟用。';

  @override
  String get providerForm_httpWarning => '憑據將透過未加密的 HTTP 傳送';

  @override
  String get providerForm_testingConnection => '正在測試連線...';

  @override
  String get providerForm_connectionSuccessful => '連線成功！';

  @override
  String get providerForm_fetchingPlatforms => '正在擷取平台...';

  @override
  String get providerForm_noPlatformsFound => '在此 RomM 伺服器上找不到任何平台。';

  @override
  String get providerForm_platform => '平台';

  @override
  String get providerForm_pickPlatform => '選擇平台...';

  @override
  String get providerForm_testAndSave => '測試並儲存';

  @override
  String get providerForm_connectionFailed => '連線失敗';

  @override
  String get providerForm_hostMissing => '主機';

  @override
  String get providerForm_portMissing => '連接埠';

  @override
  String get providerForm_pathMissing => '路徑';

  @override
  String get providerForm_shareMissing => '分享名稱';

  @override
  String get providerForm_urlMissing => 'URL';

  @override
  String get rommLogin_title => '登入 RomM';

  @override
  String get rommLogin_name => '名稱';

  @override
  String get rommLogin_nameDefault => '我的 RomM';

  @override
  String get rommLogin_serverUrl => '伺服器 URL';

  @override
  String get rommLogin_username => '使用者名稱';

  @override
  String get rommLogin_usernameHint => 'admin';

  @override
  String get rommLogin_password => '密碼';

  @override
  String get rommLogin_passwordHint => '••••••••';

  @override
  String get rommLogin_nameRequired => '名稱為必填';

  @override
  String get rommLogin_serverUrlRequired => '伺服器 URL 為必填';

  @override
  String get rommLogin_credentialsRequired => '使用者名稱或密碼為必填';

  @override
  String get ra_title => 'RetroAchievements';

  @override
  String get ra_subtitle => '追蹤您的復古遊戲成就。';

  @override
  String get ra_usernameLabel => '使用者名稱';

  @override
  String get ra_usernameHint => '您的 RA 使用者名稱';

  @override
  String get ra_apiKeyLabel => 'API Key';

  @override
  String get ra_apiKeyHint => '從 retroachievements.org 貼上';

  @override
  String get ra_usernameRequired => '使用者名稱為必填';

  @override
  String get ra_apiKeyRequired => 'API Key 為必填';

  @override
  String get ra_connectionFailed => '連線失敗';

  @override
  String get ra_disconnect => '斷開連線';

  @override
  String get ra_syncNow => '立即同步成就';

  @override
  String get ra_skipForNow => '暫時跳過';

  @override
  String get pairing_scanQrTitle => '掃描 QR Code';

  @override
  String get pairing_scanQrHint => '將 QR Code 置於框架內';

  @override
  String get pairing_enterManually => '手動輸入代碼';

  @override
  String get pairing_invalidQr => '此 QR Code 不是有效的 RomM 配對連結';

  @override
  String get pairing_manualTitle => '手動配對';

  @override
  String get pairing_manualInstructions => '請在 RomM 網頁版 UI 的設定中產生代碼';

  @override
  String get pairing_serverUrl => '伺服器 URL';

  @override
  String get pairing_pairingCode => '配對代碼';

  @override
  String get pairing_pairingCodeHint => 'ABCD-1234';

  @override
  String get pairing_probingServer => '正在探測伺服器...';

  @override
  String get pairing_serverNotReachable => '伺服器無法連線或非 RomM 執行實體';

  @override
  String get pairing_serverUrlRequired => '伺服器 URL 與代碼均為必填';

  @override
  String get pairing_successTitle => '配對成功';

  @override
  String get pairing_server => '伺服器';

  @override
  String get pairing_token => 'Token';

  @override
  String get pairing_userId => '使用者 ID';

  @override
  String get pairing_expiry => '有效期至';

  @override
  String get pairing_neverExpires => '永久有效';

  @override
  String get pairing_alreadyExpired => '已過期';

  @override
  String get pairing_permissions => '權限';

  @override
  String get pairing_addServer => '新增伺服器';

  @override
  String get service_notificationTitle => 'R-Shop';

  @override
  String get service_channelName => '下載項目';

  @override
  String get service_channelDescription => '顯示下載遊戲的進度';

  @override
  String get service_downloadComplete => '下載完成';

  @override
  String service_downloading(String details) {
    return '正在下載：$details';
  }

  @override
  String service_activeCount(int count) {
    return '$count 個下載中';
  }

  @override
  String service_queuedCount(int count) {
    return '$count 個等待中';
  }
}
