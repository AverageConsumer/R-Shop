// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'R-Shop';

  @override
  String get settings_language => 'Idioma';

  @override
  String get settings_languageSystem => 'Predeterminado del sistema';

  @override
  String get common_back => 'Volver';

  @override
  String get common_close => 'Cerrar';

  @override
  String get common_cancel => 'Cancelar';

  @override
  String get common_cancelUpper => 'CANCELAR';

  @override
  String get common_select => 'Seleccionar';

  @override
  String get common_search => 'Buscar';

  @override
  String get common_searchEllipsis => 'Buscar...';

  @override
  String get common_menu => 'Menú';

  @override
  String get common_navigate => 'Navegar';

  @override
  String get common_toggle => 'Alternar';

  @override
  String get common_clear => 'Limpiar';

  @override
  String get common_done => 'Listo';

  @override
  String get common_save => 'Guardar';

  @override
  String get common_connect => 'Conectar';

  @override
  String get common_retry => 'Reintentar';

  @override
  String get common_remove => 'Quitar';

  @override
  String get common_favorite => 'Favorito';

  @override
  String get common_unfavorite => 'Quitar favorito';

  @override
  String get common_downloads => 'Descargas';

  @override
  String get common_installed => 'INSTALADO';

  @override
  String get common_move => 'Mover';

  @override
  String get common_drop => 'Soltar';

  @override
  String get common_grab => 'Agarrar';

  @override
  String get confirm_deleteTitle => '¿Borrar ROM?';

  @override
  String confirm_deleteMessage(String gameTitle) {
    return '¿Seguro que quieres borrar esta versión de $gameTitle?';
  }

  @override
  String get confirm_exitTitle => '¿Salir?';

  @override
  String get confirm_exitMessage => '¿Seguro que quieres salir de Retro eShop?';

  @override
  String get confirm_resetTitle => '¿Reiniciar app?';

  @override
  String get confirm_resetMessage =>
      'Volverás a la pantalla de configuración inicial.';

  @override
  String get confirm_deleteButton => 'BORRAR';

  @override
  String get confirm_exitButton => 'SALIR';

  @override
  String get confirm_resetButton => 'REINICIAR';

  @override
  String get confirm_gamepadHint => '← → Elegir   A Confirmar   B Cancelar';

  @override
  String get exit_title => 'SALIR DE LA APP';

  @override
  String get exit_message => '¿Seguro que quieres salir?';

  @override
  String get exit_confirmButton => 'SALIR';

  @override
  String get exit_cancelButton => 'QUEDARME';

  @override
  String get downloads_title => 'Descargas';

  @override
  String downloads_activeCount(int count) {
    return '$count activas';
  }

  @override
  String get downloads_noDownloads => 'Sin descargas';

  @override
  String get downloads_sectionDownloading => 'Descargando';

  @override
  String get downloads_sectionQueued => 'En cola';

  @override
  String get downloads_sectionComplete => 'Completas';

  @override
  String get downloads_actionCancel => 'Cancelar';

  @override
  String get downloads_actionRetry => 'Reintentar';

  @override
  String get downloads_actionRemove => 'Quitar';

  @override
  String get downloads_actionClear => 'Limpiar';

  @override
  String get downloads_clearDone => 'Limpiar listas';

  @override
  String get downloadStatus_downloading => 'Descargando...';

  @override
  String get downloadStatus_extracting => 'Extrayendo...';

  @override
  String get downloadStatus_installing => 'Instalando...';

  @override
  String get downloadStatus_waiting => 'Esperando...';

  @override
  String get downloadStatus_complete => 'Completa';

  @override
  String get downloadStatus_cancelled => 'Cancelada';

  @override
  String get downloadStatus_failed => 'Falló';

  @override
  String storage_free(String size) {
    return '$size libre';
  }

  @override
  String storage_veryLow(String freeSpace) {
    return 'Muy poco espacio: $freeSpace';
  }

  @override
  String storage_gettingLow(String freeSpace) {
    return 'Poco espacio: $freeSpace';
  }

  @override
  String sync_progress(int completed, int total) {
    return 'Sincronizando $completed/$total';
  }

  @override
  String sync_singleSystemFailed(String system) {
    return 'Falló la sincronización de $system';
  }

  @override
  String sync_multipleSystemsFailed(int count) {
    return '$count sistemas fallaron al sincronizar';
  }

  @override
  String sync_raProgress(int completed, int total) {
    return 'Logros $completed/$total';
  }

  @override
  String get sync_raFailed => 'Falló la sincronización RA';

  @override
  String get toast_addedToQueue => 'Añadido a la cola';

  @override
  String get toast_configRecovered => 'Config recuperada del respaldo';

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
  String get gameDetail_achievements => 'Logros';

  @override
  String get gameDetail_mastered => 'DOMINADO';

  @override
  String get gameDetail_noAchievementsFound => 'No se encontraron logros';

  @override
  String get gameDetail_retroachievements => 'RETROACHIEVEMENTS';

  @override
  String get gameDetail_romVerified => 'ROM verificada';

  @override
  String get gameDetail_incompatibleRom => 'ROM incompatible';

  @override
  String get gameDetail_gameHasAchievements => 'Tiene logros';

  @override
  String get gameDetail_viewAchievements => 'Ver logros';

  @override
  String get gameDetail_versions => 'VERSIONES';

  @override
  String get gameDetail_download => 'DESCARGAR';

  @override
  String get gameDetail_adding => 'AÑADIENDO...';

  @override
  String get gameDetail_queued => 'EN COLA';

  @override
  String get gameDetail_extracting => 'EXTRAYENDO...';

  @override
  String get gameDetail_delete => 'BORRAR';

  @override
  String get gameDetail_manageFiles => 'GESTIONAR ARCHIVOS';

  @override
  String get gameDetail_unavailable => 'NO DISPONIBLE';

  @override
  String get gameDetail_installedLabel => 'Instalado';

  @override
  String get gameDetail_notFound => 'No encontrado';

  @override
  String get gameDetail_details => 'Detalles';

  @override
  String get gameDetail_screenshots => 'Capturas';

  @override
  String get gameDetail_otherVersions => 'Otras versiones';

  @override
  String get gameDetail_readMore => 'Leer más...';

  @override
  String get gameDetail_showLess => 'Ver menos';

  @override
  String get gameDetail_standard => 'Estándar';

  @override
  String get gameDetail_franchise => 'Franquicia';

  @override
  String get gameDetail_gameModes => 'Modos de juego';

  @override
  String get gameDetail_perspective => 'Perspectiva';

  @override
  String get gameDetail_ageRating => 'Clasificación';

  @override
  String get gameDetail_themes => 'Temas';

  @override
  String get gameDetail_fileTags => 'ETIQUETAS';

  @override
  String get gameDetail_tagVersion => 'Versión';

  @override
  String get gameDetail_tagBuild => 'Build';

  @override
  String get gameDetail_tagDisc => 'Disco';

  @override
  String get gameDetail_tagQuality => 'Calidad';

  @override
  String get gameDetail_tagInfo => 'Info';

  @override
  String get gameDetail_tagTechnical => 'Técnico';

  @override
  String get gameDetail_gameInfo => 'Info del juego';

  @override
  String get gameDetail_showTitle => 'Mostrar título';

  @override
  String get gameDetail_showFilename => 'Mostrar archivo';

  @override
  String gameDetail_fromProvider(String provider) {
    return 'de $provider';
  }

  @override
  String get gameDetail_addToShelf => 'Añadir al estante';

  @override
  String get gameDetail_removeFromShelf => 'Quitar del estante';

  @override
  String get gameDetail_removeFromShelfTitle => 'QUITAR DEL ESTANTE';

  @override
  String get gameDetail_gameNotInstalled => 'El juego no está instalado';

  @override
  String get gameDetail_couldNotShare => 'No se pudo compartir el archivo';

  @override
  String get gameDetail_pressAPickVersion => 'Pulsa A para elegir versión';

  @override
  String get gameDetail_pressAManage => 'Pulsa A para gestionar';

  @override
  String get gameDetail_pressADownload => 'Pulsa A para descargar';

  @override
  String gameDetail_errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get settings_title => 'AJUSTES';

  @override
  String get settings_tabGeneral => 'General';

  @override
  String get settings_tabAudio => 'Audio';

  @override
  String get settings_tabAdvanced => 'Avanzado';

  @override
  String get settings_tabAbout => 'Acerca de';

  @override
  String get settings_previousTab => 'Pestaña anterior';

  @override
  String get settings_nextTab => 'Siguiente pestaña';

  @override
  String get settings_resetApp => 'Reiniciar app';

  @override
  String get settings_resetDialogTitle => 'REINICIAR APP';

  @override
  String get settings_resetDialogMessage =>
      'Se borrarán todos los ajustes y volverás a la configuración inicial.';

  @override
  String get settings_resetDialogConfirm => 'REINICIAR';

  @override
  String get settings_resetDialogCancel => 'CANCELAR';

  @override
  String get settings_sectionLibrary => 'Biblioteca';

  @override
  String get settings_sectionDisplay => 'Pantalla';

  @override
  String get settings_mySources => 'Mis fuentes';

  @override
  String get settings_mySourcesSubtitle =>
      'Añade o gestiona servidores RomM, SMB, FTP';

  @override
  String get settings_consoleSettings => 'Ajustes de consola';

  @override
  String get settings_consoleSettingsSubtitle =>
      'Carpetas, extracción, opciones por sistema';

  @override
  String get settings_retroAchievements => 'RetroAchievements';

  @override
  String get settings_retroAchievementsSubtitle =>
      'Seguimiento de logros y verificación de ROMs';

  @override
  String get settings_homeLayout => 'Diseño de inicio';

  @override
  String get settings_homeLayoutGrid => 'Cuadrícula';

  @override
  String get settings_homeLayoutCarousel => 'Carrusel horizontal';

  @override
  String get settings_hideEmptyConsoles => 'Ocultar consolas vacías';

  @override
  String get settings_hideEmptyConsolesSubtitle =>
      'Solo mostrar sistemas con juegos';

  @override
  String get settings_controllerButtons => 'Botones del mando';

  @override
  String get settings_controllerNintendo => 'Nintendo (por defecto)';

  @override
  String get settings_controllerXbox => 'XBOX';

  @override
  String get settings_controllerPs => 'PS';

  @override
  String get settings_controllerNin => 'NIN';

  @override
  String get settings_sectionFeedback => 'Respuesta';

  @override
  String get settings_vibration => 'Vibración';

  @override
  String get settings_vibrationSubtitle => 'Vibrar al pulsar botones';

  @override
  String get settings_soundEffects => 'Efectos de sonido';

  @override
  String get settings_soundEffectsSubtitle => 'Sonidos en acciones del menú';

  @override
  String get settings_sectionVolume => 'Volumen';

  @override
  String get settings_music => 'Música';

  @override
  String get settings_musicSubtitle => 'Música ambiental de fondo';

  @override
  String get settings_effects => 'Efectos';

  @override
  String get settings_effectsSubtitle => 'Efectos de sonido de interfaz';

  @override
  String get settings_sectionDownloads => 'Descargas';

  @override
  String get settings_simultaneousDownloads => 'Descargas simultáneas';

  @override
  String get settings_simultaneousDownloadsSubtitle =>
      'Cuántos archivos se descargan a la vez';

  @override
  String get settings_downloadAllCovers => 'DESCARGAR CARÁTULAS';

  @override
  String get settings_downloadingCovers => 'DESCARGANDO CARÁTULAS...';

  @override
  String get settings_sectionSync => 'Sincronización';

  @override
  String get settings_syncTimeout => 'Tiempo de espera';

  @override
  String get settings_syncTimeoutSubtitle => 'Cuánto esperar por cada servidor';

  @override
  String get settings_autoSyncInterval => 'Intervalo de auto-sync';

  @override
  String get settings_autoSyncIntervalSubtitle =>
      'Tiempo mínimo entre sincronizaciones';

  @override
  String get settings_sectionDebug => 'Depuración';

  @override
  String get settings_allowInsecure => 'Permitir conexiones inseguras';

  @override
  String get settings_allowInsecureSubtitle =>
      'Permitir HTTP en servidores sin HTTPS';

  @override
  String get settings_exportErrorLog => 'Exportar log de errores';

  @override
  String get settings_exportErrorLogSubtitle =>
      'Compartir log para diagnóstico';

  @override
  String get settings_sectionInfo => 'Info';

  @override
  String get settings_sectionLinks => 'Enlaces';

  @override
  String get settings_github => 'GitHub';

  @override
  String get settings_githubSubtitle => 'Ver código fuente en GitHub';

  @override
  String get settings_issues => 'Problemas';

  @override
  String get settings_issuesSubtitle => 'Reportar errores o sugerir funciones';

  @override
  String get settings_tagline => 'INTENSIV, AGGRESSIV, MUTIG';

  @override
  String get settings_deviceMemoryLow => 'LOW';

  @override
  String get settings_deviceMemoryStandard => 'STANDARD';

  @override
  String get settings_deviceMemoryHigh => 'HIGH';

  @override
  String get settings_fetchingCovers => 'Obteniendo carátulas...';

  @override
  String settings_coversResult(int ok, int failed) {
    return 'Carátulas: $ok ok, $failed fallidas';
  }

  @override
  String settings_coversLoaded(int count) {
    return '¡$count carátulas cargadas!';
  }

  @override
  String get settings_noErrorLog => 'No hay log de errores';

  @override
  String get settings_configImported => '¡Config importada!';

  @override
  String get settings_controllerXboxFull => 'Xbox (A/B y X/Y invertidos)';

  @override
  String get settings_controllerPlaystationFull => 'PlayStation (✕ ○ □ △)';

  @override
  String get settings_allCoversCached => 'Todas las carátulas en caché';

  @override
  String get settings_downloadCoverArt =>
      'Descargar carátulas de todos los juegos';

  @override
  String settings_coverCacheInfo(String size, int count) {
    return '$size ($count en caché)';
  }

  @override
  String settings_coversRemaining(int count, String size) {
    return '$count restantes (~$size MB)';
  }

  @override
  String settings_coversProgress(int completed, int total) {
    return '$completed / $total juegos';
  }

  @override
  String get configMode_title => 'AJUSTES DE CONSOLA';

  @override
  String get configMode_globalTitle => 'AJUSTES GLOBALES';

  @override
  String get configMode_noFolderSet => 'Sin carpeta asignada';

  @override
  String get configMode_notConfigured => 'No configurado';

  @override
  String get configMode_export => 'Exportar';

  @override
  String get configMode_import => 'Importar';

  @override
  String get systemDetail_sectionStorage => 'Almacenamiento';

  @override
  String get systemDetail_selectRomFolder => 'Seleccionar carpeta de ROMs';

  @override
  String get systemDetail_tapToChangeFolder => 'Toca para cambiar carpeta';

  @override
  String get systemDetail_sectionBehavior => 'Comportamiento';

  @override
  String get systemDetail_autoExtractZips => 'Auto-extraer ZIPs';

  @override
  String get systemDetail_autoExtractEnabled =>
      'Las ROMs comprimidas se extraen al descargar';

  @override
  String get systemDetail_autoExtractDisabled =>
      'Las ROMs se quedan comprimidas';

  @override
  String get systemDetail_autoSyncOnLaunch => 'Auto-sync al iniciar';

  @override
  String get systemDetail_autoSyncEnabled =>
      'Sincroniza automáticamente (respeta cooldown)';

  @override
  String get systemDetail_autoSyncDisabled =>
      'Solo sincroniza manualmente desde el menú';

  @override
  String get systemDetail_sectionSources => 'Fuentes';

  @override
  String get sources_title => 'FUENTES';

  @override
  String get sources_noSourcesConfigured => 'No hay fuentes configuradas';

  @override
  String get sources_noSourcesYet => 'Aún no hay fuentes';

  @override
  String get sources_noSourcesDescription =>
      'Vincula un servidor RomM para empezar a descargar juegos. ';

  @override
  String get sources_addSource => 'Añadir fuente';

  @override
  String get sources_whereDoGamesComeFrom => '¿De dónde vienen tus juegos?';

  @override
  String get sources_sourceTypeRomm => 'Servidor RomM';

  @override
  String get sources_sourceTypeRommHint =>
      'Vincular vía QR o código de 8 dígitos';

  @override
  String get sources_sourceTypeRommLegacy => 'Login RomM (servidores antiguos)';

  @override
  String get sources_sourceTypeSmb => 'Recurso compartido SMB';

  @override
  String get sources_sourceTypeFtp => 'Servidor FTP';

  @override
  String get sources_sourceTypeWeb => 'Mirror Web';

  @override
  String get sources_sourceTypeWebHint => 'Listado de directorio HTTPS';

  @override
  String get sources_expired => 'EXPIRADO';

  @override
  String get sources_borrowed => 'PRESTADO';

  @override
  String get sources_off => 'OFF';

  @override
  String get sources_noPlatforms => 'Sin plataformas';

  @override
  String get sources_rePair => 'Re-vincular';

  @override
  String get sources_editMappings => 'Editar mapeos';

  @override
  String get sources_disable => 'Desactivar';

  @override
  String get sources_enable => 'Activar';

  @override
  String get manualSource_defaultNameSmb => 'Mi NAS';

  @override
  String get manualSource_defaultNameFtp => 'Mi FTP';

  @override
  String get manualSource_defaultNameWeb => 'Mirror Web';

  @override
  String get manualSource_defaultNameOther => 'Fuente';

  @override
  String get manualSource_name => 'Nombre';

  @override
  String get manualSource_url => 'URL';

  @override
  String get manualSource_urlHint => 'https://ejemplo.com/roms';

  @override
  String get manualSource_host => 'Host';

  @override
  String get manualSource_hostHint => 'nas.local o 192.168.1.10';

  @override
  String get manualSource_port => 'Port';

  @override
  String get manualSource_share => 'Share';

  @override
  String get manualSource_shareHint => 'roms';

  @override
  String get manualSource_usernameOptional => 'Usuario (opcional)';

  @override
  String get manualSource_usernameHint => 'dejar vacío para invitado';

  @override
  String get manualSource_passwordOptional => 'Contraseña (opcional)';

  @override
  String get manualSource_nameRequired => 'El nombre es obligatorio';

  @override
  String get manualSource_urlRequired => 'La URL es obligatoria';

  @override
  String get manualSource_hostRequired => 'El host es obligatorio';

  @override
  String get manualSource_shareRequired => 'El share es obligatorio';

  @override
  String get manualSource_saveSource => 'Guardar fuente';

  @override
  String get manualSource_smb => 'SMB';

  @override
  String get manualSource_ftp => 'FTP';

  @override
  String get manualSource_web => 'Web';

  @override
  String get manualSource_searchingNetwork => 'Buscando en la red…';

  @override
  String get manualSource_foundOnNetwork => 'Encontrado en tu red';

  @override
  String get sourceMappings_title => 'Mapeo de sistemas';

  @override
  String get sourceMappings_instruction =>
      'Indica la carpeta remota para cada sistema que quieras usar con esta fuente. Deja vacío para omitir.';

  @override
  String get sourceMappings_save => 'Guardar mapeo';

  @override
  String get library_title => 'BIBLIOTECA';

  @override
  String get library_tabAll => 'Todo';

  @override
  String get library_tabInstalled => 'Instalados';

  @override
  String get library_tabFavorites => 'Favoritos';

  @override
  String get library_sortSystem => 'Ordenar por sistema';

  @override
  String get library_sortManual => 'Orden manual';

  @override
  String get library_sortAZ => 'Ordenar A-Z';

  @override
  String get library_sortIndicatorAZ => 'A-Z';

  @override
  String get library_sortIndicatorBySystem => 'POR SISTEMA';

  @override
  String get library_sortIndicatorManual => 'MANUAL';

  @override
  String get library_searchHint => 'Buscar en biblioteca...';

  @override
  String get library_zoomIn => 'Acercar';

  @override
  String get library_zoomOut => 'Alejar';

  @override
  String get library_newShelf => 'Nuevo estante';

  @override
  String get library_editShelf => 'Editar estante';

  @override
  String get library_addToShelf => 'Añadir al estante';

  @override
  String get library_removeFromShelf => 'Quitar del estante';

  @override
  String get library_reorderGames => 'Reordenar juegos';

  @override
  String library_noResults(String query) {
    return 'Sin resultados para \"$query\"';
  }

  @override
  String get library_tryShorterSearch => 'Prueba un término más corto';

  @override
  String get library_noInstalledGames => 'No hay juegos instalados';

  @override
  String get library_downloadGamesToSee => 'Descarga juegos para verlos aquí';

  @override
  String get library_noFavoritesYet => 'Aún no hay favoritos';

  @override
  String get library_pressFavoriteHint =>
      'Pulsa SELECT en un juego para marcarlo';

  @override
  String get library_noGamesInShelf => 'No hay juegos en este estante';

  @override
  String get library_addGamesViaEditor => 'Añade juegos desde el editor';

  @override
  String get library_noGamesInLibrary => 'No hay juegos en la biblioteca';

  @override
  String get library_gamesAfterSync =>
      'Los juegos aparecerán tras la sincronización';

  @override
  String get shelfEdit_title => 'EDITAR ESTANTE';

  @override
  String get shelfEdit_titleNew => 'NUEVO ESTANTE';

  @override
  String get shelfEdit_nameSection => 'NOMBRE';

  @override
  String get shelfEdit_shelfName => 'Nombre del estante';

  @override
  String get shelfEdit_filterText => 'Texto de filtro';

  @override
  String get shelfEdit_tapToSet => 'Toca para asignar...';

  @override
  String get shelfEdit_filterRules => 'REGLAS DE FILTRO';

  @override
  String get shelfEdit_resetManualOrder => 'Reiniciar orden manual';

  @override
  String get shelfEdit_saveButton => 'GUARDAR';

  @override
  String get shelfEdit_deleteShelf => 'BORRAR ESTANTE';

  @override
  String get shelfEdit_anyText => 'Cualquier texto';

  @override
  String get shelfEdit_allSystems => 'Todos los sistemas';

  @override
  String get shelfPicker_title => 'AÑADIR AL ESTANTE';

  @override
  String get systemSelector_title => 'SELECCIONAR SISTEMAS';

  @override
  String get textInput_hint => 'Escribe aquí...';

  @override
  String get textInput_ok => 'OK';

  @override
  String get gameListOverlay_hiddenGames => 'JUEGOS OCULTOS';

  @override
  String get gameListOverlay_addedGames => 'JUEGOS AÑADIDOS';

  @override
  String get gameListOverlay_restore => 'Restaurar';

  @override
  String get gameListOverlay_noGames => 'Sin juegos';

  @override
  String get gameListOverlay_clearAll => 'Limpiar todo';

  @override
  String get home_allGames => 'TODOS LOS JUEGOS';

  @override
  String get home_library => 'Biblioteca';

  @override
  String get home_noConsoles => 'No hay consolas configuradas';

  @override
  String get home_pressStartForMenu => 'Pulsa Start para el menú';

  @override
  String get home_settings => 'Ajustes';

  @override
  String home_syncSystem(String system) {
    return 'Sincronizar $system';
  }

  @override
  String get home_syncAll => 'Sincronizar todo';

  @override
  String get home_lastSyncNever => 'Nunca sincronizado';

  @override
  String get home_lastSyncJustNow => 'Sincronizado recién';

  @override
  String home_lastSyncMinutes(int minutes) {
    return 'Sincronizado hace ${minutes}min';
  }

  @override
  String home_lastSyncHours(int hours) {
    return 'Sincronizado hace ${hours}h';
  }

  @override
  String home_lastSyncDays(int days) {
    return 'Sincronizado hace ${days}d';
  }

  @override
  String get common_exit => 'Salir';

  @override
  String gameList_gamesCount(int count) {
    return '$count Juegos';
  }

  @override
  String get gameList_offline => 'Sin conexión';

  @override
  String get gameList_zoomIn => 'Acercar';

  @override
  String get gameList_zoomOut => 'Alejar';

  @override
  String get gameList_filterActive => 'Filtro (activo)';

  @override
  String get gameList_filter => 'Filtro';

  @override
  String gameList_noGamesMatchSearch(String query) {
    return 'Ningún juego coincide con \'$query\'';
  }

  @override
  String get gameList_tryShorterSearch => 'Prueba un término más corto';

  @override
  String get gameList_noGamesMatchFilters =>
      'Ningún juego coincide con los filtros';

  @override
  String get gameList_changeFilters =>
      'Cambia o reinicia los filtros en el menú';

  @override
  String gameList_noRomsFound(String folder) {
    return 'No se encontraron ROMs en $folder';
  }

  @override
  String get gameList_addRomFiles =>
      'Añade archivos ROM a esta carpeta y refresca';

  @override
  String get gameList_couldNotLoadGames => 'No se pudieron cargar los juegos';

  @override
  String get gameList_checkConnection =>
      'Revisa tu conexión e inténtalo de nuevo';

  @override
  String get gameList_errorLoadingGames => 'Error al cargar juegos';

  @override
  String get gameList_gamesAppearShortly => 'Los juegos aparecerán pronto';

  @override
  String get gameList_syncingLibrary => 'Sincronizando biblioteca…';

  @override
  String get gameList_localFilesOnly =>
      'Solo archivos locales · Añade un proveedor para más';

  @override
  String get gameList_pressMenuHint => 'Pulsa  +  para el menú';

  @override
  String filter_activeCount(int count) {
    return '$count activos';
  }

  @override
  String get shelfEdit_addFilter => '+ AÑADIR FILTRO';

  @override
  String shelfEdit_hiddenGamesCount(int count) {
    return 'Juegos ocultos ($count)';
  }

  @override
  String shelfEdit_addedGamesCount(int count) {
    return 'Juegos añadidos ($count)';
  }

  @override
  String get shelfEdit_textHint => '← Texto  Sis →';

  @override
  String gameListOverlay_gameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count juegos',
      one: '1 juego',
    );
    return '$_temp0';
  }

  @override
  String gameListOverlay_actionHint(String action) {
    return 'A: $action';
  }

  @override
  String systemSelector_selectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get filter_favoritesOnly => 'Solo favoritos';

  @override
  String get filter_installedOnly => 'Solo instalados';

  @override
  String get filter_regions => 'REGIONES';

  @override
  String get filter_languages => 'IDIOMAS';

  @override
  String get filter_title => 'FILTRO';

  @override
  String get onboarding_welcomeTitle => 'Bienvenido a R-Shop';

  @override
  String get onboarding_welcomeSubtitle => '¿De dónde vienen tus juegos?';

  @override
  String get onboarding_pairQrTitle => 'Vincular RomM vía QR';

  @override
  String get onboarding_pairQrSubtitle =>
      'Escanea un código de tu servidor RomM';

  @override
  String get onboarding_legacyLoginTitle => 'Login RomM (servidores antiguos)';

  @override
  String get onboarding_legacyLoginSubtitle =>
      'Usuario + contraseña para RomM < 4.8';

  @override
  String get onboarding_addServerTitle => 'Añadir mi propio servidor';

  @override
  String get onboarding_addServerSubtitle =>
      'SMB, FTP o mirror Web — mapea sistemas manualmente';

  @override
  String get onboarding_localOnlyTitle => 'Solo juegos locales';

  @override
  String get onboarding_localOnlySubtitle =>
      'ROMs que ya están en este dispositivo';

  @override
  String get onboarding_working => 'Trabajando…';

  @override
  String get onboarding_scanningFolders => 'Escaneando carpetas de ROMs…';

  @override
  String get onboarding_discoveringPlatforms => 'Descubriendo plataformas…';

  @override
  String get onboarding_savingSource => 'Guardando fuente…';

  @override
  String get onboarding_allSet => '¡Todo listo!';

  @override
  String get onboarding_noSystems =>
      'No hay sistemas configurados — puedes añadir fuentes luego en Ajustes.';

  @override
  String onboarding_systemsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sistemas listos para explorar',
      one: '1 sistema listo para explorar',
    );
    return '$_temp0';
  }

  @override
  String get onboarding_jumpIn => '¡A jugar!';

  @override
  String get onboarding_jumpInSubtitle =>
      'Abre la pantalla de inicio y empieza a sincronizar';

  @override
  String get onboarding_retroachievements => 'RetroAchievements';

  @override
  String get onboarding_retroachievementsSubtitle => 'Sigue tus logros retro';

  @override
  String get onboarding_exportConfig => 'Exportar config';

  @override
  String get onboarding_exportConfigSubtitle =>
      'Reutiliza esta configuración en otro dispositivo';

  @override
  String get onboarding_importConfig => 'Importar config';

  @override
  String get onboarding_configImported => '¡Config importada!';

  @override
  String onboarding_exportFailed(String error) {
    return 'Exportación fallida: $error';
  }

  @override
  String onboarding_invalidConfig(String error) {
    return 'Config inválida: $error';
  }

  @override
  String onboarding_failedToSave(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get onboarding_selectFolderPrompt =>
      'Elige la carpeta donde guardar las ROMs';

  @override
  String get onboarding_serverType => 'Tipo de servidor';

  @override
  String get onboarding_folderExplanationTitle =>
      'Configura la ruta de tu biblioteca';

  @override
  String get onboarding_folderExplanationMessage =>
      'R-Shop necesita una carpeta base para guardar los juegos que descargues. Esto ayuda a organizar tus archivos y es necesario para los permisos de carpetas de Android.\n\nTe recomendamos crear una carpeta llamada \'ROMs\' y seleccionarla.';

  @override
  String get onboarding_continueToPicker => 'Seleccionar carpeta';

  @override
  String get onboarding_hangOn => 'Un momento, probando la conexión...';

  @override
  String get onboarding_foundConsole =>
      '¡Encontré esta consola en tu servidor RomM! Confirma o elige otra.';

  @override
  String get onboarding_pickPlatform =>
      'Elige la plataforma correspondiente de tu servidor RomM.';

  @override
  String get onboarding_couldNotReach =>
      'No pude conectar con tu servidor RomM. Revisa la URL e inténtalo de nuevo.';

  @override
  String get onboarding_connectionGood =>
      '¡Conexión exitosa! Ya puedes guardar esta fuente.';

  @override
  String get onboarding_couldNotConnect =>
      'Hmm, no pude conectar. Revisa la dirección y las credenciales.';

  @override
  String get onboarding_whatKindOfSource =>
      '¿Qué tipo de fuente es? Elige el tipo de conexión.';

  @override
  String get onboarding_lookingGood =>
      '¡Se ve bien! Añade más fuentes o pulsa Listo cuando quieras.';

  @override
  String get onboarding_localCollection =>
      'Es una colección local. ¡Añade una fuente para descargar más, o pulsa Listo!';

  @override
  String get onboarding_addMoreSources =>
      'Ahora añade al menos una fuente para que sepa dónde están las ROMs.';

  @override
  String get onboarding_letsSetUp =>
      '¡Configuremos tus consolas! Selecciona un sistema para empezar.';

  @override
  String get onboarding_romFolder => 'CARPETA DE ROMS';

  @override
  String get onboarding_options => 'OPCIONES';

  @override
  String get onboarding_autoExtractZips => 'Auto-extraer ROMs comprimidas';

  @override
  String get onboarding_autoSyncLabel => 'Auto-sync al iniciar la app';

  @override
  String get onboarding_autoSyncEnabled =>
      'Sincroniza automáticamente (respeta cooldown)';

  @override
  String get onboarding_autoSyncDisabled =>
      'Solo sincroniza manualmente desde el menú';

  @override
  String get onboarding_selectFolder => 'Seleccionar carpeta...';

  @override
  String get providerForm_addSource => 'Añadir fuente';

  @override
  String get providerForm_editSource => 'Editar fuente';

  @override
  String get providerForm_url => 'URL';

  @override
  String get providerForm_urlPlaceholder => 'https://...';

  @override
  String get providerForm_path => 'Ruta';

  @override
  String get providerForm_pathPlaceholder => '/roms/nes/ (opcional)';

  @override
  String get providerForm_username => 'Usuario';

  @override
  String get providerForm_usernameOptional => '(opcional)';

  @override
  String get providerForm_password => 'Contraseña';

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
  String get providerForm_domain => 'Dominio';

  @override
  String get providerForm_domainOptional => '(opcional)';

  @override
  String get providerForm_rommUrl => 'URL';

  @override
  String get providerForm_rommUrlPlaceholder => 'https://romm.ejemplo.com';

  @override
  String get providerForm_apiKey => 'API Key';

  @override
  String get providerForm_apiKeyOptional => '(opcional)';

  @override
  String get providerForm_httpBlocked =>
      'HTTP a servidores externos está bloqueado. Usa HTTPS, o habilítalo después en Ajustes.';

  @override
  String get providerForm_httpWarning =>
      'Las credenciales se enviarán sin cifrar por HTTP';

  @override
  String get providerForm_testingConnection => 'Probando conexión...';

  @override
  String get providerForm_connectionSuccessful => '¡Conexión exitosa!';

  @override
  String get providerForm_fetchingPlatforms => 'Obteniendo plataformas...';

  @override
  String get providerForm_noPlatformsFound =>
      'No se encontraron plataformas en este servidor RomM.';

  @override
  String get providerForm_platform => 'PLATAFORMA';

  @override
  String get providerForm_pickPlatform => 'Elige una plataforma...';

  @override
  String get providerForm_testAndSave => 'Probar y guardar';

  @override
  String get providerForm_connectionFailed => 'Conexión fallida';

  @override
  String get providerForm_hostMissing => 'Host';

  @override
  String get providerForm_portMissing => 'Port';

  @override
  String get providerForm_pathMissing => 'Ruta';

  @override
  String get providerForm_shareMissing => 'Share';

  @override
  String get providerForm_urlMissing => 'URL';

  @override
  String get rommLogin_title => 'Iniciar sesión en RomM';

  @override
  String get rommLogin_name => 'Nombre';

  @override
  String get rommLogin_nameDefault => 'Mi RomM';

  @override
  String get rommLogin_serverUrl => 'URL del servidor';

  @override
  String get rommLogin_username => 'Usuario';

  @override
  String get rommLogin_usernameHint => 'admin';

  @override
  String get rommLogin_password => 'Contraseña';

  @override
  String get rommLogin_passwordHint => '••••••••';

  @override
  String get rommLogin_nameRequired => 'El nombre es obligatorio';

  @override
  String get rommLogin_serverUrlRequired =>
      'La URL del servidor es obligatoria';

  @override
  String get rommLogin_credentialsRequired =>
      'Se requiere usuario o contraseña';

  @override
  String get ra_title => 'RetroAchievements';

  @override
  String get ra_subtitle => 'Sigue tus logros en juegos retro. ';

  @override
  String get ra_usernameLabel => 'Usuario';

  @override
  String get ra_usernameHint => 'tu usuario de RA';

  @override
  String get ra_apiKeyLabel => 'API Key';

  @override
  String get ra_apiKeyHint => 'copia desde retroachievements.org';

  @override
  String get ra_usernameRequired => 'El usuario es obligatorio';

  @override
  String get ra_apiKeyRequired => 'La API Key es obligatoria';

  @override
  String get ra_connectionFailed => 'Conexión fallida';

  @override
  String get ra_disconnect => 'Desconectar';

  @override
  String get ra_syncNow => 'Sincronizar logros ahora';

  @override
  String get ra_skipForNow => 'Saltar por ahora';

  @override
  String get pairing_scanQrTitle => 'Escanear código QR';

  @override
  String get pairing_scanQrHint => 'Mantén el código QR dentro del marco';

  @override
  String get pairing_enterManually => 'Ingresar código manualmente';

  @override
  String get pairing_invalidQr => 'El código QR no es un enlace válido de RomM';

  @override
  String get pairing_manualTitle => 'Vinculación manual';

  @override
  String get pairing_manualInstructions =>
      'Genera el código en la web de RomM en ';

  @override
  String get pairing_serverUrl => 'URL del servidor';

  @override
  String get pairing_pairingCode => 'Código de vinculación';

  @override
  String get pairing_pairingCodeHint => 'ABCD-1234';

  @override
  String get pairing_probingServer => 'Contactando servidor…';

  @override
  String get pairing_serverNotReachable =>
      'Servidor no alcanzable o no es una instancia RomM';

  @override
  String get pairing_serverUrlRequired => 'Se requieren la URL y el código';

  @override
  String get pairing_successTitle => '¡Vinculación exitosa!';

  @override
  String get pairing_server => 'Servidor';

  @override
  String get pairing_token => 'Token';

  @override
  String get pairing_userId => 'ID de usuario';

  @override
  String get pairing_expiry => 'Expiración';

  @override
  String get pairing_neverExpires => 'No expira';

  @override
  String get pairing_alreadyExpired => 'Ya expiró';

  @override
  String get pairing_permissions => 'PERMISOS';

  @override
  String get pairing_addServer => 'Añadir servidor';

  @override
  String get service_notificationTitle => 'R-Shop';

  @override
  String get service_channelName => 'Descargas';

  @override
  String get service_channelDescription =>
      'Muestra el progreso de las descargas';

  @override
  String get service_downloadComplete => 'Descargas completas';

  @override
  String service_downloading(String details) {
    return 'Descargando: $details';
  }

  @override
  String service_activeCount(int count) {
    return '$count activas';
  }

  @override
  String service_queuedCount(int count) {
    return '$count en cola';
  }

  @override
  String get sources_connectionRoute => 'Ruta de conexión';

  @override
  String get sources_routeAuto => 'Automático';

  @override
  String get sources_routeAutoHint =>
      'Usar la ruta más rápida que responda; se comprueba de nuevo cuando cambia la red';

  @override
  String get sources_routeInUse => 'En uso';

  @override
  String get sources_routePinned => 'Fijada';

  @override
  String get sources_routeReachable => 'Accesible';

  @override
  String get sources_routeNoAnswer => 'Sin respuesta';

  @override
  String get sources_routeChecking => 'Comprobando…';

  @override
  String sources_routeLatencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String sources_routeAutoPicks(String route) {
    return 'Usaría $route';
  }

  @override
  String get sources_routeAutoNoneReachable => 'No respondió ninguna';

  @override
  String get sources_routeFastest => 'La más rápida';

  @override
  String get sources_routeReleasePin =>
      'Quita la fijación y vuelve a elegir la más rápida';

  @override
  String get sources_routeOwnLogin => 'Inicio de sesión propio';

  @override
  String get sources_routeAuthTitle => 'Inicio de sesión de esta ruta';

  @override
  String get sources_routeAuthHint =>
      'Déjalo en blanco para usar el inicio de sesión de la fuente. Rellénalo solo si esta dirección pide otro.';

  @override
  String get sources_routeAuthInherited =>
      'Usa el inicio de sesión de la fuente';

  @override
  String get sources_routeAuthOwn => 'Esta ruta inicia sesión por su cuenta';

  @override
  String get sources_routeOnlyOne => 'Esta fuente solo tiene una ruta';

  @override
  String get sources_addRoute => 'Añadir ruta';

  @override
  String get sources_editRoute => 'Editar ruta';

  @override
  String get sources_removeRoute => 'Eliminar ruta';

  @override
  String get sources_routeDuplicate =>
      'Esta fuente ya tiene una ruta a esa dirección';

  @override
  String get sources_activeSource => 'En uso';

  @override
  String get sources_switchSource => 'Cambiar fuente';

  @override
  String get sources_prevSource => 'Fuente anterior';

  @override
  String get sources_nextSource => 'Fuente siguiente';

  @override
  String get sources_setFallback => 'Fuente de respaldo';

  @override
  String get sources_fallbackNone => 'Ninguna';

  @override
  String get sources_fallbackShort => 'Respaldo';

  @override
  String get sources_routeSameServerHint =>
      'Todas las rutas llegan al mismo servidor. Una ruta puede llevar su propio inicio de sesión si esa dirección pide otro.';

  @override
  String get sources_routeCannotRemoveLast =>
      'No se puede eliminar la última ruta';

  @override
  String sources_countLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fuentes',
      one: '1 fuente',
    );
    return '$_temp0';
  }

  @override
  String get sources_useThisShort => 'Usar esta';

  @override
  String get sources_stopUsingShort => 'Dejar de usar';

  @override
  String get sources_removeConfirmTitle => '¿Eliminar la fuente?';

  @override
  String sources_removeConfirmMessage(String name) {
    return '¿Eliminar \"$name\"? Su lista desaparece de la biblioteca, pero los juegos ya descargados en este dispositivo se conservan.';
  }

  @override
  String get sources_groupBadge => 'Grupo';

  @override
  String get sources_groupCreate => 'Agrupar con otra fuente…';

  @override
  String get sources_groupCreateHint =>
      'Para dos direcciones que en realidad son el mismo servidor';

  @override
  String get sources_groupPickMember => 'Elige la fuente con la que agrupar';

  @override
  String get sources_groupSameTypeOnly =>
      'Solo se pueden agrupar fuentes del mismo tipo';

  @override
  String get sources_groupNoCandidates => 'No hay otra fuente de este tipo';

  @override
  String get sources_groupManage => 'Ajustes del grupo';

  @override
  String get sources_groupRename => 'Renombrar grupo';

  @override
  String get sources_groupNameLabel => 'Nombre del grupo';

  @override
  String get sources_groupModeTitle => 'Qué miembro se usa';

  @override
  String get sources_groupModeAuto => 'Quien responda primero';

  @override
  String get sources_groupModeAutoHint =>
      'Sin orden que mantener: la dirección que responde antes es la que puedes usar antes';

  @override
  String get sources_groupModeOrdered => 'Mi orden';

  @override
  String get sources_groupModeOrderedHint =>
      'Usa la primera de tu orden que responda';

  @override
  String get sources_groupPreferred => 'Primera opción';

  @override
  String get sources_groupAddMember => 'Añadir una fuente';

  @override
  String get sources_groupLeave => 'Salir del grupo';

  @override
  String sources_groupLeaveConfirm(String name) {
    return '«$name» no conserva ningún juego y tendrá que sincronizar de nuevo. La lista compartida se queda en el grupo.';
  }

  @override
  String get sources_groupLeaveTitle => '¿Salir del grupo?';

  @override
  String get sources_groupDissolve => 'Deshacer el grupo';

  @override
  String sources_groupDissolveConfirm(String name) {
    return 'La lista compartida se queda con «$name»; las demás tendrán que sincronizar de nuevo.';
  }

  @override
  String get sources_groupDissolveTitle => '¿Deshacer el grupo?';

  @override
  String sources_groupMembersCount(int count) {
    return '$count fuentes';
  }

  @override
  String sources_groupUsing(String name) {
    return 'Usando «$name»';
  }

  @override
  String get sources_moveUp => 'Subir';

  @override
  String get sources_moveDown => 'Bajar';

  @override
  String get sources_routeOrdered => 'Mi orden';

  @override
  String get sources_routeOrderedHint =>
      'Usar la primera ruta de tu orden que responda';
}
