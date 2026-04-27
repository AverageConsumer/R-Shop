// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class LDe extends L {
  LDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'R-Shop';

  @override
  String get settings_language => 'Sprache';

  @override
  String get settings_languageSystem => 'Systemstandard';

  @override
  String get common_back => 'Zurück';

  @override
  String get common_close => 'Schließen';

  @override
  String get common_cancel => 'Abbrechen';

  @override
  String get common_cancelUpper => 'ABBRECHEN';

  @override
  String get common_select => 'Wählen';

  @override
  String get common_search => 'Suche';

  @override
  String get common_searchEllipsis => 'Suchen...';

  @override
  String get common_menu => 'Menü';

  @override
  String get common_navigate => 'Navigation';

  @override
  String get common_toggle => 'Umschalten';

  @override
  String get common_clear => 'Leeren';

  @override
  String get common_done => 'Fertig';

  @override
  String get common_save => 'Speichern';

  @override
  String get common_connect => 'Verbinden';

  @override
  String get common_retry => 'Erneut';

  @override
  String get common_remove => 'Entfernen';

  @override
  String get common_favorite => 'Favorit';

  @override
  String get common_unfavorite => 'Entfernen';

  @override
  String get common_downloads => 'Downloads';

  @override
  String get common_installed => 'INSTALLIERT';

  @override
  String get common_move => 'Bewegen';

  @override
  String get common_drop => 'Ablegen';

  @override
  String get common_grab => 'Greifen';

  @override
  String get confirm_deleteTitle => 'ROM löschen?';

  @override
  String confirm_deleteMessage(String gameTitle) {
    return 'Willst du diese Version von $gameTitle wirklich löschen?';
  }

  @override
  String get confirm_exitTitle => 'App beenden?';

  @override
  String get confirm_exitMessage => 'Willst du Retro eShop wirklich beenden?';

  @override
  String get confirm_resetTitle => 'App zurücksetzen?';

  @override
  String get confirm_resetMessage =>
      'Alle Einstellungen werden gelöscht und die Ersteinrichtung startet neu.';

  @override
  String get confirm_deleteButton => 'LÖSCHEN';

  @override
  String get confirm_exitButton => 'BEENDEN';

  @override
  String get confirm_resetButton => 'RESET';

  @override
  String get confirm_gamepadHint => '← → Wählen   A Bestätigen   B Abbrechen';

  @override
  String get exit_title => 'APP BEENDEN';

  @override
  String get exit_message => 'Bist du sicher, dass du beenden willst?';

  @override
  String get exit_confirmButton => 'BEENDEN';

  @override
  String get exit_cancelButton => 'BLEIBEN';

  @override
  String get downloads_title => 'Downloads';

  @override
  String downloads_activeCount(int count) {
    return '$count aktiv';
  }

  @override
  String get downloads_noDownloads => 'Keine Downloads';

  @override
  String get downloads_sectionDownloading => 'Aktiv';

  @override
  String get downloads_sectionQueued => 'Warteschlange';

  @override
  String get downloads_sectionComplete => 'Fertig';

  @override
  String get downloads_actionCancel => 'Abbrechen';

  @override
  String get downloads_actionRetry => 'Erneut';

  @override
  String get downloads_actionRemove => 'Entfernen';

  @override
  String get downloads_actionClear => 'Löschen';

  @override
  String get downloads_clearDone => 'Fertige löschen';

  @override
  String get downloadStatus_downloading => 'Lädt herunter...';

  @override
  String get downloadStatus_extracting => 'Entpacken...';

  @override
  String get downloadStatus_installing => 'Installieren...';

  @override
  String get downloadStatus_waiting => 'Wartet...';

  @override
  String get downloadStatus_complete => 'Fertig';

  @override
  String get downloadStatus_cancelled => 'Abgebrochen';

  @override
  String get downloadStatus_failed => 'Fehler';

  @override
  String storage_free(String size) {
    return '$size frei';
  }

  @override
  String storage_veryLow(String freeSpace) {
    return 'Sehr wenig Speicher: $freeSpace';
  }

  @override
  String storage_gettingLow(String freeSpace) {
    return 'Speicher wird knapp: $freeSpace';
  }

  @override
  String sync_progress(int completed, int total) {
    return 'Sync $completed/$total';
  }

  @override
  String sync_singleSystemFailed(String system) {
    return '$system-Sync fehlgeschlagen';
  }

  @override
  String sync_multipleSystemsFailed(int count) {
    return '$count Systeme fehlgeschlagen';
  }

  @override
  String sync_raProgress(int completed, int total) {
    return 'Achievements $completed/$total';
  }

  @override
  String get sync_raFailed => 'RA-Sync fehlgeschlagen';

  @override
  String get toast_addedToQueue => 'Zur Warteschlange hinzugefügt';

  @override
  String get toast_configRecovered =>
      'Konfiguration aus Backup wiederhergestellt';

  @override
  String gameCard_variantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Varianten',
      one: '1 Variante',
    );
    return '$_temp0';
  }

  @override
  String get gameDetail_achievements => 'Achievements';

  @override
  String get gameDetail_mastered => 'GEMEISTERT';

  @override
  String get gameDetail_noAchievementsFound => 'Keine Achievements gefunden';

  @override
  String get gameDetail_retroachievements => 'RETROACHIEVEMENTS';

  @override
  String get gameDetail_romVerified => 'ROM verifiziert';

  @override
  String get gameDetail_incompatibleRom => 'Inkompatibles ROM';

  @override
  String get gameDetail_gameHasAchievements => 'Spiel hat Achievements';

  @override
  String get gameDetail_viewAchievements => 'Achievements ansehen';

  @override
  String get gameDetail_versions => 'VERSIONEN';

  @override
  String get gameDetail_download => 'DOWNLOAD';

  @override
  String get gameDetail_adding => 'WIRD HINZUGEFÜGT...';

  @override
  String get gameDetail_queued => 'WARTESCHLANGE';

  @override
  String get gameDetail_extracting => 'ENTPACKEN...';

  @override
  String get gameDetail_delete => 'LÖSCHEN';

  @override
  String get gameDetail_manageFiles => 'DATEIEN VERWALTEN';

  @override
  String get gameDetail_unavailable => 'NICHT VERFÜGBAR';

  @override
  String get gameDetail_installedLabel => 'Installiert';

  @override
  String get gameDetail_notFound => 'Nicht gefunden';

  @override
  String get gameDetail_details => 'Details';

  @override
  String get gameDetail_screenshots => 'Screenshots';

  @override
  String get gameDetail_otherVersions => 'Andere Versionen';

  @override
  String get gameDetail_readMore => 'Mehr lesen...';

  @override
  String get gameDetail_showLess => 'Weniger';

  @override
  String get gameDetail_standard => 'Standard';

  @override
  String get gameDetail_franchise => 'Franchise';

  @override
  String get gameDetail_gameModes => 'Spielmodi';

  @override
  String get gameDetail_perspective => 'Perspektive';

  @override
  String get gameDetail_ageRating => 'Altersfreigabe';

  @override
  String get gameDetail_themes => 'Themen';

  @override
  String get gameDetail_fileTags => 'DATEI-TAGS';

  @override
  String get gameDetail_tagVersion => 'Version';

  @override
  String get gameDetail_tagBuild => 'Build';

  @override
  String get gameDetail_tagDisc => 'Disc';

  @override
  String get gameDetail_tagQuality => 'Qualität';

  @override
  String get gameDetail_tagInfo => 'Info';

  @override
  String get gameDetail_tagTechnical => 'Technik';

  @override
  String get gameDetail_gameInfo => 'Spielinfo';

  @override
  String get gameDetail_showTitle => 'Titel anzeigen';

  @override
  String get gameDetail_showFilename => 'Dateiname anzeigen';

  @override
  String gameDetail_fromProvider(String provider) {
    return 'von $provider';
  }

  @override
  String get gameDetail_addToShelf => 'Zum Regal';

  @override
  String get gameDetail_removeFromShelf => 'Aus Regal entfernen';

  @override
  String get gameDetail_removeFromShelfTitle => 'AUS REGAL ENTFERNEN';

  @override
  String get gameDetail_gameNotInstalled => 'Spiel ist nicht installiert';

  @override
  String get gameDetail_couldNotShare =>
      'Spieldatei konnte nicht geteilt werden';

  @override
  String get gameDetail_pressAPickVersion => 'A drücken für Version';

  @override
  String get gameDetail_pressAManage => 'A drücken zum Verwalten';

  @override
  String get gameDetail_pressADownload => 'A drücken zum Download';

  @override
  String gameDetail_errorPrefix(String error) {
    return 'Fehler: $error';
  }

  @override
  String get settings_title => 'EINSTELLUNGEN';

  @override
  String get settings_tabGeneral => 'Allgemein';

  @override
  String get settings_tabAudio => 'Audio';

  @override
  String get settings_tabAdvanced => 'Erweitert';

  @override
  String get settings_tabAbout => 'Info';

  @override
  String get settings_previousTab => 'Vorheriger Tab';

  @override
  String get settings_nextTab => 'Nächster Tab';

  @override
  String get settings_resetApp => 'App zurücksetzen';

  @override
  String get settings_resetDialogTitle => 'APP ZURÜCKSETZEN';

  @override
  String get settings_resetDialogMessage =>
      'Alle Einstellungen werden gelöscht und die Ersteinrichtung startet neu.';

  @override
  String get settings_resetDialogConfirm => 'RESET';

  @override
  String get settings_resetDialogCancel => 'ABBRECHEN';

  @override
  String get settings_sectionLibrary => 'Bibliothek';

  @override
  String get settings_sectionDisplay => 'Anzeige';

  @override
  String get settings_mySources => 'Meine Quellen';

  @override
  String get settings_mySourcesSubtitle => 'RomM, SMB, FTP-Server verwalten';

  @override
  String get settings_consoleSettings => 'Konsoleneinstellungen';

  @override
  String get settings_consoleSettingsSubtitle =>
      'Ordnerpfade, Entpacken, Systemoptionen';

  @override
  String get settings_retroAchievements => 'RetroAchievements';

  @override
  String get settings_retroAchievementsSubtitle =>
      'Achievement-Tracking und ROM-Verifizierung';

  @override
  String get settings_homeLayout => 'Startseiten-Layout';

  @override
  String get settings_homeLayoutGrid => 'Rasteransicht';

  @override
  String get settings_homeLayoutCarousel => 'Horizontales Karussell';

  @override
  String get settings_hideEmptyConsoles => 'Leere Konsolen ausblenden';

  @override
  String get settings_hideEmptyConsolesSubtitle =>
      'Nur Systeme mit Spielen anzeigen';

  @override
  String get settings_controllerButtons => 'Controller-Tasten';

  @override
  String get settings_controllerNintendo => 'Nintendo (Standard)';

  @override
  String get settings_controllerXbox => 'XBOX';

  @override
  String get settings_controllerPs => 'PS';

  @override
  String get settings_controllerNin => 'NIN';

  @override
  String get settings_sectionFeedback => 'Feedback';

  @override
  String get settings_vibration => 'Vibration';

  @override
  String get settings_vibrationSubtitle => 'Bei Tastendruck vibrieren';

  @override
  String get settings_soundEffects => 'Soundeffekte';

  @override
  String get settings_soundEffectsSubtitle => 'Töne bei Menüaktionen';

  @override
  String get settings_sectionVolume => 'Lautstärke';

  @override
  String get settings_music => 'Musik';

  @override
  String get settings_musicSubtitle => 'Hintergrundmusik';

  @override
  String get settings_effects => 'Effekte';

  @override
  String get settings_effectsSubtitle => 'Interface-Soundeffekte';

  @override
  String get settings_sectionDownloads => 'Downloads';

  @override
  String get settings_simultaneousDownloads => 'Gleichzeitige Downloads';

  @override
  String get settings_simultaneousDownloadsSubtitle =>
      'Wie viele Dateien parallel laden';

  @override
  String get settings_downloadAllCovers => 'ALLE COVER LADEN';

  @override
  String get settings_downloadingCovers => 'COVER WERDEN GELADEN...';

  @override
  String get settings_sectionSync => 'Sync';

  @override
  String get settings_syncTimeout => 'Sync-Timeout';

  @override
  String get settings_syncTimeoutSubtitle => 'Wartezeit pro Server';

  @override
  String get settings_autoSyncInterval => 'Auto-Sync-Intervall';

  @override
  String get settings_autoSyncIntervalSubtitle =>
      'Mindestzeit zwischen automatischen Syncs';

  @override
  String get settings_sectionDebug => 'Debug';

  @override
  String get settings_allowInsecure => 'Unsichere Verbindungen';

  @override
  String get settings_allowInsecureSubtitle =>
      'HTTP für Server ohne HTTPS erlauben';

  @override
  String get settings_exportErrorLog => 'Fehlerlog exportieren';

  @override
  String get settings_exportErrorLogSubtitle =>
      'Crash-Log zur Fehlerbehebung teilen';

  @override
  String get settings_sectionInfo => 'Info';

  @override
  String get settings_sectionLinks => 'Links';

  @override
  String get settings_github => 'GitHub';

  @override
  String get settings_githubSubtitle => 'Quellcode auf GitHub ansehen';

  @override
  String get settings_issues => 'Issues';

  @override
  String get settings_issuesSubtitle =>
      'Fehler melden oder Features vorschlagen';

  @override
  String get settings_tagline => 'INTENSIV, AGGRESSIV, MUTIG';

  @override
  String get settings_deviceMemoryLow => 'NIEDRIG';

  @override
  String get settings_deviceMemoryStandard => 'STANDARD';

  @override
  String get settings_deviceMemoryHigh => 'HOCH';

  @override
  String get settings_fetchingCovers => 'Cover werden geladen...';

  @override
  String settings_coversResult(int ok, int failed) {
    return 'Cover: $ok OK, $failed fehlgeschlagen';
  }

  @override
  String settings_coversLoaded(int count) {
    return '$count Cover geladen!';
  }

  @override
  String get settings_noErrorLog => 'Kein Fehlerlog vorhanden';

  @override
  String get settings_configImported => 'Konfiguration importiert!';

  @override
  String get settings_controllerXboxFull => 'Xbox (A/B & X/Y getauscht)';

  @override
  String get settings_controllerPlaystationFull => 'PlayStation (✕ ○ □ △)';

  @override
  String get settings_allCoversCached => 'Alle Cover gecacht';

  @override
  String get settings_downloadCoverArt => 'Cover für alle Spiele herunterladen';

  @override
  String settings_coverCacheInfo(String size, int count) {
    return '$size ($count gecacht)';
  }

  @override
  String settings_coversRemaining(int count, String size) {
    return '$count verbleibend (~$size MB)';
  }

  @override
  String settings_coversProgress(int completed, int total) {
    return '$completed / $total Spiele';
  }

  @override
  String get configMode_title => 'KONSOLENEINSTELLUNGEN';

  @override
  String get configMode_globalTitle => 'GLOBALE EINSTELLUNGEN';

  @override
  String get configMode_noFolderSet => 'Kein Ordner gewählt';

  @override
  String get configMode_notConfigured => 'Nicht konfiguriert';

  @override
  String get configMode_export => 'Exportieren';

  @override
  String get configMode_import => 'Importieren';

  @override
  String get systemDetail_sectionStorage => 'Speicher';

  @override
  String get systemDetail_selectRomFolder => 'ROM-Ordner wählen';

  @override
  String get systemDetail_tapToChangeFolder => 'Tippen zum Ändern';

  @override
  String get systemDetail_sectionBehavior => 'Verhalten';

  @override
  String get systemDetail_autoExtractZips => 'ZIPs automatisch entpacken';

  @override
  String get systemDetail_autoExtractEnabled =>
      'Gezippte ROMs werden nach Download entpackt';

  @override
  String get systemDetail_autoExtractDisabled =>
      'ROMs bleiben nach Download gezippt';

  @override
  String get systemDetail_autoSyncOnLaunch => 'Auto-Sync beim Start';

  @override
  String get systemDetail_autoSyncEnabled =>
      'Synchronisiert automatisch (mit Cooldown)';

  @override
  String get systemDetail_autoSyncDisabled => 'Nur manuell über Startmenü';

  @override
  String get systemDetail_sectionSources => 'Quellen';

  @override
  String get sources_title => 'QUELLEN';

  @override
  String get sources_noSourcesConfigured => 'Keine Quellen konfiguriert';

  @override
  String get sources_noSourcesYet => 'Noch keine Quellen';

  @override
  String get sources_noSourcesDescription =>
      'Verbinde einen RomM-Server, um Spiele herunterzuladen. ';

  @override
  String get sources_addSource => 'Quelle hinzufügen';

  @override
  String get sources_whereDoGamesComeFrom => 'Woher kommen deine Spiele?';

  @override
  String get sources_sourceTypeRomm => 'RomM-Server';

  @override
  String get sources_sourceTypeRommHint =>
      'Per QR oder 8-stelligem Code koppeln';

  @override
  String get sources_sourceTypeRommLegacy => 'RomM-Login (ältere Server)';

  @override
  String get sources_sourceTypeSmb => 'SMB-Freigabe';

  @override
  String get sources_sourceTypeFtp => 'FTP-Server';

  @override
  String get sources_sourceTypeWeb => 'Web-Mirror';

  @override
  String get sources_sourceTypeWebHint => 'HTTPS-Verzeichnisliste';

  @override
  String get sources_expired => 'ABGELAUFEN';

  @override
  String get sources_borrowed => 'GELIEHEN';

  @override
  String get sources_off => 'AUS';

  @override
  String get sources_noPlatforms => 'Keine Plattformen';

  @override
  String get sources_rePair => 'Erneut koppeln';

  @override
  String get sources_editMappings => 'Zuordnungen';

  @override
  String get sources_disable => 'Deaktivieren';

  @override
  String get sources_enable => 'Aktivieren';

  @override
  String get manualSource_defaultNameSmb => 'Mein NAS';

  @override
  String get manualSource_defaultNameFtp => 'Mein FTP';

  @override
  String get manualSource_defaultNameWeb => 'Web-Mirror';

  @override
  String get manualSource_defaultNameOther => 'Quelle';

  @override
  String get manualSource_name => 'Name';

  @override
  String get manualSource_url => 'URL';

  @override
  String get manualSource_urlHint => 'https://example.com/roms';

  @override
  String get manualSource_host => 'Host';

  @override
  String get manualSource_hostHint => 'nas.local oder 192.168.1.10';

  @override
  String get manualSource_port => 'Port';

  @override
  String get manualSource_share => 'Freigabe';

  @override
  String get manualSource_shareHint => 'roms';

  @override
  String get manualSource_usernameOptional => 'Benutzername (optional)';

  @override
  String get manualSource_usernameHint => 'leer für Gastzugang';

  @override
  String get manualSource_passwordOptional => 'Passwort (optional)';

  @override
  String get manualSource_nameRequired => 'Name ist erforderlich';

  @override
  String get manualSource_urlRequired => 'URL ist erforderlich';

  @override
  String get manualSource_hostRequired => 'Host ist erforderlich';

  @override
  String get manualSource_shareRequired => 'Freigabe ist erforderlich';

  @override
  String get manualSource_saveSource => 'Quelle speichern';

  @override
  String get manualSource_smb => 'SMB';

  @override
  String get manualSource_ftp => 'FTP';

  @override
  String get manualSource_web => 'Web';

  @override
  String get manualSource_searchingNetwork => 'Netzwerk wird durchsucht…';

  @override
  String get manualSource_foundOnNetwork => 'In deinem Netzwerk gefunden';

  @override
  String get sourceMappings_title => 'Systemzuordnungen';

  @override
  String get sourceMappings_instruction =>
      'Gib den Remote-Ordner für jedes System ein, das diese Quelle bedienen soll. Leer lassen zum Überspringen.';

  @override
  String get sourceMappings_save => 'Zuordnungen speichern';

  @override
  String get library_title => 'BIBLIOTHEK';

  @override
  String get library_tabAll => 'Alle';

  @override
  String get library_tabInstalled => 'Installiert';

  @override
  String get library_tabFavorites => 'Favoriten';

  @override
  String get library_sortSystem => 'Nach System';

  @override
  String get library_sortManual => 'Manuell';

  @override
  String get library_sortAZ => 'Sortieren A-Z';

  @override
  String get library_sortIndicatorAZ => 'A-Z';

  @override
  String get library_sortIndicatorBySystem => 'SYSTEM';

  @override
  String get library_sortIndicatorManual => 'MANUELL';

  @override
  String get library_searchHint => 'Bibliothek durchsuchen...';

  @override
  String get library_zoomIn => 'Vergrößern';

  @override
  String get library_zoomOut => 'Verkleinern';

  @override
  String get library_newShelf => 'Neues Regal';

  @override
  String get library_editShelf => 'Regal bearbeiten';

  @override
  String get library_addToShelf => 'Zum Regal';

  @override
  String get library_removeFromShelf => 'Aus Regal';

  @override
  String get library_reorderGames => 'Spiele sortieren';

  @override
  String library_noResults(String query) {
    return 'Keine Ergebnisse für \"$query\"';
  }

  @override
  String get library_tryShorterSearch => 'Probiere einen kürzeren Suchbegriff';

  @override
  String get library_noInstalledGames => 'Keine installierten Spiele';

  @override
  String get library_downloadGamesToSee =>
      'Lade Spiele herunter, um sie hier zu sehen';

  @override
  String get library_noFavoritesYet => 'Noch keine Favoriten';

  @override
  String get library_pressFavoriteHint =>
      'Drücke SELECT bei einem Spiel zum Favorisieren';

  @override
  String get library_noGamesInShelf => 'Keine Spiele in diesem Regal';

  @override
  String get library_addGamesViaEditor =>
      'Füge Spiele über den Regal-Editor hinzu';

  @override
  String get library_noGamesInLibrary => 'Keine Spiele in der Bibliothek';

  @override
  String get library_gamesAfterSync => 'Spiele erscheinen nach dem Sync';

  @override
  String get shelfEdit_title => 'REGAL BEARBEITEN';

  @override
  String get shelfEdit_titleNew => 'NEUES REGAL';

  @override
  String get shelfEdit_nameSection => 'NAME';

  @override
  String get shelfEdit_shelfName => 'Regalname';

  @override
  String get shelfEdit_filterText => 'Filtertext';

  @override
  String get shelfEdit_tapToSet => 'Tippen zum Setzen...';

  @override
  String get shelfEdit_filterRules => 'FILTERREGELN';

  @override
  String get shelfEdit_resetManualOrder => 'Manuelle Sortierung zurücksetzen';

  @override
  String get shelfEdit_saveButton => 'SPEICHERN';

  @override
  String get shelfEdit_deleteShelf => 'REGAL LÖSCHEN';

  @override
  String get shelfEdit_anyText => 'Beliebiger Text';

  @override
  String get shelfEdit_allSystems => 'Alle Systeme';

  @override
  String get shelfPicker_title => 'ZUM REGAL HINZUFÜGEN';

  @override
  String get systemSelector_title => 'SYSTEME WÄHLEN';

  @override
  String get textInput_hint => 'Text eingeben...';

  @override
  String get textInput_ok => 'OK';

  @override
  String get gameListOverlay_hiddenGames => 'VERSTECKTE SPIELE';

  @override
  String get gameListOverlay_addedGames => 'HINZUGEFÜGTE SPIELE';

  @override
  String get gameListOverlay_restore => 'Wiederherstellen';

  @override
  String get gameListOverlay_noGames => 'Keine Spiele';

  @override
  String get gameListOverlay_clearAll => 'Alle löschen';

  @override
  String get home_allGames => 'ALLE SPIELE';

  @override
  String get home_library => 'Bibliothek';

  @override
  String get home_noConsoles => 'Keine Konsolen konfiguriert';

  @override
  String get home_pressStartForMenu => 'Drücke Start für Menü';

  @override
  String get home_settings => 'Einstellungen';

  @override
  String home_syncSystem(String system) {
    return '$system synchronisieren';
  }

  @override
  String get home_syncAll => 'Alles synchronisieren';

  @override
  String get home_lastSyncNever => 'Nie synchronisiert';

  @override
  String get home_lastSyncJustNow => 'Gerade synchronisiert';

  @override
  String home_lastSyncMinutes(int minutes) {
    return 'Vor $minutes Min. synchronisiert';
  }

  @override
  String home_lastSyncHours(int hours) {
    return 'Vor $hours Std. synchronisiert';
  }

  @override
  String home_lastSyncDays(int days) {
    return 'Vor $days Tagen synchronisiert';
  }

  @override
  String get common_exit => 'Beenden';

  @override
  String gameList_gamesCount(int count) {
    return '$count Spiele';
  }

  @override
  String get gameList_offline => 'Offline';

  @override
  String get gameList_zoomIn => 'Vergrößern';

  @override
  String get gameList_zoomOut => 'Verkleinern';

  @override
  String get gameList_filterActive => 'Filter (aktiv)';

  @override
  String get gameList_filter => 'Filter';

  @override
  String gameList_noGamesMatchSearch(String query) {
    return 'Keine Spiele für \'$query\'';
  }

  @override
  String get gameList_tryShorterSearch => 'Probiere einen kürzeren Suchbegriff';

  @override
  String get gameList_noGamesMatchFilters =>
      'Keine Spiele mit aktuellem Filter';

  @override
  String get gameList_changeFilters =>
      'Filter im Menü ändern oder zurücksetzen';

  @override
  String gameList_noRomsFound(String folder) {
    return 'Keine ROMs in $folder gefunden';
  }

  @override
  String get gameList_addRomFiles => 'Füge ROM-Dateien hinzu und aktualisiere';

  @override
  String get gameList_couldNotLoadGames =>
      'Spiele konnten nicht geladen werden';

  @override
  String get gameList_checkConnection =>
      'Prüfe deine Verbindung und versuche es erneut';

  @override
  String get gameList_errorLoadingGames => 'Fehler beim Laden';

  @override
  String get gameList_gamesAppearShortly => 'Spiele erscheinen in Kürze';

  @override
  String get gameList_syncingLibrary => 'Bibliothek wird synchronisiert…';

  @override
  String get gameList_localFilesOnly => 'Lokal';

  @override
  String get gameList_pressMenuHint => 'Drücke  +  für Menü';

  @override
  String filter_activeCount(int count) {
    return '$count aktiv';
  }

  @override
  String get shelfEdit_addFilter => '+ FILTER HINZUFÜGEN';

  @override
  String shelfEdit_hiddenGamesCount(int count) {
    return 'Versteckte Spiele ($count)';
  }

  @override
  String shelfEdit_addedGamesCount(int count) {
    return 'Hinzugefügte Spiele ($count)';
  }

  @override
  String get shelfEdit_textHint => '← Text  Sys →';

  @override
  String gameListOverlay_gameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Spiele',
      one: '1 Spiel',
    );
    return '$_temp0';
  }

  @override
  String gameListOverlay_actionHint(String action) {
    return 'A: $action';
  }

  @override
  String systemSelector_selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get filter_favoritesOnly => 'Nur Favoriten';

  @override
  String get filter_installedOnly => 'Nur Installierte';

  @override
  String get filter_regions => 'REGIONEN';

  @override
  String get filter_languages => 'SPRACHEN';

  @override
  String get filter_title => 'FILTER';

  @override
  String get onboarding_welcomeTitle => 'Willkommen bei R-Shop';

  @override
  String get onboarding_welcomeSubtitle => 'Woher kommen deine Spiele?';

  @override
  String get onboarding_pairQrTitle => 'RomM per QR koppeln';

  @override
  String get onboarding_pairQrSubtitle =>
      'Scanne einen Code von deinem RomM-Server';

  @override
  String get onboarding_legacyLoginTitle => 'RomM-Login (ältere Server)';

  @override
  String get onboarding_legacyLoginSubtitle =>
      'Benutzername + Passwort für RomM < 4.8';

  @override
  String get onboarding_addServerTitle => 'Eigenen Server hinzufügen';

  @override
  String get onboarding_addServerSubtitle =>
      'SMB, FTP oder Web-Mirror — Systeme manuell zuordnen';

  @override
  String get onboarding_localOnlyTitle => 'Nur lokale Spiele';

  @override
  String get onboarding_localOnlySubtitle => 'ROMs bereits auf diesem Gerät';

  @override
  String get onboarding_working => 'Arbeite…';

  @override
  String get onboarding_scanningFolders => 'Scanne lokale ROM-Ordner…';

  @override
  String get onboarding_discoveringPlatforms => 'Entdecke Plattformen…';

  @override
  String get onboarding_savingSource => 'Speichere Quelle…';

  @override
  String get onboarding_allSet => 'Alles bereit';

  @override
  String get onboarding_noSystems =>
      'Noch keine Systeme konfiguriert — du kannst später in den Einstellungen Quellen hinzufügen.';

  @override
  String onboarding_systemsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Systeme bereit',
      one: '1 System bereit',
    );
    return '$_temp0';
  }

  @override
  String get onboarding_jumpIn => 'Los geht\'s';

  @override
  String get onboarding_jumpInSubtitle => 'Startseite öffnen und Sync starten';

  @override
  String get onboarding_retroachievements => 'RetroAchievements';

  @override
  String get onboarding_retroachievementsSubtitle =>
      'Verfolge deine Retro-Achievements';

  @override
  String get onboarding_exportConfig => 'Konfiguration exportieren';

  @override
  String get onboarding_exportConfigSubtitle =>
      'Setup auf anderem Gerät wiederverwenden';

  @override
  String get onboarding_importConfig => 'Konfiguration importieren';

  @override
  String get onboarding_configImported => 'Konfiguration importiert!';

  @override
  String onboarding_exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String onboarding_invalidConfig(String error) {
    return 'Ungültige Konfiguration: $error';
  }

  @override
  String onboarding_failedToSave(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get onboarding_selectFolderPrompt =>
      'Wähle den Ordner, in dem ROMs gespeichert werden sollen';

  @override
  String get onboarding_serverType => 'Servertyp';

  @override
  String get onboarding_hangOn => 'Moment, teste die Verbindung...';

  @override
  String get onboarding_foundConsole =>
      'Diese Konsole habe ich auf deinem RomM-Server gefunden! Bestätige oder wähle eine andere.';

  @override
  String get onboarding_pickPlatform =>
      'Wähle die passende Plattform von deinem RomM-Server.';

  @override
  String get onboarding_couldNotReach =>
      'Dein RomM-Server ist nicht erreichbar. Prüfe die URL und versuche es erneut.';

  @override
  String get onboarding_connectionGood =>
      'Verbindung steht! Du kannst diese Quelle jetzt speichern.';

  @override
  String get onboarding_couldNotConnect =>
      'Hmm, konnte nicht verbinden. Überprüfe Adresse und Zugangsdaten.';

  @override
  String get onboarding_whatKindOfSource =>
      'Was für eine Quelle ist das? Wähle den Verbindungstyp.';

  @override
  String get onboarding_lookingGood =>
      'Sieht gut aus! Füge mehr Quellen hinzu oder drücke Fertig.';

  @override
  String get onboarding_localCollection =>
      'Das ist eine lokale Sammlung. Füge eine Quelle hinzu oder drücke einfach Fertig!';

  @override
  String get onboarding_addMoreSources =>
      'Jetzt mindestens eine Quelle hinzufügen, damit ich weiß, wo die ROMs sind.';

  @override
  String get onboarding_letsSetUp =>
      'Lass uns deine Konsolen einrichten! Wähle ein System zum Starten.';

  @override
  String get onboarding_romFolder => 'ROM-ORDNER';

  @override
  String get onboarding_options => 'OPTIONEN';

  @override
  String get onboarding_autoExtractZips =>
      'Gezippte ROMs automatisch entpacken';

  @override
  String get onboarding_autoSyncLabel => 'Auto-Sync beim App-Start';

  @override
  String get onboarding_autoSyncEnabled =>
      'Synchronisiert automatisch (mit Cooldown)';

  @override
  String get onboarding_autoSyncDisabled => 'Nur manuell über Startmenü';

  @override
  String get onboarding_selectFolder => 'Ordner wählen...';

  @override
  String get providerForm_addSource => 'Quelle hinzufügen';

  @override
  String get providerForm_editSource => 'Quelle bearbeiten';

  @override
  String get providerForm_url => 'URL';

  @override
  String get providerForm_urlPlaceholder => 'https://...';

  @override
  String get providerForm_path => 'Pfad';

  @override
  String get providerForm_pathPlaceholder => '/roms/nes/ (optional)';

  @override
  String get providerForm_username => 'Benutzername';

  @override
  String get providerForm_usernameOptional => '(optional)';

  @override
  String get providerForm_password => 'Passwort';

  @override
  String get providerForm_host => 'Host';

  @override
  String get providerForm_hostPlaceholder => '192.168.1.100';

  @override
  String get providerForm_port => 'Port';

  @override
  String get providerForm_share => 'Freigabe';

  @override
  String get providerForm_sharePlaceholder => 'roms';

  @override
  String get providerForm_domain => 'Domain';

  @override
  String get providerForm_domainOptional => '(optional)';

  @override
  String get providerForm_rommUrl => 'URL';

  @override
  String get providerForm_rommUrlPlaceholder => 'https://romm.example.com';

  @override
  String get providerForm_apiKey => 'API Key';

  @override
  String get providerForm_apiKeyOptional => '(optional)';

  @override
  String get providerForm_httpBlocked =>
      'HTTP zu nicht-lokalen Servern ist blockiert. Nutze HTTPS oder aktiviere es später in den Einstellungen.';

  @override
  String get providerForm_httpWarning =>
      'Zugangsdaten werden unverschlüsselt über HTTP gesendet';

  @override
  String get providerForm_testingConnection => 'Teste Verbindung...';

  @override
  String get providerForm_connectionSuccessful => 'Verbindung erfolgreich!';

  @override
  String get providerForm_fetchingPlatforms => 'Lade Plattformen...';

  @override
  String get providerForm_noPlatformsFound =>
      'Keine Plattformen auf diesem RomM-Server gefunden.';

  @override
  String get providerForm_platform => 'PLATTFORM';

  @override
  String get providerForm_pickPlatform => 'Plattform wählen...';

  @override
  String get providerForm_testAndSave => 'Testen & Speichern';

  @override
  String get providerForm_connectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get providerForm_hostMissing => 'Host';

  @override
  String get providerForm_portMissing => 'Port';

  @override
  String get providerForm_pathMissing => 'Pfad';

  @override
  String get providerForm_shareMissing => 'Freigabe';

  @override
  String get providerForm_urlMissing => 'URL';

  @override
  String get rommLogin_title => 'Bei RomM anmelden';

  @override
  String get rommLogin_name => 'Name';

  @override
  String get rommLogin_nameDefault => 'Mein RomM';

  @override
  String get rommLogin_serverUrl => 'Server-URL';

  @override
  String get rommLogin_username => 'Benutzername';

  @override
  String get rommLogin_usernameHint => 'admin';

  @override
  String get rommLogin_password => 'Passwort';

  @override
  String get rommLogin_passwordHint => '••••••••';

  @override
  String get rommLogin_nameRequired => 'Name ist erforderlich';

  @override
  String get rommLogin_serverUrlRequired => 'Server-URL ist erforderlich';

  @override
  String get rommLogin_credentialsRequired =>
      'Benutzername oder Passwort erforderlich';

  @override
  String get ra_title => 'RetroAchievements';

  @override
  String get ra_subtitle => 'Verfolge deine Retro-Achievements. ';

  @override
  String get ra_usernameLabel => 'Benutzername';

  @override
  String get ra_usernameHint => 'dein RA-Benutzername';

  @override
  String get ra_apiKeyLabel => 'API Key';

  @override
  String get ra_apiKeyHint => 'Von retroachievements.org einfügen';

  @override
  String get ra_usernameRequired => 'Benutzername ist erforderlich';

  @override
  String get ra_apiKeyRequired => 'API Key ist erforderlich';

  @override
  String get ra_connectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get ra_disconnect => 'Trennen';

  @override
  String get ra_syncNow => 'Achievements jetzt synchronisieren';

  @override
  String get ra_skipForNow => 'Jetzt überspringen';

  @override
  String get pairing_scanQrTitle => 'QR-Code scannen';

  @override
  String get pairing_scanQrHint => 'Halte den QR-Code in den Rahmen';

  @override
  String get pairing_enterManually => 'Code manuell eingeben';

  @override
  String get pairing_invalidQr =>
      'QR-Code ist kein gültiger RomM-Kopplungslink';

  @override
  String get pairing_manualTitle => 'Manuelle Kopplung';

  @override
  String get pairing_manualInstructions =>
      'Generiere den Code in deiner RomM-Weboberfläche unter ';

  @override
  String get pairing_serverUrl => 'Server-URL';

  @override
  String get pairing_pairingCode => 'Kopplungscode';

  @override
  String get pairing_pairingCodeHint => 'ABCD-1234';

  @override
  String get pairing_probingServer => 'Server wird geprüft…';

  @override
  String get pairing_serverNotReachable =>
      'Server nicht erreichbar oder keine RomM-Instanz';

  @override
  String get pairing_serverUrlRequired =>
      'Server-URL und Code sind erforderlich';

  @override
  String get pairing_successTitle => 'Kopplung erfolgreich';

  @override
  String get pairing_server => 'Server';

  @override
  String get pairing_token => 'Token';

  @override
  String get pairing_userId => 'Benutzer-ID';

  @override
  String get pairing_expiry => 'Ablauf';

  @override
  String get pairing_neverExpires => 'Läuft nie ab';

  @override
  String get pairing_alreadyExpired => 'Bereits abgelaufen';

  @override
  String get pairing_permissions => 'BERECHTIGUNGEN';

  @override
  String get pairing_addServer => 'Server hinzufügen';

  @override
  String get service_notificationTitle => 'R-Shop';

  @override
  String get service_channelName => 'Downloads';

  @override
  String get service_channelDescription =>
      'Zeigt Fortschritt beim Herunterladen von Spielen';

  @override
  String get service_downloadComplete => 'Downloads abgeschlossen';

  @override
  String service_downloading(String details) {
    return 'Laden: $details';
  }

  @override
  String service_activeCount(int count) {
    return '$count aktiv';
  }

  @override
  String service_queuedCount(int count) {
    return '$count in Warteschlange';
  }
}
