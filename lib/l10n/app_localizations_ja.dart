// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class LJa extends L {
  LJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'R-Shop';

  @override
  String get settings_language => '言語';

  @override
  String get settings_languageSystem => 'システムのデフォルト';

  @override
  String get common_back => '戻る';

  @override
  String get common_close => '閉じる';

  @override
  String get common_cancel => 'キャンセル';

  @override
  String get common_cancelUpper => 'キャンセル';

  @override
  String get common_select => '選択';

  @override
  String get common_search => '検索';

  @override
  String get common_searchEllipsis => '検索...';

  @override
  String get common_menu => 'メニュー';

  @override
  String get common_navigate => 'ナビゲート';

  @override
  String get common_toggle => '切り替え';

  @override
  String get common_clear => 'クリア';

  @override
  String get common_done => '完了';

  @override
  String get common_save => '保存';

  @override
  String get common_connect => '接続';

  @override
  String get common_retry => 'リトライ';

  @override
  String get common_remove => '削除';

  @override
  String get common_favorite => 'お気に入り';

  @override
  String get common_unfavorite => 'お気に入り解除';

  @override
  String get common_downloads => 'ダウンロード';

  @override
  String get common_installed => 'インストール済み';

  @override
  String get common_move => '移動';

  @override
  String get common_drop => 'ドロップ';

  @override
  String get common_grab => 'つかむ';

  @override
  String get confirm_deleteTitle => 'ROMを削除？';

  @override
  String confirm_deleteMessage(String gameTitle) {
    return '$gameTitleのこのバージョンを削除しますか？';
  }

  @override
  String get confirm_exitTitle => 'アプリを終了？';

  @override
  String get confirm_exitMessage => 'Retro eShopを終了しますか？';

  @override
  String get confirm_resetTitle => 'アプリをリセット？';

  @override
  String get confirm_resetMessage => 'オンボーディング画面に戻ります。';

  @override
  String get confirm_deleteButton => '削除';

  @override
  String get confirm_exitButton => '終了';

  @override
  String get confirm_resetButton => 'リセット';

  @override
  String get confirm_gamepadHint => '← → 選択   A 決定   B キャンセル';

  @override
  String get exit_title => 'アプリを終了';

  @override
  String get exit_message => '本当に終了しますか？';

  @override
  String get exit_confirmButton => '終了';

  @override
  String get exit_cancelButton => 'とどまる';

  @override
  String get downloads_title => 'ダウンロード';

  @override
  String downloads_activeCount(int count) {
    return '$count件アクティブ';
  }

  @override
  String get downloads_noDownloads => 'ダウンロードなし';

  @override
  String get downloads_sectionDownloading => 'ダウンロード中';

  @override
  String get downloads_sectionQueued => 'キュー';

  @override
  String get downloads_sectionComplete => '完了';

  @override
  String get downloads_actionCancel => 'キャンセル';

  @override
  String get downloads_actionRetry => 'リトライ';

  @override
  String get downloads_actionRemove => '削除';

  @override
  String get downloads_actionClear => 'クリア';

  @override
  String get downloads_clearDone => '完了をクリア';

  @override
  String get downloadStatus_downloading => 'ダウンロード中...';

  @override
  String get downloadStatus_extracting => '展開中...';

  @override
  String get downloadStatus_installing => 'インストール中...';

  @override
  String get downloadStatus_waiting => '待機中...';

  @override
  String get downloadStatus_complete => '完了';

  @override
  String get downloadStatus_cancelled => 'キャンセル済み';

  @override
  String get downloadStatus_failed => '失敗';

  @override
  String storage_free(String size) {
    return '$size 空き';
  }

  @override
  String storage_veryLow(String freeSpace) {
    return 'ストレージ残りわずか: $freeSpace';
  }

  @override
  String storage_gettingLow(String freeSpace) {
    return 'ストレージが少ない: $freeSpace';
  }

  @override
  String sync_progress(int completed, int total) {
    return '同期中 $completed/$total';
  }

  @override
  String sync_singleSystemFailed(String system) {
    return '$systemの同期に失敗';
  }

  @override
  String sync_multipleSystemsFailed(int count) {
    return '$countシステムの同期に失敗';
  }

  @override
  String sync_raProgress(int completed, int total) {
    return '実績 $completed/$total';
  }

  @override
  String get sync_raFailed => 'RA同期失敗';

  @override
  String get toast_addedToQueue => 'キューに追加しました';

  @override
  String get toast_configRecovered => 'バックアップから設定を復元しました';

  @override
  String gameCard_variantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countバリアント',
      one: '1バリアント',
    );
    return '$_temp0';
  }

  @override
  String get gameDetail_achievements => '実績';

  @override
  String get gameDetail_mastered => 'マスター';

  @override
  String get gameDetail_noAchievementsFound => '実績が見つかりません';

  @override
  String get gameDetail_retroachievements => 'RETROACHIEVEMENTS';

  @override
  String get gameDetail_romVerified => 'ROM検証済み';

  @override
  String get gameDetail_incompatibleRom => '非対応 ROM';

  @override
  String get gameDetail_gameHasAchievements => '実績あり';

  @override
  String get gameDetail_viewAchievements => '実績を見る';

  @override
  String get gameDetail_versions => 'バージョン';

  @override
  String get gameDetail_download => 'ダウンロード';

  @override
  String get gameDetail_adding => '追加中...';

  @override
  String get gameDetail_queued => '待機中';

  @override
  String get gameDetail_extracting => '展開中...';

  @override
  String get gameDetail_delete => '削除';

  @override
  String get gameDetail_manageFiles => 'ファイル管理';

  @override
  String get gameDetail_unavailable => '利用不可';

  @override
  String get gameDetail_installedLabel => 'インストール済み';

  @override
  String get gameDetail_notFound => '見つかりません';

  @override
  String get gameDetail_details => '詳細';

  @override
  String get gameDetail_screenshots => 'スクリーンショット';

  @override
  String get gameDetail_otherVersions => '他のバージョン';

  @override
  String get gameDetail_readMore => 'もっと見る...';

  @override
  String get gameDetail_showLess => '閉じる';

  @override
  String get gameDetail_standard => 'スタンダード';

  @override
  String get gameDetail_franchise => 'フランチャイズ';

  @override
  String get gameDetail_gameModes => 'ゲームモード';

  @override
  String get gameDetail_perspective => '視点';

  @override
  String get gameDetail_ageRating => '年齢レーティング';

  @override
  String get gameDetail_themes => 'テーマ';

  @override
  String get gameDetail_fileTags => 'ファイルタグ';

  @override
  String get gameDetail_tagVersion => 'バージョン';

  @override
  String get gameDetail_tagBuild => 'ビルド';

  @override
  String get gameDetail_tagDisc => 'ディスク';

  @override
  String get gameDetail_tagQuality => '品質';

  @override
  String get gameDetail_tagInfo => '情報';

  @override
  String get gameDetail_tagTechnical => '技術';

  @override
  String get gameDetail_gameInfo => 'ゲーム情報';

  @override
  String get gameDetail_showTitle => 'タイトル表示';

  @override
  String get gameDetail_showFilename => 'ファイル名表示';

  @override
  String gameDetail_fromProvider(String provider) {
    return '$providerから';
  }

  @override
  String get gameDetail_addToShelf => 'シェルフに追加';

  @override
  String get gameDetail_removeFromShelf => 'シェルフから削除';

  @override
  String get gameDetail_removeFromShelfTitle => 'シェルフから削除';

  @override
  String get gameDetail_gameNotInstalled => 'ゲームがインストールされていません';

  @override
  String get gameDetail_couldNotShare => 'ゲームファイルを共有できませんでした';

  @override
  String get gameDetail_pressAPickVersion => 'Aでバージョンを選択';

  @override
  String get gameDetail_pressAManage => 'Aで管理';

  @override
  String get gameDetail_pressADownload => 'Aでダウンロード';

  @override
  String gameDetail_errorPrefix(String error) {
    return 'エラー: $error';
  }

  @override
  String get settings_title => '設定';

  @override
  String get settings_tabGeneral => '一般';

  @override
  String get settings_tabAudio => 'オーディオ';

  @override
  String get settings_tabAdvanced => '詳細';

  @override
  String get settings_tabAbout => 'このアプリについて';

  @override
  String get settings_previousTab => '前のタブ';

  @override
  String get settings_nextTab => '次のタブ';

  @override
  String get settings_resetApp => 'アプリをリセット';

  @override
  String get settings_resetDialogTitle => 'アプリリセット';

  @override
  String get settings_resetDialogMessage => 'すべての設定が削除され、初期セットアップからやり直しになります。';

  @override
  String get settings_resetDialogConfirm => 'リセット';

  @override
  String get settings_resetDialogCancel => 'キャンセル';

  @override
  String get settings_sectionLibrary => 'ライブラリ';

  @override
  String get settings_sectionDisplay => '表示';

  @override
  String get settings_mySources => 'マイソース';

  @override
  String get settings_mySourcesSubtitle => 'RomM、SMB、FTPサーバーの追加・管理';

  @override
  String get settings_consoleSettings => 'コンソール設定';

  @override
  String get settings_consoleSettingsSubtitle => 'フォルダ、展開、システムごとの設定';

  @override
  String get settings_retroAchievements => 'RetroAchievements';

  @override
  String get settings_retroAchievementsSubtitle => '実績トラッキングとROM検証';

  @override
  String get settings_homeLayout => 'ホームレイアウト';

  @override
  String get settings_homeLayoutGrid => 'グリッド表示';

  @override
  String get settings_homeLayoutCarousel => '横スクロール';

  @override
  String get settings_hideEmptyConsoles => '空のコンソールを隠す';

  @override
  String get settings_hideEmptyConsolesSubtitle => 'ゲームのあるシステムだけ表示';

  @override
  String get settings_controllerButtons => 'コントローラーボタン';

  @override
  String get settings_controllerNintendo => 'Nintendo（デフォルト）';

  @override
  String get settings_controllerXbox => 'XBOX';

  @override
  String get settings_controllerPs => 'PS';

  @override
  String get settings_controllerNin => 'NIN';

  @override
  String get settings_sectionFeedback => 'フィードバック';

  @override
  String get settings_vibration => 'バイブレーション';

  @override
  String get settings_vibrationSubtitle => 'ボタン操作時に振動';

  @override
  String get settings_soundEffects => '効果音';

  @override
  String get settings_soundEffectsSubtitle => 'メニュー操作時に音を鳴らす';

  @override
  String get settings_sectionVolume => 'ボリューム';

  @override
  String get settings_music => '音楽';

  @override
  String get settings_musicSubtitle => 'バックグラウンドミュージック';

  @override
  String get settings_effects => '効果音';

  @override
  String get settings_effectsSubtitle => 'UIサウンドエフェクト';

  @override
  String get settings_sectionDownloads => 'ダウンロード';

  @override
  String get settings_simultaneousDownloads => '同時ダウンロード数';

  @override
  String get settings_simultaneousDownloadsSubtitle => '一度にダウンロードするファイル数';

  @override
  String get settings_downloadAllCovers => '全カバーをダウンロード';

  @override
  String get settings_downloadingCovers => 'カバーダウンロード中...';

  @override
  String get settings_sectionSync => '同期';

  @override
  String get settings_syncTimeout => '同期タイムアウト';

  @override
  String get settings_syncTimeoutSubtitle => '各サーバーの待機時間';

  @override
  String get settings_autoSyncInterval => '自動同期間隔';

  @override
  String get settings_autoSyncIntervalSubtitle => '自動同期の最小間隔';

  @override
  String get settings_sectionDebug => 'デバッグ';

  @override
  String get settings_allowInsecure => '非セキュア接続を許可';

  @override
  String get settings_allowInsecureSubtitle => 'HTTPSなしのサーバーにHTTPを許可';

  @override
  String get settings_exportErrorLog => 'エラーログをエクスポート';

  @override
  String get settings_exportErrorLogSubtitle => 'トラブルシューティング用にログを共有';

  @override
  String get settings_sectionInfo => '情報';

  @override
  String get settings_sectionLinks => 'リンク';

  @override
  String get settings_github => 'GitHub';

  @override
  String get settings_githubSubtitle => 'GitHubでソースコードを見る';

  @override
  String get settings_issues => 'Issues';

  @override
  String get settings_issuesSubtitle => 'バグ報告や機能リクエスト';

  @override
  String get settings_tagline => 'INTENSIV, AGGRESSIV, MUTIG';

  @override
  String get settings_deviceMemoryLow => 'LOW';

  @override
  String get settings_deviceMemoryStandard => 'STANDARD';

  @override
  String get settings_deviceMemoryHigh => 'HIGH';

  @override
  String get settings_fetchingCovers => 'カバーを取得中...';

  @override
  String settings_coversResult(int ok, int failed) {
    return 'カバー: $ok成功、$failed失敗';
  }

  @override
  String settings_coversLoaded(int count) {
    return '$count件のカバーをロードしました！';
  }

  @override
  String get settings_noErrorLog => 'エラーログはありません';

  @override
  String get settings_configImported => '設定をインポートしました！';

  @override
  String get settings_controllerXboxFull => 'Xbox（A/B・X/Y入れ替え）';

  @override
  String get settings_controllerPlaystationFull => 'PlayStation (✕ ○ □ △)';

  @override
  String get settings_allCoversCached => '全カバーキャッシュ済み';

  @override
  String get settings_downloadCoverArt => '全ゲームのカバーをダウンロード';

  @override
  String settings_coverCacheInfo(String size, int count) {
    return '$size（$countキャッシュ済み）';
  }

  @override
  String settings_coversRemaining(int count, String size) {
    return '残り$count件（約$size MB）';
  }

  @override
  String settings_coversProgress(int completed, int total) {
    return '$completed / $totalゲーム';
  }

  @override
  String get configMode_title => 'コンソール設定';

  @override
  String get configMode_globalTitle => 'グローバル設定';

  @override
  String get configMode_noFolderSet => 'フォルダ未設定';

  @override
  String get configMode_notConfigured => '未設定';

  @override
  String get configMode_export => 'エクスポート';

  @override
  String get configMode_import => 'インポート';

  @override
  String get systemDetail_sectionStorage => 'ストレージ';

  @override
  String get systemDetail_selectRomFolder => 'ROMフォルダを選択';

  @override
  String get systemDetail_tapToChangeFolder => 'タップでフォルダ変更';

  @override
  String get systemDetail_sectionBehavior => '動作';

  @override
  String get systemDetail_autoExtractZips => 'ZIP自動展開';

  @override
  String get systemDetail_autoExtractEnabled => 'ZIP ROMはダウンロード後に展開されます';

  @override
  String get systemDetail_autoExtractDisabled => 'ROMはZIPのまま保存されます';

  @override
  String get systemDetail_autoSyncOnLaunch => '起動時自動同期';

  @override
  String get systemDetail_autoSyncEnabled => '自動同期（クールダウンあり）';

  @override
  String get systemDetail_autoSyncDisabled => 'Startメニューから手動のみ';

  @override
  String get systemDetail_sectionSources => 'ソース';

  @override
  String get sources_title => 'ソース';

  @override
  String get sources_noSourcesConfigured => 'ソースが設定されていません';

  @override
  String get sources_noSourcesYet => 'ソースがまだありません';

  @override
  String get sources_noSourcesDescription =>
      'RomMサーバーをペアリングしてゲームをダウンロードしましょう。 ';

  @override
  String get sources_addSource => 'ソースを追加';

  @override
  String get sources_whereDoGamesComeFrom => 'ゲームの入手先は？';

  @override
  String get sources_sourceTypeRomm => 'RomMサーバー';

  @override
  String get sources_sourceTypeRommHint => 'QRまたは8桁コードでペアリング';

  @override
  String get sources_sourceTypeRommLegacy => 'RomMログイン（古いサーバー）';

  @override
  String get sources_sourceTypeSmb => 'SMB共有';

  @override
  String get sources_sourceTypeFtp => 'FTPサーバー';

  @override
  String get sources_sourceTypeWeb => 'Webミラー';

  @override
  String get sources_sourceTypeWebHint => 'HTTPSディレクトリリスティング';

  @override
  String get sources_expired => 'EXPIRED';

  @override
  String get sources_borrowed => 'BORROWED';

  @override
  String get sources_off => 'OFF';

  @override
  String get sources_noPlatforms => 'プラットフォームなし';

  @override
  String get sources_rePair => '再ペアリング';

  @override
  String get sources_editMappings => 'マッピングを編集';

  @override
  String get sources_disable => '無効化';

  @override
  String get sources_enable => '有効化';

  @override
  String get manualSource_defaultNameSmb => 'マイNAS';

  @override
  String get manualSource_defaultNameFtp => 'マイFTP';

  @override
  String get manualSource_defaultNameWeb => 'Webミラー';

  @override
  String get manualSource_defaultNameOther => 'ソース';

  @override
  String get manualSource_name => '名前';

  @override
  String get manualSource_url => 'URL';

  @override
  String get manualSource_urlHint => 'https://example.com/roms';

  @override
  String get manualSource_host => 'Host';

  @override
  String get manualSource_hostHint => 'nas.local または 192.168.1.10';

  @override
  String get manualSource_port => 'Port';

  @override
  String get manualSource_share => '共有';

  @override
  String get manualSource_shareHint => 'roms';

  @override
  String get manualSource_usernameOptional => 'ユーザー名（任意）';

  @override
  String get manualSource_usernameHint => 'ゲストの場合は空白';

  @override
  String get manualSource_passwordOptional => 'パスワード（任意）';

  @override
  String get manualSource_nameRequired => '名前は必須です';

  @override
  String get manualSource_urlRequired => 'URLは必須です';

  @override
  String get manualSource_hostRequired => 'Hostは必須です';

  @override
  String get manualSource_shareRequired => '共有は必須です';

  @override
  String get manualSource_saveSource => 'ソースを保存';

  @override
  String get manualSource_smb => 'SMB';

  @override
  String get manualSource_ftp => 'FTP';

  @override
  String get manualSource_web => 'Web';

  @override
  String get manualSource_searchingNetwork => 'ネットワークを検索中…';

  @override
  String get manualSource_foundOnNetwork => 'ネットワーク上で見つかりました';

  @override
  String get sourceMappings_title => 'システムマッピング';

  @override
  String get sourceMappings_instruction =>
      'このソースが提供する各システムのリモートフォルダを入力してください。スキップする場合は空白のまま。';

  @override
  String get sourceMappings_save => 'マッピングを保存';

  @override
  String get library_title => 'ライブラリ';

  @override
  String get library_tabAll => 'すべて';

  @override
  String get library_tabInstalled => 'インストール済み';

  @override
  String get library_tabFavorites => 'お気に入り';

  @override
  String get library_sortSystem => 'システム順';

  @override
  String get library_sortManual => '手動並び替え';

  @override
  String get library_sortAZ => 'A-Z順';

  @override
  String get library_sortIndicatorAZ => 'A-Z';

  @override
  String get library_sortIndicatorBySystem => 'システム順';

  @override
  String get library_sortIndicatorManual => '手動';

  @override
  String get library_searchHint => 'ライブラリを検索...';

  @override
  String get library_zoomIn => 'ズームイン';

  @override
  String get library_zoomOut => 'ズームアウト';

  @override
  String get library_newShelf => '新規シェルフ';

  @override
  String get library_editShelf => 'シェルフを編集';

  @override
  String get library_addToShelf => 'シェルフに追加';

  @override
  String get library_removeFromShelf => 'シェルフから削除';

  @override
  String get library_reorderGames => 'ゲームを並び替え';

  @override
  String library_noResults(String query) {
    return '「$query」の結果なし';
  }

  @override
  String get library_tryShorterSearch => '短いキーワードで試してください';

  @override
  String get library_noInstalledGames => 'インストール済みゲームなし';

  @override
  String get library_downloadGamesToSee => 'ゲームをダウンロードするとここに表示されます';

  @override
  String get library_noFavoritesYet => 'お気に入りなし';

  @override
  String get library_pressFavoriteHint => 'SELECTでゲームをお気に入りに';

  @override
  String get library_noGamesInShelf => 'このシェルフにゲームなし';

  @override
  String get library_addGamesViaEditor => 'シェルフエディタでゲームを追加';

  @override
  String get library_noGamesInLibrary => 'ライブラリにゲームなし';

  @override
  String get library_gamesAfterSync => '同期完了後にゲームが表示されます';

  @override
  String get shelfEdit_title => 'シェルフを編集';

  @override
  String get shelfEdit_titleNew => '新規シェルフ';

  @override
  String get shelfEdit_nameSection => '名前';

  @override
  String get shelfEdit_shelfName => 'シェルフ名';

  @override
  String get shelfEdit_filterText => 'フィルターテキスト';

  @override
  String get shelfEdit_tapToSet => 'タップで設定...';

  @override
  String get shelfEdit_filterRules => 'フィルタールール';

  @override
  String get shelfEdit_resetManualOrder => '手動順をリセット';

  @override
  String get shelfEdit_saveButton => '保存';

  @override
  String get shelfEdit_deleteShelf => 'シェルフを削除';

  @override
  String get shelfEdit_anyText => '任意のテキスト';

  @override
  String get shelfEdit_allSystems => '全システム';

  @override
  String get shelfPicker_title => 'シェルフに追加';

  @override
  String get systemSelector_title => 'システムを選択';

  @override
  String get textInput_hint => 'テキストを入力...';

  @override
  String get textInput_ok => 'OK';

  @override
  String get gameListOverlay_hiddenGames => '非表示ゲーム';

  @override
  String get gameListOverlay_addedGames => '追加済みゲーム';

  @override
  String get gameListOverlay_restore => '復元';

  @override
  String get gameListOverlay_noGames => 'ゲームなし';

  @override
  String get gameListOverlay_clearAll => 'すべてクリア';

  @override
  String get home_allGames => '全ゲーム';

  @override
  String get home_library => 'ライブラリ';

  @override
  String get home_noConsoles => 'コンソールが設定されていません';

  @override
  String get home_pressStartForMenu => 'Startでメニュー';

  @override
  String get home_settings => '設定';

  @override
  String home_syncSystem(String system) {
    return '$systemを同期';
  }

  @override
  String get home_syncAll => 'すべて同期';

  @override
  String get home_lastSyncNever => '未同期';

  @override
  String get home_lastSyncJustNow => 'たった今同期';

  @override
  String home_lastSyncMinutes(int minutes) {
    return '$minutes分前に同期';
  }

  @override
  String home_lastSyncHours(int hours) {
    return '$hours時間前に同期';
  }

  @override
  String home_lastSyncDays(int days) {
    return '$days日前に同期';
  }

  @override
  String get common_exit => '終了';

  @override
  String gameList_gamesCount(int count) {
    return '$countゲーム';
  }

  @override
  String get gameList_offline => 'オフライン';

  @override
  String get gameList_zoomIn => 'ズームイン';

  @override
  String get gameList_zoomOut => 'ズームアウト';

  @override
  String get gameList_filterActive => 'フィルター（適用中）';

  @override
  String get gameList_filter => 'フィルター';

  @override
  String gameList_noGamesMatchSearch(String query) {
    return '\'$query\'に一致するゲームなし';
  }

  @override
  String get gameList_tryShorterSearch => '短いキーワードで試してください';

  @override
  String get gameList_noGamesMatchFilters => '現在のフィルターに一致するゲームなし';

  @override
  String get gameList_changeFilters => 'メニューでフィルターを変更またはリセット';

  @override
  String gameList_noRomsFound(String folder) {
    return '$folderにROMが見つかりません';
  }

  @override
  String get gameList_addRomFiles => 'このフォルダにROMファイルを追加して更新';

  @override
  String get gameList_couldNotLoadGames => 'ゲームを読み込めませんでした';

  @override
  String get gameList_checkConnection => '接続を確認してリトライしてください';

  @override
  String get gameList_errorLoadingGames => 'ゲーム読み込みエラー';

  @override
  String get gameList_gamesAppearShortly => 'ゲームはまもなく表示されます';

  @override
  String get gameList_syncingLibrary => 'ライブラリを同期中…';

  @override
  String get gameList_localFilesOnly => 'ローカルファイルのみ · プロバイダーを追加してダウンロード';

  @override
  String get gameList_pressMenuHint => ' + でメニュー';

  @override
  String filter_activeCount(int count) {
    return '$count件適用中';
  }

  @override
  String get shelfEdit_addFilter => '+ フィルター追加';

  @override
  String shelfEdit_hiddenGamesCount(int count) {
    return '非表示ゲーム（$count）';
  }

  @override
  String shelfEdit_addedGamesCount(int count) {
    return '追加済みゲーム（$count）';
  }

  @override
  String get shelfEdit_textHint => '← テキスト  システム →';

  @override
  String gameListOverlay_gameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countゲーム',
      one: '1ゲーム',
    );
    return '$_temp0';
  }

  @override
  String gameListOverlay_actionHint(String action) {
    return 'A: $action';
  }

  @override
  String systemSelector_selectedCount(int count) {
    return '$count件選択中';
  }

  @override
  String get filter_favoritesOnly => 'お気に入りのみ';

  @override
  String get filter_installedOnly => 'インストール済みのみ';

  @override
  String get filter_regions => 'リージョン';

  @override
  String get filter_languages => '言語';

  @override
  String get filter_title => 'フィルター';

  @override
  String get onboarding_welcomeTitle => 'R-Shopへようこそ';

  @override
  String get onboarding_welcomeSubtitle => 'ゲームの入手先は？';

  @override
  String get onboarding_pairQrTitle => 'QRでRomMをペアリング';

  @override
  String get onboarding_pairQrSubtitle => 'RomMサーバーのコードをスキャン';

  @override
  String get onboarding_legacyLoginTitle => 'RomMログイン（古いサーバー）';

  @override
  String get onboarding_legacyLoginSubtitle => 'RomM < 4.8用のユーザー名+パスワード';

  @override
  String get onboarding_addServerTitle => 'サーバーを追加';

  @override
  String get onboarding_addServerSubtitle => 'SMB、FTP、Webミラー — システムを手動マッピング';

  @override
  String get onboarding_localOnlyTitle => 'ローカルゲームのみ';

  @override
  String get onboarding_localOnlySubtitle => 'このデバイス上のROM';

  @override
  String get onboarding_working => '処理中…';

  @override
  String get onboarding_scanningFolders => 'ローカルROMフォルダをスキャン中…';

  @override
  String get onboarding_discoveringPlatforms => 'プラットフォームを検出中…';

  @override
  String get onboarding_savingSource => 'ソースを保存中…';

  @override
  String get onboarding_allSet => '準備完了！';

  @override
  String get onboarding_noSystems => 'システムがまだ設定されていません — 後から設定でソースを追加できます。';

  @override
  String onboarding_systemsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countシステムがブラウズ可能',
      one: '1システムがブラウズ可能',
    );
    return '$_temp0';
  }

  @override
  String get onboarding_jumpIn => 'はじめる';

  @override
  String get onboarding_jumpInSubtitle => 'ホーム画面を開いて同期開始';

  @override
  String get onboarding_retroachievements => 'RetroAchievements';

  @override
  String get onboarding_retroachievementsSubtitle => 'レトロゲームの実績をトラッキング';

  @override
  String get onboarding_exportConfig => '設定をエクスポート';

  @override
  String get onboarding_exportConfigSubtitle => '別のデバイスでこの設定を再利用';

  @override
  String get onboarding_importConfig => '設定をインポート';

  @override
  String get onboarding_configImported => '設定をインポートしました！';

  @override
  String onboarding_exportFailed(String error) {
    return 'エクスポート失敗: $error';
  }

  @override
  String onboarding_invalidConfig(String error) {
    return '無効な設定: $error';
  }

  @override
  String onboarding_failedToSave(String error) {
    return '保存失敗: $error';
  }

  @override
  String get onboarding_selectFolderPrompt => 'ROMを保存するフォルダを選んでください';

  @override
  String get onboarding_serverType => 'サーバータイプ';

  @override
  String get onboarding_folderExplanationTitle => 'ライブラリのパスを設定';

  @override
  String get onboarding_folderExplanationMessage =>
      'R-Shop はダウンロードしたゲームを保存するベースフォルダが必要です。ファイルの整理に役立ち、Android のフォルダ権限にも必要です。\n\n「ROMs」という名前のフォルダを作成して選択することをおすすめします。';

  @override
  String get onboarding_continueToPicker => 'フォルダを選択';

  @override
  String get onboarding_hangOn => 'ちょっと待ってね、接続テスト中...';

  @override
  String get onboarding_foundConsole =>
      'RomMサーバーでこのコンソールを見つけました！確認するか、別のものを選んでください。';

  @override
  String get onboarding_pickPlatform => 'RomMサーバーから対応するプラットフォームを選んでください。';

  @override
  String get onboarding_couldNotReach =>
      'RomMサーバーに接続できませんでした。URLを確認してリトライしてください。';

  @override
  String get onboarding_connectionGood => '接続 OK！このソースを保存できます。';

  @override
  String get onboarding_couldNotConnect => 'うーん、接続できませんでした。アドレスと認証情報を確認してください。';

  @override
  String get onboarding_whatKindOfSource => 'どのタイプのソースですか？接続タイプを選んでください。';

  @override
  String get onboarding_lookingGood => 'いい感じ！ソースを追加するか、準備ができたら完了を押してください。';

  @override
  String get onboarding_localCollection =>
      'ローカルコレクションです。ソースを追加してダウンロードするか、そのまま完了！';

  @override
  String get onboarding_addMoreSources => 'ROMの場所を知るために、少なくとも1つソースを追加してください。';

  @override
  String get onboarding_letsSetUp => 'コンソールをセットアップしましょう！任意のシステムを選んでください。';

  @override
  String get onboarding_romFolder => 'ROMフォルダ';

  @override
  String get onboarding_options => 'オプション';

  @override
  String get onboarding_autoExtractZips => 'ZIP ROMを自動展開';

  @override
  String get onboarding_autoSyncLabel => 'アプリ起動時に自動同期';

  @override
  String get onboarding_autoSyncEnabled => '自動同期（クールダウンあり）';

  @override
  String get onboarding_autoSyncDisabled => 'Startメニューから手動のみ';

  @override
  String get onboarding_selectFolder => 'フォルダを選択...';

  @override
  String get providerForm_addSource => 'ソースを追加';

  @override
  String get providerForm_editSource => 'ソースを編集';

  @override
  String get providerForm_url => 'URL';

  @override
  String get providerForm_urlPlaceholder => 'https://...';

  @override
  String get providerForm_path => 'パス';

  @override
  String get providerForm_pathPlaceholder => '/roms/nes/（任意）';

  @override
  String get providerForm_username => 'ユーザー名';

  @override
  String get providerForm_usernameOptional => '（任意）';

  @override
  String get providerForm_password => 'パスワード';

  @override
  String get providerForm_host => 'Host';

  @override
  String get providerForm_hostPlaceholder => '192.168.1.100';

  @override
  String get providerForm_port => 'Port';

  @override
  String get providerForm_share => '共有';

  @override
  String get providerForm_sharePlaceholder => 'roms';

  @override
  String get providerForm_domain => 'ドメイン';

  @override
  String get providerForm_domainOptional => '（任意）';

  @override
  String get providerForm_rommUrl => 'URL';

  @override
  String get providerForm_rommUrlPlaceholder => 'https://romm.example.com';

  @override
  String get providerForm_apiKey => 'API Key';

  @override
  String get providerForm_apiKeyOptional => '（任意）';

  @override
  String get providerForm_httpBlocked =>
      'ローカル以外のサーバーへのHTTPはブロックされます。HTTPSを使うか、設定で後から有効化してください。';

  @override
  String get providerForm_httpWarning => '認証情報がHTTPで暗号化なしに送信されます';

  @override
  String get providerForm_testingConnection => '接続テスト中...';

  @override
  String get providerForm_connectionSuccessful => '接続成功！';

  @override
  String get providerForm_fetchingPlatforms => 'プラットフォームを取得中...';

  @override
  String get providerForm_noPlatformsFound => 'このRomMサーバーにプラットフォームが見つかりません。';

  @override
  String get providerForm_platform => 'プラットフォーム';

  @override
  String get providerForm_pickPlatform => 'プラットフォームを選択...';

  @override
  String get providerForm_testAndSave => 'テストして保存';

  @override
  String get providerForm_connectionFailed => '接続失敗';

  @override
  String get providerForm_hostMissing => 'Host';

  @override
  String get providerForm_portMissing => 'Port';

  @override
  String get providerForm_pathMissing => 'パス';

  @override
  String get providerForm_shareMissing => '共有';

  @override
  String get providerForm_urlMissing => 'URL';

  @override
  String get rommLogin_title => 'RomMにログイン';

  @override
  String get rommLogin_name => '名前';

  @override
  String get rommLogin_nameDefault => 'マイRomM';

  @override
  String get rommLogin_serverUrl => 'サーバー URL';

  @override
  String get rommLogin_username => 'ユーザー名';

  @override
  String get rommLogin_usernameHint => 'admin';

  @override
  String get rommLogin_password => 'パスワード';

  @override
  String get rommLogin_passwordHint => '••••••••';

  @override
  String get rommLogin_nameRequired => '名前は必須です';

  @override
  String get rommLogin_serverUrlRequired => 'サーバーURLは必須です';

  @override
  String get rommLogin_credentialsRequired => 'ユーザー名またはパスワードが必要です';

  @override
  String get ra_title => 'RetroAchievements';

  @override
  String get ra_subtitle => 'レトロゲームの実績をトラッキング。 ';

  @override
  String get ra_usernameLabel => 'ユーザー名';

  @override
  String get ra_usernameHint => 'RAユーザー名';

  @override
  String get ra_apiKeyLabel => 'API Key';

  @override
  String get ra_apiKeyHint => 'retroachievements.orgから貼り付け';

  @override
  String get ra_usernameRequired => 'ユーザー名は必須です';

  @override
  String get ra_apiKeyRequired => 'API Keyは必須です';

  @override
  String get ra_connectionFailed => '接続失敗';

  @override
  String get ra_disconnect => '切断';

  @override
  String get ra_syncNow => '実績を今すぐ同期';

  @override
  String get ra_skipForNow => '今はスキップ';

  @override
  String get pairing_scanQrTitle => 'QRコードをスキャン';

  @override
  String get pairing_scanQrHint => 'QRコードをフレーム内にかざしてください';

  @override
  String get pairing_enterManually => 'コードを手動入力';

  @override
  String get pairing_invalidQr => '有効なRomMペアリングリンクではありません';

  @override
  String get pairing_manualTitle => '手動ペアリング';

  @override
  String get pairing_manualInstructions => 'RomMのWeb UIの以下でコードを生成してください: ';

  @override
  String get pairing_serverUrl => 'サーバー URL';

  @override
  String get pairing_pairingCode => 'ペアリングコード';

  @override
  String get pairing_pairingCodeHint => 'ABCD-1234';

  @override
  String get pairing_probingServer => 'サーバーを確認中…';

  @override
  String get pairing_serverNotReachable => 'サーバーに到達できないか、RomMインスタンスではありません';

  @override
  String get pairing_serverUrlRequired => 'サーバーURLとコードが必要です';

  @override
  String get pairing_successTitle => 'ペアリング成功';

  @override
  String get pairing_server => 'サーバー';

  @override
  String get pairing_token => 'トークン';

  @override
  String get pairing_userId => 'ユーザー ID';

  @override
  String get pairing_expiry => '有効期限';

  @override
  String get pairing_neverExpires => '無期限';

  @override
  String get pairing_alreadyExpired => '期限切れ';

  @override
  String get pairing_permissions => 'パーミッション';

  @override
  String get pairing_addServer => 'サーバーを追加';

  @override
  String get service_notificationTitle => 'R-Shop';

  @override
  String get service_channelName => 'ダウンロード';

  @override
  String get service_channelDescription => 'ゲームダウンロードの進捗を表示';

  @override
  String get service_downloadComplete => 'ダウンロード完了';

  @override
  String service_downloading(String details) {
    return 'ダウンロード中: $details';
  }

  @override
  String service_activeCount(int count) {
    return '$count件アクティブ';
  }

  @override
  String service_queuedCount(int count) {
    return '$count件キュー中';
  }

  @override
  String get sources_connectionRoute => '接続経路';

  @override
  String get sources_routeAuto => '自動選択';

  @override
  String get sources_routeAutoHint => '応答が最も速い経路を使用（ネットワークが変わると選び直します）';

  @override
  String get sources_routeInUse => '使用中';

  @override
  String get sources_routePinned => '固定中';

  @override
  String get sources_routeReachable => '接続可能';

  @override
  String get sources_routeNoAnswer => '応答なし';

  @override
  String get sources_routeChecking => '確認中…';

  @override
  String sources_routeLatencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String sources_routeAutoPicks(String route) {
    return '「$route」を使用します';
  }

  @override
  String get sources_routeAutoNoneReachable => '応答した経路がありません';

  @override
  String get sources_routeFastest => '最速';

  @override
  String get sources_routeReleasePin => '固定を解除して最速の経路を選び直します';

  @override
  String get sources_routeOwnLogin => '専用ログイン';

  @override
  String get sources_routeAuthTitle => 'この経路のログイン情報';

  @override
  String get sources_routeAuthHint =>
      '空欄にすると提供元のログイン情報を使います。このアドレスが別のログインを求める場合のみ入力してください。';

  @override
  String get sources_routeAuthInherited => '提供元のログイン情報を使用中';

  @override
  String get sources_routeAuthOwn => 'この経路は独自のログイン情報を使用します';

  @override
  String get sources_routeOnlyOne => 'この提供元の経路は1つだけです';

  @override
  String get sources_addRoute => '経路を追加';

  @override
  String get sources_editRoute => '経路を編集';

  @override
  String get sources_removeRoute => 'この経路を削除';

  @override
  String get sources_routeDuplicate => 'この提供元には同じアドレスの経路がすでにあります';

  @override
  String get sources_activeSource => '使用中';

  @override
  String get sources_switchSource => '提供元切替';

  @override
  String get sources_prevSource => '前の提供元';

  @override
  String get sources_nextSource => '次の提供元';

  @override
  String get sources_setFallback => 'バックアップ提供元';

  @override
  String get sources_fallbackNone => 'なし';

  @override
  String get sources_fallbackShort => 'バックアップ';

  @override
  String get sources_routeSameServerHint =>
      'すべての経路は同じサーバーにつながります。そのアドレスが別のログインを求める場合、経路ごとに専用のログイン情報を持たせられます。';

  @override
  String get sources_routeCannotRemoveLast => '最後の経路は削除できません';

  @override
  String sources_countLabel(num count) {
    return '$count 件のソース';
  }

  @override
  String get sources_useThisShort => 'この提供元を使用';

  @override
  String get sources_stopUsingShort => '使用をやめる';

  @override
  String get sources_removeConfirmTitle => 'ソースを削除しますか？';

  @override
  String sources_removeConfirmMessage(String name) {
    return '「$name」を削除しますか？このソースの一覧はライブラリから消えますが、すでに端末にダウンロードしたゲームは残ります。';
  }

  @override
  String get sources_groupBadge => 'グループ';

  @override
  String get sources_groupCreate => '他のソースとグループにする…';

  @override
  String get sources_groupCreateHint => '実際には同じサーバーである 2 つのアドレス向け';

  @override
  String get sources_groupPickMember => 'グループにするソースを選択';

  @override
  String get sources_groupSameTypeOnly => '同じ種類のソースだけをグループにできます';

  @override
  String get sources_groupNoCandidates => '同じ種類のソースが他にありません';

  @override
  String get sources_groupManage => 'グループ設定';

  @override
  String get sources_groupRename => 'グループ名を変更';

  @override
  String get sources_groupNameLabel => 'グループ名';

  @override
  String get sources_groupModeTitle => 'どれを使うか';

  @override
  String get sources_groupModeAuto => '先に応答したもの';

  @override
  String get sources_groupModeAutoHint => '順序を管理する必要はありません。先に応答したアドレスが最も早く使えます';

  @override
  String get sources_groupModeOrdered => '自分の順序';

  @override
  String get sources_groupModeOrderedHint => '順序どおりに、最初に応答したものを使用';

  @override
  String get sources_groupPreferred => '第 1 候補';

  @override
  String get sources_groupAddMember => 'ソースを追加';

  @override
  String get sources_groupLeave => 'グループから外す';

  @override
  String sources_groupLeaveConfirm(String name) {
    return '「$name」の一覧は残らず、同期し直す必要があります。共有の一覧はグループに残ります。';
  }

  @override
  String get sources_groupLeaveTitle => 'グループから外しますか？';

  @override
  String get sources_groupDissolve => 'グループを解散';

  @override
  String sources_groupDissolveConfirm(String name) {
    return '共有の一覧は「$name」に残り、他のソースは同期し直します。';
  }

  @override
  String get sources_groupDissolveTitle => 'グループを解散しますか？';

  @override
  String sources_groupMembersCount(int count) {
    return '$count 個のソース';
  }

  @override
  String sources_groupUsing(String name) {
    return '「$name」を使用中';
  }

  @override
  String get sources_moveUp => '上へ移動';

  @override
  String get sources_moveDown => '下へ移動';

  @override
  String get sources_routeOrdered => '自分の順序';

  @override
  String get sources_routeOrderedHint => '順序どおりに、最初に応答した経路を使用';

  @override
  String get sources_reorderHint => '上下キーで位置を移動し、もう一度押すと完了';

  @override
  String get sources_groupMemberHint => '▶ でグループから除外、[A] で並べ替え';

  @override
  String get sources_routeRowHint => '▶ で右のアイコンへ：並べ替え・編集・削除';

  @override
  String get sources_routeUse => 'この経路を使用';

  @override
  String get sources_routeLock => 'この経路に固定';

  @override
  String get sources_routeUnlock => '固定を解除';

  @override
  String sources_removeRouteConfirm(String name) {
    return '「$name」を削除しますか？このソースのゲーム一覧は残り、消えるのはアドレスだけです。';
  }
}
