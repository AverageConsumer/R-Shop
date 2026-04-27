// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LFr extends L {
  LFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'R-Shop';

  @override
  String get settings_language => 'Langue';

  @override
  String get settings_languageSystem => 'Par défaut du système';

  @override
  String get common_back => 'Retour';

  @override
  String get common_close => 'Fermer';

  @override
  String get common_cancel => 'Annuler';

  @override
  String get common_cancelUpper => 'ANNULER';

  @override
  String get common_select => 'Choisir';

  @override
  String get common_search => 'Chercher';

  @override
  String get common_searchEllipsis => 'Chercher...';

  @override
  String get common_menu => 'Menu';

  @override
  String get common_navigate => 'Naviguer';

  @override
  String get common_toggle => 'Basculer';

  @override
  String get common_clear => 'Effacer';

  @override
  String get common_done => 'Terminé';

  @override
  String get common_save => 'Enregistrer';

  @override
  String get common_connect => 'Connecter';

  @override
  String get common_retry => 'Réessayer';

  @override
  String get common_remove => 'Retirer';

  @override
  String get common_favorite => 'Favori';

  @override
  String get common_share => 'Partager';

  @override
  String get common_unfavorite => 'Retirer favori';

  @override
  String get common_downloads => 'Téléchargements';

  @override
  String get common_installed => 'INSTALLÉ';

  @override
  String get common_move => 'Déplacer';

  @override
  String get common_drop => 'Poser';

  @override
  String get common_grab => 'Saisir';

  @override
  String get confirm_deleteTitle => 'Supprimer la ROM ?';

  @override
  String confirm_deleteMessage(String gameTitle) {
    return 'Tu veux vraiment supprimer cette version de $gameTitle ?';
  }

  @override
  String get confirm_exitTitle => 'Quitter ?';

  @override
  String get confirm_exitMessage => 'Tu veux vraiment quitter Retro eShop ?';

  @override
  String get confirm_resetTitle => 'Réinitialiser ?';

  @override
  String get confirm_resetMessage =>
      'Tu reviendras à l\'écran de configuration initiale.';

  @override
  String get confirm_deleteButton => 'SUPPRIMER';

  @override
  String get confirm_exitButton => 'QUITTER';

  @override
  String get confirm_resetButton => 'RÉINITIALISER';

  @override
  String get confirm_gamepadHint => '← → Choisir   A Confirmer   B Annuler';

  @override
  String get exit_title => 'QUITTER L\'APP';

  @override
  String get exit_message => 'Tu veux vraiment quitter ?';

  @override
  String get exit_confirmButton => 'QUITTER';

  @override
  String get exit_cancelButton => 'RESTER';

  @override
  String get downloads_title => 'Téléchargements';

  @override
  String downloads_activeCount(int count) {
    return '$count actifs';
  }

  @override
  String get downloads_noDownloads => 'Aucun téléchargement';

  @override
  String get downloads_sectionDownloading => 'En cours';

  @override
  String get downloads_sectionQueued => 'En attente';

  @override
  String get downloads_sectionComplete => 'Terminés';

  @override
  String get downloads_actionCancel => 'Annuler';

  @override
  String get downloads_actionRetry => 'Réessayer';

  @override
  String get downloads_actionRemove => 'Retirer';

  @override
  String get downloads_actionClear => 'Effacer';

  @override
  String get downloads_clearDone => 'Effacer terminés';

  @override
  String get downloadStatus_downloading => 'Téléchargement...';

  @override
  String get downloadStatus_extracting => 'Extraction...';

  @override
  String get downloadStatus_installing => 'Installation...';

  @override
  String get downloadStatus_waiting => 'En attente...';

  @override
  String get downloadStatus_complete => 'Terminé';

  @override
  String get downloadStatus_cancelled => 'Annulé';

  @override
  String get downloadStatus_failed => 'Échoué';

  @override
  String storage_free(String size) {
    return '$size libre';
  }

  @override
  String storage_veryLow(String freeSpace) {
    return 'Stockage très bas : $freeSpace';
  }

  @override
  String storage_gettingLow(String freeSpace) {
    return 'Stockage faible : $freeSpace';
  }

  @override
  String sync_progress(int completed, int total) {
    return 'Synchro $completed/$total';
  }

  @override
  String sync_singleSystemFailed(String system) {
    return 'Synchro de $system échouée';
  }

  @override
  String sync_multipleSystemsFailed(int count) {
    return '$count systèmes n\'ont pas pu se synchroniser';
  }

  @override
  String sync_raProgress(int completed, int total) {
    return 'Succès $completed/$total';
  }

  @override
  String get sync_raFailed => 'Synchro RA échouée';

  @override
  String get toast_addedToQueue => 'Ajouté à la file';

  @override
  String get toast_configRecovered => 'Config récupérée depuis la sauvegarde';

  @override
  String gameCard_variantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variantes',
      one: '1 variante',
    );
    return '$_temp0';
  }

  @override
  String get gameDetail_achievements => 'Succès';

  @override
  String get gameDetail_mastered => 'MAÎTRISÉ';

  @override
  String get gameDetail_noAchievementsFound => 'Aucun succès trouvé';

  @override
  String get gameDetail_noMetadata => 'Aucune info supplémentaire';

  @override
  String get gameDetail_noMetadataHint =>
      'Synchronise avec RetroAchievements ou une source de métadonnées pour descriptions, captures, etc.';

  @override
  String get gameDetail_retroachievements => 'RETROACHIEVEMENTS';

  @override
  String get gameDetail_romVerified => 'ROM vérifiée';

  @override
  String get gameDetail_incompatibleRom => 'ROM incompatible';

  @override
  String get gameDetail_gameHasAchievements => 'A des succès';

  @override
  String get gameDetail_viewAchievements => 'Voir les succès';

  @override
  String get gameDetail_versions => 'VERSIONS';

  @override
  String get gameDetail_download => 'TÉLÉCHARGER';

  @override
  String get gameDetail_adding => 'AJOUT...';

  @override
  String get gameDetail_queued => 'EN ATTENTE';

  @override
  String get gameDetail_extracting => 'EXTRACTION...';

  @override
  String get gameDetail_delete => 'SUPPRIMER';

  @override
  String get gameDetail_manageFiles => 'GÉRER FICHIERS';

  @override
  String get gameDetail_unavailable => 'INDISPONIBLE';

  @override
  String get gameDetail_installedLabel => 'Installé';

  @override
  String get gameDetail_notFound => 'Introuvable';

  @override
  String get gameDetail_details => 'Détails';

  @override
  String get gameDetail_screenshots => 'Captures';

  @override
  String get gameDetail_otherVersions => 'Autres versions';

  @override
  String get gameDetail_readMore => 'Lire la suite...';

  @override
  String get gameDetail_showLess => 'Voir moins';

  @override
  String get gameDetail_standard => 'Standard';

  @override
  String get gameDetail_franchise => 'Franchise';

  @override
  String get gameDetail_gameModes => 'Modes de jeu';

  @override
  String get gameDetail_perspective => 'Perspective';

  @override
  String get gameDetail_ageRating => 'Classification';

  @override
  String get gameDetail_themes => 'Thèmes';

  @override
  String get gameDetail_fileTags => 'TAGS FICHIER';

  @override
  String get gameDetail_tagVersion => 'Version';

  @override
  String get gameDetail_tagBuild => 'Build';

  @override
  String get gameDetail_tagDisc => 'Disque';

  @override
  String get gameDetail_tagQuality => 'Qualité';

  @override
  String get gameDetail_tagInfo => 'Info';

  @override
  String get gameDetail_tagTechnical => 'Technique';

  @override
  String get gameDetail_gameInfo => 'Info du jeu';

  @override
  String get gameDetail_showTitle => 'Afficher titre';

  @override
  String get gameDetail_showFilename => 'Afficher fichier';

  @override
  String gameDetail_fromProvider(String provider) {
    return 'de $provider';
  }

  @override
  String get gameDetail_addToShelf => 'Ajouter à l\'étagère';

  @override
  String get gameDetail_removeFromShelf => 'Retirer de l\'étagère';

  @override
  String get gameDetail_removeFromShelfTitle => 'RETIRER DE L\'ÉTAGÈRE';

  @override
  String get gameDetail_gameNotInstalled => 'Le jeu n\'est pas installé';

  @override
  String get gameDetail_couldNotShare => 'Impossible de partager le fichier';

  @override
  String get gameDetail_pressAPickVersion =>
      'Appuie sur A pour choisir une version';

  @override
  String get gameDetail_pressAManage => 'Appuie sur A pour gérer';

  @override
  String get gameDetail_pressADownload => 'Appuie sur A pour télécharger';

  @override
  String gameDetail_errorPrefix(String error) {
    return 'Erreur : $error';
  }

  @override
  String get settings_title => 'PARAMÈTRES';

  @override
  String get settings_tabGeneral => 'Général';

  @override
  String get settings_tabAudio => 'Audio';

  @override
  String get settings_tabAdvanced => 'Avancé';

  @override
  String get settings_tabAbout => 'À propos';

  @override
  String get settings_previousTab => 'Onglet précédent';

  @override
  String get settings_nextTab => 'Onglet suivant';

  @override
  String get settings_resetApp => 'Réinitialiser l\'app';

  @override
  String get settings_resetDialogTitle => 'RÉINITIALISER L\'APP';

  @override
  String get settings_resetDialogMessage =>
      'Tous les paramètres seront supprimés et la configuration redémarrera.';

  @override
  String get settings_resetDialogConfirm => 'RÉINITIALISER';

  @override
  String get settings_resetDialogCancel => 'ANNULER';

  @override
  String get settings_sectionLibrary => 'Bibliothèque';

  @override
  String get settings_sectionDisplay => 'Affichage';

  @override
  String get settings_mySources => 'Mes sources';

  @override
  String get settings_mySourcesSubtitle =>
      'Ajouter ou gérer des serveurs RomM, SMB, FTP';

  @override
  String get settings_consoleSettings => 'Paramètres consoles';

  @override
  String get settings_consoleSettingsSubtitle =>
      'Dossiers, extraction, options par système';

  @override
  String get settings_retroAchievements => 'RetroAchievements';

  @override
  String get settings_retroAchievementsSubtitle =>
      'Suivi des succès et vérification des ROMs';

  @override
  String get settings_homeLayout => 'Disposition accueil';

  @override
  String get settings_homeLayoutGrid => 'Grille';

  @override
  String get settings_homeLayoutCarousel => 'Carrousel horizontal';

  @override
  String get settings_hideEmptyConsoles => 'Masquer consoles vides';

  @override
  String get settings_hideEmptyConsolesSubtitle =>
      'N\'afficher que les systèmes avec des jeux';

  @override
  String get settings_controllerButtons => 'Boutons manette';

  @override
  String get settings_controllerNintendo => 'Nintendo (par défaut)';

  @override
  String get settings_controllerXbox => 'XBOX';

  @override
  String get settings_controllerPs => 'PS';

  @override
  String get settings_controllerNin => 'NIN';

  @override
  String get settings_sectionFeedback => 'Retour';

  @override
  String get settings_vibration => 'Vibration';

  @override
  String get settings_vibrationSubtitle =>
      'Vibrer quand on appuie sur les boutons';

  @override
  String get settings_soundEffects => 'Effets sonores';

  @override
  String get settings_soundEffectsSubtitle => 'Sons pour les actions du menu';

  @override
  String get settings_sectionVolume => 'Volume';

  @override
  String get settings_music => 'Musique';

  @override
  String get settings_musicSubtitle => 'Musique d\'ambiance';

  @override
  String get settings_effects => 'Effets';

  @override
  String get settings_effectsSubtitle => 'Effets sonores d\'interface';

  @override
  String get settings_sectionDownloads => 'Téléchargements';

  @override
  String get settings_simultaneousDownloads => 'Téléchargements simultanés';

  @override
  String get settings_simultaneousDownloadsSubtitle =>
      'Combien de fichiers à la fois';

  @override
  String get settings_downloadAllCovers => 'TÉLÉCHARGER LES JAQUETTES';

  @override
  String get settings_downloadingCovers => 'TÉLÉCHARGEMENT DES JAQUETTES...';

  @override
  String get settings_sectionSync => 'Synchronisation';

  @override
  String get settings_syncTimeout => 'Délai d\'attente';

  @override
  String get settings_syncTimeoutSubtitle => 'Combien attendre par serveur';

  @override
  String get settings_autoSyncInterval => 'Intervalle auto-sync';

  @override
  String get settings_autoSyncIntervalSubtitle =>
      'Temps minimum entre les synchros auto';

  @override
  String get settings_sectionDebug => 'Débogage';

  @override
  String get settings_allowInsecure => 'Connexions non sécurisées';

  @override
  String get settings_allowInsecureSubtitle =>
      'Autoriser HTTP pour les serveurs sans HTTPS';

  @override
  String get settings_exportErrorLog => 'Exporter le log d\'erreurs';

  @override
  String get settings_exportErrorLogSubtitle =>
      'Partager le log pour le diagnostic';

  @override
  String get settings_sectionInfo => 'Info';

  @override
  String get settings_sectionLinks => 'Liens';

  @override
  String get settings_github => 'GitHub';

  @override
  String get settings_githubSubtitle => 'Voir le code source sur GitHub';

  @override
  String get settings_issues => 'Problèmes';

  @override
  String get settings_issuesSubtitle =>
      'Signaler des bugs ou demander des fonctionnalités';

  @override
  String get settings_tagline => 'INTENSIV, AGGRESSIV, MUTIG';

  @override
  String get settings_deviceMemoryLow => 'LOW';

  @override
  String get settings_deviceMemoryStandard => 'STANDARD';

  @override
  String get settings_deviceMemoryHigh => 'HIGH';

  @override
  String get settings_fetchingCovers => 'Récupération des jaquettes...';

  @override
  String settings_coversResult(int ok, int failed) {
    return 'Jaquettes : $ok ok, $failed échouées';
  }

  @override
  String settings_coversLoaded(int count) {
    return '$count jaquettes chargées !';
  }

  @override
  String get settings_noErrorLog => 'Pas de log d\'erreurs';

  @override
  String get settings_configImported => 'Config importée !';

  @override
  String get settings_controllerXboxFull => 'Xbox (A/B et X/Y inversés)';

  @override
  String get settings_controllerPlaystationFull => 'PlayStation (✕ ○ □ △)';

  @override
  String get settings_allCoversCached => 'Toutes les jaquettes en cache';

  @override
  String get settings_downloadCoverArt =>
      'Télécharger les jaquettes de tous les jeux';

  @override
  String settings_coverCacheInfo(String size, int count) {
    return '$size ($count en cache)';
  }

  @override
  String settings_coversRemaining(int count, String size) {
    return '$count restantes (~$size Mo)';
  }

  @override
  String settings_coversProgress(int completed, int total) {
    return '$completed / $total jeux';
  }

  @override
  String get configMode_title => 'PARAMÈTRES CONSOLES';

  @override
  String get configMode_globalTitle => 'PARAMÈTRES GLOBAUX';

  @override
  String get configMode_noFolderSet => 'Aucun dossier défini';

  @override
  String get configMode_notConfigured => 'Non configuré';

  @override
  String get configMode_export => 'Exporter';

  @override
  String get configMode_import => 'Importer';

  @override
  String get systemDetail_sectionStorage => 'Stockage';

  @override
  String get systemDetail_selectRomFolder => 'Choisir le dossier ROMs';

  @override
  String get systemDetail_tapToChangeFolder => 'Touche pour changer le dossier';

  @override
  String get systemDetail_sectionBehavior => 'Comportement';

  @override
  String get systemDetail_autoExtractZips => 'Auto-extraire les ZIPs';

  @override
  String get systemDetail_autoExtractEnabled =>
      'Les ROMs zippées sont extraites après téléchargement';

  @override
  String get systemDetail_autoExtractDisabled => 'Les ROMs restent zippées';

  @override
  String get systemDetail_autoSyncOnLaunch => 'Auto-sync au lancement';

  @override
  String get systemDetail_autoSyncEnabled =>
      'Synchronise automatiquement (respecte le cooldown)';

  @override
  String get systemDetail_autoSyncDisabled =>
      'Synchronise manuellement via le menu Start';

  @override
  String get systemDetail_sectionSources => 'Sources';

  @override
  String get sources_title => 'SOURCES';

  @override
  String get sources_noSourcesConfigured => 'Aucune source configurée';

  @override
  String get sources_noSourcesYet => 'Pas encore de sources';

  @override
  String get sources_noSourcesDescription =>
      'Associe un serveur RomM pour télécharger des jeux. ';

  @override
  String get sources_addSource => 'Ajouter une source';

  @override
  String get sources_whereDoGamesComeFrom => 'D\'où viennent tes jeux ?';

  @override
  String get sources_sourceTypeRomm => 'Serveur RomM';

  @override
  String get sources_sourceTypeRommHint =>
      'Associer via QR ou code à 8 chiffres';

  @override
  String get sources_sourceTypeRommLegacy => 'Login RomM (anciens serveurs)';

  @override
  String get sources_sourceTypeSmb => 'Partage SMB';

  @override
  String get sources_sourceTypeFtp => 'Serveur FTP';

  @override
  String get sources_sourceTypeWeb => 'Miroir Web';

  @override
  String get sources_sourceTypeWebHint => 'Listing de répertoire HTTPS';

  @override
  String get sources_expired => 'EXPIRÉ';

  @override
  String get sources_borrowed => 'EMPRUNTÉ';

  @override
  String get sources_off => 'OFF';

  @override
  String get sources_noPlatforms => 'Aucune plateforme';

  @override
  String get sources_rePair => 'Ré-associer';

  @override
  String get sources_editMappings => 'Modifier les mappings';

  @override
  String get sources_disable => 'Désactiver';

  @override
  String get sources_enable => 'Activer';

  @override
  String get manualSource_defaultNameSmb => 'Mon NAS';

  @override
  String get manualSource_defaultNameFtp => 'Mon FTP';

  @override
  String get manualSource_defaultNameWeb => 'Miroir Web';

  @override
  String get manualSource_defaultNameOther => 'Source';

  @override
  String get manualSource_name => 'Nom';

  @override
  String get manualSource_url => 'URL';

  @override
  String get manualSource_urlHint => 'https://exemple.com/roms';

  @override
  String get manualSource_host => 'Host';

  @override
  String get manualSource_hostHint => 'nas.local ou 192.168.1.10';

  @override
  String get manualSource_port => 'Port';

  @override
  String get manualSource_share => 'Share';

  @override
  String get manualSource_shareHint => 'roms';

  @override
  String get manualSource_usernameOptional => 'Utilisateur (optionnel)';

  @override
  String get manualSource_usernameHint => 'laisser vide pour invité';

  @override
  String get manualSource_passwordOptional => 'Mot de passe (optionnel)';

  @override
  String get manualSource_nameRequired => 'Le nom est requis';

  @override
  String get manualSource_urlRequired => 'L\'URL est requise';

  @override
  String get manualSource_hostRequired => 'L\'hôte est requis';

  @override
  String get manualSource_shareRequired => 'Le partage est requis';

  @override
  String get manualSource_saveSource => 'Enregistrer la source';

  @override
  String get manualSource_smb => 'SMB';

  @override
  String get manualSource_ftp => 'FTP';

  @override
  String get manualSource_web => 'Web';

  @override
  String get manualSource_searchingNetwork => 'Recherche sur le réseau…';

  @override
  String get manualSource_foundOnNetwork => 'Trouvé sur ton réseau';

  @override
  String get sourceMappings_title => 'Mappings système';

  @override
  String get sourceMappings_instruction =>
      'Indique le dossier distant pour chaque système que cette source doit servir. Laisse vide pour ignorer.';

  @override
  String get sourceMappings_save => 'Enregistrer les mappings';

  @override
  String get library_title => 'BIBLIOTHÈQUE';

  @override
  String get library_tabAll => 'Tout';

  @override
  String get library_tabInstalled => 'Installés';

  @override
  String get library_tabFavorites => 'Favoris';

  @override
  String get library_sortSystem => 'Trier par système';

  @override
  String get library_sortManual => 'Tri manuel';

  @override
  String get library_sortAZ => 'Trier A-Z';

  @override
  String get library_sortIndicatorAZ => 'A-Z';

  @override
  String get library_sortIndicatorBySystem => 'PAR SYSTÈME';

  @override
  String get library_sortIndicatorManual => 'MANUEL';

  @override
  String get library_searchHint => 'Chercher dans la bibli...';

  @override
  String get library_zoomIn => 'Zoom +';

  @override
  String get library_zoomOut => 'Zoom -';

  @override
  String get library_newShelf => 'Nouvelle étagère';

  @override
  String get library_editShelf => 'Modifier l\'étagère';

  @override
  String get library_addToShelf => 'Ajouter à l\'étagère';

  @override
  String get library_removeFromShelf => 'Retirer de l\'étagère';

  @override
  String get library_reorderGames => 'Réorganiser les jeux';

  @override
  String library_noResults(String query) {
    return 'Aucun résultat pour \"$query\"';
  }

  @override
  String get library_tryShorterSearch => 'Essaie un terme plus court';

  @override
  String get library_noInstalledGames => 'Aucun jeu installé';

  @override
  String get library_downloadGamesToSee =>
      'Télécharge des jeux pour les voir ici';

  @override
  String get library_noFavoritesYet => 'Pas encore de favoris';

  @override
  String get library_pressFavoriteHint =>
      'Appuie sur SELECT pour mettre en favori';

  @override
  String get library_noGamesInShelf => 'Aucun jeu dans cette étagère';

  @override
  String get library_addGamesViaEditor => 'Ajoute des jeux via l\'éditeur';

  @override
  String get library_noGamesInLibrary => 'Aucun jeu dans la bibliothèque';

  @override
  String get library_gamesAfterSync => 'Les jeux apparaîtront après la synchro';

  @override
  String get shelfEdit_title => 'MODIFIER L\'ÉTAGÈRE';

  @override
  String get shelfEdit_titleNew => 'NOUVELLE ÉTAGÈRE';

  @override
  String get shelfEdit_nameSection => 'NOM';

  @override
  String get shelfEdit_shelfName => 'Nom de l\'étagère';

  @override
  String get shelfEdit_filterText => 'Texte de filtre';

  @override
  String get shelfEdit_tapToSet => 'Touche pour définir...';

  @override
  String get shelfEdit_filterRules => 'RÈGLES DE FILTRE';

  @override
  String get shelfEdit_resetManualOrder => 'Réinitialiser l\'ordre manuel';

  @override
  String get shelfEdit_saveButton => 'ENREGISTRER';

  @override
  String get shelfEdit_deleteShelf => 'SUPPRIMER L\'ÉTAGÈRE';

  @override
  String get shelfEdit_anyText => 'Tout texte';

  @override
  String get shelfEdit_allSystems => 'Tous les systèmes';

  @override
  String get shelfPicker_title => 'AJOUTER À L\'ÉTAGÈRE';

  @override
  String get systemSelector_title => 'CHOISIR LES SYSTÈMES';

  @override
  String get textInput_hint => 'Saisir du texte...';

  @override
  String get textInput_ok => 'OK';

  @override
  String get gameListOverlay_hiddenGames => 'JEUX MASQUÉS';

  @override
  String get gameListOverlay_addedGames => 'JEUX AJOUTÉS';

  @override
  String get gameListOverlay_restore => 'Restaurer';

  @override
  String get gameListOverlay_noGames => 'Aucun jeu';

  @override
  String get gameListOverlay_clearAll => 'Tout effacer';

  @override
  String get home_allGames => 'TOUS LES JEUX';

  @override
  String get home_library => 'Bibliothèque';

  @override
  String get home_noConsoles => 'Aucune console configurée';

  @override
  String get home_pressStartForMenu => 'Appuie sur Start pour le menu';

  @override
  String get home_settings => 'Paramètres';

  @override
  String home_syncSystem(String system) {
    return 'Synchroniser $system';
  }

  @override
  String get home_syncAll => 'Tout synchroniser';

  @override
  String get home_lastSyncNever => 'Jamais synchronisé';

  @override
  String get home_lastSyncJustNow => 'Synchronisé à l\'instant';

  @override
  String home_lastSyncMinutes(int minutes) {
    return 'Synchronisé il y a ${minutes}min';
  }

  @override
  String home_lastSyncHours(int hours) {
    return 'Synchronisé il y a ${hours}h';
  }

  @override
  String home_lastSyncDays(int days) {
    return 'Synchronisé il y a ${days}j';
  }

  @override
  String get common_exit => 'Quitter';

  @override
  String gameList_gamesCount(int count) {
    return '$count Jeux';
  }

  @override
  String get gameList_offline => 'Hors ligne';

  @override
  String get gameList_zoomIn => 'Zoom +';

  @override
  String get gameList_zoomOut => 'Zoom -';

  @override
  String get gameList_filterActive => 'Filtre (actif)';

  @override
  String get gameList_filter => 'Filtre';

  @override
  String gameList_noGamesMatchSearch(String query) {
    return 'Aucun jeu pour \'$query\'';
  }

  @override
  String get gameList_tryShorterSearch => 'Essaie un terme plus court';

  @override
  String get gameList_noGamesMatchFilters =>
      'Aucun jeu ne correspond aux filtres';

  @override
  String get gameList_changeFilters =>
      'Modifie ou réinitialise les filtres dans le menu';

  @override
  String gameList_noRomsFound(String folder) {
    return 'Aucune ROM trouvée dans $folder';
  }

  @override
  String get gameList_addRomFiles =>
      'Ajoute des ROMs dans ce dossier et rafraîchis';

  @override
  String get gameList_couldNotLoadGames => 'Impossible de charger les jeux';

  @override
  String get gameList_checkConnection => 'Vérifie ta connexion et réessaie';

  @override
  String get gameList_errorLoadingGames => 'Erreur de chargement';

  @override
  String get gameList_gamesAppearShortly => 'Les jeux vont apparaître bientôt';

  @override
  String get gameList_syncingLibrary => 'Synchronisation en cours…';

  @override
  String get gameList_localFilesOnly => 'Local';

  @override
  String get gameList_pressMenuHint => 'Appuie sur  +  pour le menu';

  @override
  String filter_activeCount(int count) {
    return '$count actifs';
  }

  @override
  String get shelfEdit_addFilter => '+ AJOUTER FILTRE';

  @override
  String shelfEdit_hiddenGamesCount(int count) {
    return 'Jeux masqués ($count)';
  }

  @override
  String shelfEdit_addedGamesCount(int count) {
    return 'Jeux ajoutés ($count)';
  }

  @override
  String get shelfEdit_textHint => '← Texte  Sys →';

  @override
  String gameListOverlay_gameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jeux',
      one: '1 jeu',
    );
    return '$_temp0';
  }

  @override
  String gameListOverlay_actionHint(String action) {
    return 'A : $action';
  }

  @override
  String systemSelector_selectedCount(int count) {
    return '$count sélectionnés';
  }

  @override
  String get filter_favoritesOnly => 'Favoris uniquement';

  @override
  String get filter_installedOnly => 'Installés uniquement';

  @override
  String get filter_regions => 'RÉGIONS';

  @override
  String get filter_languages => 'LANGUES';

  @override
  String get filter_title => 'FILTRE';

  @override
  String get onboarding_welcomeTitle => 'Bienvenue sur R-Shop';

  @override
  String get onboarding_welcomeSubtitle => 'D\'où viennent tes jeux ?';

  @override
  String get onboarding_pairQrTitle => 'Associer RomM via QR';

  @override
  String get onboarding_pairQrSubtitle =>
      'Scanne un code depuis ton serveur RomM';

  @override
  String get onboarding_legacyLoginTitle => 'Login RomM (anciens serveurs)';

  @override
  String get onboarding_legacyLoginSubtitle =>
      'Identifiant + mot de passe pour RomM < 4.8';

  @override
  String get onboarding_addServerTitle => 'Ajouter mon propre serveur';

  @override
  String get onboarding_addServerSubtitle =>
      'SMB, FTP ou miroir Web — mappe les systèmes manuellement';

  @override
  String get onboarding_localOnlyTitle => 'Jeux locaux uniquement';

  @override
  String get onboarding_localOnlySubtitle => 'ROMs déjà sur cet appareil';

  @override
  String get onboarding_working => 'En cours…';

  @override
  String get onboarding_scanningFolders => 'Scan des dossiers ROMs…';

  @override
  String get onboarding_discoveringPlatforms => 'Découverte des plateformes…';

  @override
  String get onboarding_savingSource => 'Enregistrement de la source…';

  @override
  String get onboarding_allSet => 'Tout est prêt !';

  @override
  String get onboarding_noSystems =>
      'Aucun système configuré — tu pourras ajouter des sources plus tard dans Paramètres.';

  @override
  String onboarding_systemsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count systèmes prêts à explorer',
      one: '1 système prêt à explorer',
    );
    return '$_temp0';
  }

  @override
  String get onboarding_jumpIn => 'C\'est parti !';

  @override
  String get onboarding_jumpInSubtitle =>
      'Ouvre l\'accueil et lance la synchro';

  @override
  String get onboarding_retroachievements => 'RetroAchievements';

  @override
  String get onboarding_retroachievementsSubtitle =>
      'Suis tes succès retro gaming';

  @override
  String get onboarding_exportConfig => 'Exporter la config';

  @override
  String get onboarding_exportConfigSubtitle =>
      'Réutilise cette config sur un autre appareil';

  @override
  String get onboarding_importConfig => 'Importer la config';

  @override
  String get onboarding_configImported => 'Config importée !';

  @override
  String onboarding_exportFailed(String error) {
    return 'Export échoué : $error';
  }

  @override
  String onboarding_invalidConfig(String error) {
    return 'Config invalide : $error';
  }

  @override
  String onboarding_failedToSave(String error) {
    return 'Erreur de sauvegarde : $error';
  }

  @override
  String get onboarding_selectFolderPrompt =>
      'Choisis le dossier où enregistrer les ROMs';

  @override
  String get onboarding_serverType => 'Type de serveur';

  @override
  String get onboarding_hangOn => 'Un instant, test de la connexion...';

  @override
  String get onboarding_foundConsole =>
      'J\'ai trouvé cette console sur ton serveur RomM ! Confirme ou choisis-en une autre.';

  @override
  String get onboarding_pickPlatform =>
      'Choisis la plateforme correspondante sur ton serveur RomM.';

  @override
  String get onboarding_couldNotReach =>
      'Impossible de joindre ton serveur RomM. Vérifie l\'URL et réessaie.';

  @override
  String get onboarding_connectionGood =>
      'Connexion réussie ! Tu peux enregistrer cette source.';

  @override
  String get onboarding_couldNotConnect =>
      'Hmm, connexion impossible. Vérifie l\'adresse et les identifiants.';

  @override
  String get onboarding_whatKindOfSource =>
      'Quel type de source ? Choisis le type de connexion.';

  @override
  String get onboarding_lookingGood =>
      'Ça a l\'air bon ! Ajoute d\'autres sources ou appuie sur Terminé.';

  @override
  String get onboarding_localCollection =>
      'C\'est une collection locale. Ajoute une source pour télécharger plus, ou appuie sur Terminé !';

  @override
  String get onboarding_addMoreSources =>
      'Ajoute au moins une source pour que je sache où trouver les ROMs.';

  @override
  String get onboarding_letsSetUp =>
      'Configurons tes consoles ! Sélectionne un système pour commencer.';

  @override
  String get onboarding_romFolder => 'DOSSIER ROMS';

  @override
  String get onboarding_options => 'OPTIONS';

  @override
  String get onboarding_autoExtractZips => 'Auto-extraire les ROMs zippées';

  @override
  String get onboarding_autoSyncLabel => 'Auto-sync au lancement';

  @override
  String get onboarding_autoSyncEnabled =>
      'Synchronise automatiquement (respecte le cooldown)';

  @override
  String get onboarding_autoSyncDisabled =>
      'Synchronise manuellement via le menu Start';

  @override
  String get onboarding_selectFolder => 'Choisir un dossier...';

  @override
  String get providerForm_addSource => 'Ajouter une source';

  @override
  String get providerForm_editSource => 'Modifier la source';

  @override
  String get providerForm_url => 'URL';

  @override
  String get providerForm_urlPlaceholder => 'https://...';

  @override
  String get providerForm_path => 'Chemin';

  @override
  String get providerForm_pathPlaceholder => '/roms/nes/ (optionnel)';

  @override
  String get providerForm_username => 'Utilisateur';

  @override
  String get providerForm_usernameOptional => '(optionnel)';

  @override
  String get providerForm_password => 'Mot de passe';

  @override
  String get providerForm_host => 'Host';

  @override
  String get providerForm_hostPlaceholder => '192.168.1.100';

  @override
  String get providerForm_port => 'Port';

  @override
  String get providerForm_share => 'Share';

  @override
  String get providerForm_sharePlaceholder => 'roms';

  @override
  String get providerForm_domain => 'Domaine';

  @override
  String get providerForm_domainOptional => '(optionnel)';

  @override
  String get providerForm_rommUrl => 'URL';

  @override
  String get providerForm_rommUrlPlaceholder => 'https://romm.exemple.com';

  @override
  String get providerForm_apiKey => 'API Key';

  @override
  String get providerForm_apiKeyOptional => '(optionnel)';

  @override
  String get providerForm_httpBlocked =>
      'HTTP vers des serveurs externes est bloqué. Utilise HTTPS, ou active-le après dans Paramètres.';

  @override
  String get providerForm_httpWarning =>
      'Les identifiants seront envoyés en clair par HTTP';

  @override
  String get providerForm_testingConnection => 'Test de connexion...';

  @override
  String get providerForm_connectionSuccessful => 'Connexion réussie !';

  @override
  String get providerForm_fetchingPlatforms =>
      'Récupération des plateformes...';

  @override
  String get providerForm_noPlatformsFound =>
      'Aucune plateforme trouvée sur ce serveur RomM.';

  @override
  String get providerForm_platform => 'PLATEFORME';

  @override
  String get providerForm_pickPlatform => 'Choisis une plateforme...';

  @override
  String get providerForm_testAndSave => 'Tester et enregistrer';

  @override
  String get providerForm_connectionFailed => 'Connexion échouée';

  @override
  String get providerForm_hostMissing => 'Host';

  @override
  String get providerForm_portMissing => 'Port';

  @override
  String get providerForm_pathMissing => 'Chemin';

  @override
  String get providerForm_shareMissing => 'Share';

  @override
  String get providerForm_urlMissing => 'URL';

  @override
  String get rommLogin_title => 'Connexion à RomM';

  @override
  String get rommLogin_name => 'Nom';

  @override
  String get rommLogin_nameDefault => 'Mon RomM';

  @override
  String get rommLogin_serverUrl => 'URL du serveur';

  @override
  String get rommLogin_username => 'Utilisateur';

  @override
  String get rommLogin_usernameHint => 'admin';

  @override
  String get rommLogin_password => 'Mot de passe';

  @override
  String get rommLogin_passwordHint => '••••••••';

  @override
  String get rommLogin_nameRequired => 'Le nom est requis';

  @override
  String get rommLogin_serverUrlRequired => 'L\'URL du serveur est requise';

  @override
  String get rommLogin_credentialsRequired =>
      'Identifiant ou mot de passe requis';

  @override
  String get ra_title => 'RetroAchievements';

  @override
  String get ra_subtitle => 'Suis tes succès retro gaming. ';

  @override
  String get ra_usernameLabel => 'Utilisateur';

  @override
  String get ra_usernameHint => 'ton pseudo RA';

  @override
  String get ra_apiKeyLabel => 'API Key';

  @override
  String get ra_apiKeyHint => 'copie depuis retroachievements.org';

  @override
  String get ra_usernameRequired => 'L\'utilisateur est requis';

  @override
  String get ra_apiKeyRequired => 'L\'API Key est requise';

  @override
  String get ra_connectionFailed => 'Connexion échouée';

  @override
  String get ra_disconnect => 'Déconnecter';

  @override
  String get ra_syncNow => 'Synchroniser les succès';

  @override
  String get ra_skipForNow => 'Passer pour l\'instant';

  @override
  String get pairing_scanQrTitle => 'Scanner le code QR';

  @override
  String get pairing_scanQrHint => 'Place le code QR dans le cadre';

  @override
  String get pairing_enterManually => 'Saisir le code manuellement';

  @override
  String get pairing_invalidQr =>
      'Ce code QR n\'est pas un lien de jumelage RomM valide';

  @override
  String get pairing_manualTitle => 'Jumelage manuel';

  @override
  String get pairing_manualInstructions =>
      'Génère le code dans l\'interface web RomM sous ';

  @override
  String get pairing_serverUrl => 'URL du serveur';

  @override
  String get pairing_pairingCode => 'Code de jumelage';

  @override
  String get pairing_pairingCodeHint => 'ABCD-1234';

  @override
  String get pairing_probingServer => 'Contact du serveur…';

  @override
  String get pairing_serverNotReachable =>
      'Serveur inaccessible ou pas une instance RomM';

  @override
  String get pairing_serverUrlRequired => 'L\'URL et le code sont requis';

  @override
  String get pairing_successTitle => 'Jumelage réussi !';

  @override
  String get pairing_server => 'Serveur';

  @override
  String get pairing_token => 'Token';

  @override
  String get pairing_userId => 'ID utilisateur';

  @override
  String get pairing_expiry => 'Expiration';

  @override
  String get pairing_neverExpires => 'N\'expire jamais';

  @override
  String get pairing_alreadyExpired => 'Déjà expiré';

  @override
  String get pairing_permissions => 'PERMISSIONS';

  @override
  String get pairing_addServer => 'Ajouter le serveur';

  @override
  String get service_notificationTitle => 'R-Shop';

  @override
  String get service_channelName => 'Téléchargements';

  @override
  String get service_channelDescription =>
      'Affiche la progression des téléchargements';

  @override
  String get service_downloadComplete => 'Téléchargements terminés';

  @override
  String service_downloading(String details) {
    return 'Téléchargement : $details';
  }

  @override
  String service_activeCount(int count) {
    return '$count actifs';
  }

  @override
  String service_queuedCount(int count) {
    return '$count en attente';
  }
}
