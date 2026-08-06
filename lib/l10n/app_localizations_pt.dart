// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class LPt extends L {
  LPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'R-Shop';

  @override
  String get settings_language => 'Idioma';

  @override
  String get settings_languageSystem => 'Padrão do sistema';

  @override
  String get common_back => 'Voltar';

  @override
  String get common_close => 'Fechar';

  @override
  String get common_cancel => 'Cancelar';

  @override
  String get common_cancelUpper => 'CANCELAR';

  @override
  String get common_select => 'Selecionar';

  @override
  String get common_search => 'Buscar';

  @override
  String get common_searchEllipsis => 'Buscar...';

  @override
  String get common_menu => 'Menu';

  @override
  String get common_navigate => 'Navegar';

  @override
  String get common_toggle => 'Alternar';

  @override
  String get common_clear => 'Limpar';

  @override
  String get common_done => 'Pronto';

  @override
  String get common_save => 'Salvar';

  @override
  String get common_connect => 'Conectar';

  @override
  String get common_retry => 'Tentar de novo';

  @override
  String get common_remove => 'Remover';

  @override
  String get common_favorite => 'Favoritar';

  @override
  String get common_unfavorite => 'Desfavoritar';

  @override
  String get common_downloads => 'Downloads';

  @override
  String get common_installed => 'INSTALADO';

  @override
  String get common_move => 'Mover';

  @override
  String get common_drop => 'Soltar';

  @override
  String get common_grab => 'Pegar';

  @override
  String get confirm_deleteTitle => 'Apagar ROM?';

  @override
  String confirm_deleteMessage(String gameTitle) {
    return 'Quer mesmo apagar essa versão de $gameTitle?';
  }

  @override
  String get confirm_exitTitle => 'Sair do App?';

  @override
  String get confirm_exitMessage => 'Quer mesmo sair do Retro eShop?';

  @override
  String get confirm_resetTitle => 'Resetar App?';

  @override
  String get confirm_resetMessage =>
      'Isso vai voltar pra tela de configuração inicial.';

  @override
  String get confirm_deleteButton => 'APAGAR';

  @override
  String get confirm_exitButton => 'SAIR';

  @override
  String get confirm_resetButton => 'RESETAR';

  @override
  String get confirm_gamepadHint => '← → Selecionar   A Confirmar   B Cancelar';

  @override
  String get exit_title => 'SAIR DO APLICATIVO';

  @override
  String get exit_message => 'Tem certeza que quer sair?';

  @override
  String get exit_confirmButton => 'SAIR';

  @override
  String get exit_cancelButton => 'FICAR';

  @override
  String get downloads_title => 'Downloads';

  @override
  String downloads_activeCount(int count) {
    return '$count ativos';
  }

  @override
  String get downloads_noDownloads => 'Nenhum download';

  @override
  String get downloads_sectionDownloading => 'Baixando';

  @override
  String get downloads_sectionQueued => 'Na fila';

  @override
  String get downloads_sectionComplete => 'Concluídos';

  @override
  String get downloads_actionCancel => 'Cancelar';

  @override
  String get downloads_actionRetry => 'Tentar de novo';

  @override
  String get downloads_actionRemove => 'Remover';

  @override
  String get downloads_actionClear => 'Limpar';

  @override
  String get downloads_clearDone => 'Limpar concluídos';

  @override
  String get downloadStatus_downloading => 'Baixando...';

  @override
  String get downloadStatus_extracting => 'Extraindo...';

  @override
  String get downloadStatus_installing => 'Instalando...';

  @override
  String get downloadStatus_waiting => 'Aguardando...';

  @override
  String get downloadStatus_complete => 'Concluído';

  @override
  String get downloadStatus_cancelled => 'Cancelado';

  @override
  String get downloadStatus_failed => 'Falhou';

  @override
  String storage_free(String size) {
    return '$size livre';
  }

  @override
  String storage_veryLow(String freeSpace) {
    return 'Armazenamento muito baixo: $freeSpace';
  }

  @override
  String storage_gettingLow(String freeSpace) {
    return 'Armazenamento ficando baixo: $freeSpace';
  }

  @override
  String sync_progress(int completed, int total) {
    return 'Sincronizando $completed/$total';
  }

  @override
  String sync_singleSystemFailed(String system) {
    return 'Falha ao sincronizar $system';
  }

  @override
  String sync_multipleSystemsFailed(int count) {
    return '$count sistemas falharam ao sincronizar';
  }

  @override
  String sync_raProgress(int completed, int total) {
    return 'Conquistas $completed/$total';
  }

  @override
  String get sync_raFailed => 'Falha na sinc. RA';

  @override
  String get toast_addedToQueue => 'Adicionado à fila';

  @override
  String get toast_configRecovered => 'Config recuperada do backup';

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
  String get gameDetail_achievements => 'Conquistas';

  @override
  String get gameDetail_mastered => 'DOMINADO';

  @override
  String get gameDetail_noAchievementsFound => 'Nenhuma conquista encontrada';

  @override
  String get gameDetail_retroachievements => 'RETROACHIEVEMENTS';

  @override
  String get gameDetail_romVerified => 'ROM Verificada';

  @override
  String get gameDetail_incompatibleRom => 'ROM Incompatível';

  @override
  String get gameDetail_gameHasAchievements => 'Jogo Tem Conquistas';

  @override
  String get gameDetail_viewAchievements => 'Ver Conquistas';

  @override
  String get gameDetail_versions => 'VERSÕES';

  @override
  String get gameDetail_download => 'BAIXAR';

  @override
  String get gameDetail_adding => 'ADICIONANDO...';

  @override
  String get gameDetail_queued => 'NA FILA';

  @override
  String get gameDetail_extracting => 'EXTRAINDO...';

  @override
  String get gameDetail_delete => 'APAGAR';

  @override
  String get gameDetail_manageFiles => 'GERENCIAR ARQUIVOS';

  @override
  String get gameDetail_unavailable => 'INDISPONÍVEL';

  @override
  String get gameDetail_installedLabel => 'Instalado';

  @override
  String get gameDetail_notFound => 'Não encontrado';

  @override
  String get gameDetail_details => 'Detalhes';

  @override
  String get gameDetail_screenshots => 'Capturas de tela';

  @override
  String get gameDetail_otherVersions => 'Outras Versões';

  @override
  String get gameDetail_readMore => 'Ler mais...';

  @override
  String get gameDetail_showLess => 'Mostrar menos';

  @override
  String get gameDetail_standard => 'Padrão';

  @override
  String get gameDetail_franchise => 'Franquia';

  @override
  String get gameDetail_gameModes => 'Modos de Jogo';

  @override
  String get gameDetail_perspective => 'Perspectiva';

  @override
  String get gameDetail_ageRating => 'Classificação Etária';

  @override
  String get gameDetail_themes => 'Temas';

  @override
  String get gameDetail_fileTags => 'TAGS DO ARQUIVO';

  @override
  String get gameDetail_tagVersion => 'Versão';

  @override
  String get gameDetail_tagBuild => 'Build';

  @override
  String get gameDetail_tagDisc => 'Disco';

  @override
  String get gameDetail_tagQuality => 'Qualidade';

  @override
  String get gameDetail_tagInfo => 'Info';

  @override
  String get gameDetail_tagTechnical => 'Técnico';

  @override
  String get gameDetail_gameInfo => 'Info do Jogo';

  @override
  String get gameDetail_showTitle => 'Mostrar Título';

  @override
  String get gameDetail_showFilename => 'Mostrar Arquivo';

  @override
  String gameDetail_fromProvider(String provider) {
    return 'de $provider';
  }

  @override
  String get gameDetail_addToShelf => 'Adicionar à Estante';

  @override
  String get gameDetail_removeFromShelf => 'Remover da Estante';

  @override
  String get gameDetail_removeFromShelfTitle => 'REMOVER DA ESTANTE';

  @override
  String get gameDetail_gameNotInstalled => 'Jogo não está instalado';

  @override
  String get gameDetail_couldNotShare =>
      'Não foi possível compartilhar o arquivo';

  @override
  String get gameDetail_pressAPickVersion => 'Aperte A pra escolher uma versão';

  @override
  String get gameDetail_pressAManage => 'Aperte A pra gerenciar';

  @override
  String get gameDetail_pressADownload => 'Aperte A pra baixar';

  @override
  String gameDetail_errorPrefix(String error) {
    return 'Erro: $error';
  }

  @override
  String get settings_title => 'CONFIGURAÇÕES';

  @override
  String get settings_tabGeneral => 'Geral';

  @override
  String get settings_tabAudio => 'Áudio';

  @override
  String get settings_tabAdvanced => 'Avançado';

  @override
  String get settings_tabAbout => 'Sobre';

  @override
  String get settings_previousTab => 'Aba Anterior';

  @override
  String get settings_nextTab => 'Próxima Aba';

  @override
  String get settings_resetApp => 'Resetar App';

  @override
  String get settings_resetDialogTitle => 'RESETAR APLICATIVO';

  @override
  String get settings_resetDialogMessage =>
      'Isso vai apagar todas as configurações e reiniciar a configuração.';

  @override
  String get settings_resetDialogConfirm => 'RESETAR';

  @override
  String get settings_resetDialogCancel => 'CANCELAR';

  @override
  String get settings_sectionLibrary => 'Biblioteca';

  @override
  String get settings_sectionDisplay => 'Tela';

  @override
  String get settings_mySources => 'Minhas Fontes';

  @override
  String get settings_mySourcesSubtitle =>
      'Adicionar ou gerenciar servidores RomM, SMB, FTP';

  @override
  String get settings_consoleSettings => 'Config. de Consoles';

  @override
  String get settings_consoleSettingsSubtitle =>
      'Pastas, extração, opções por sistema';

  @override
  String get settings_retroAchievements => 'RetroAchievements';

  @override
  String get settings_retroAchievementsSubtitle =>
      'Conquistas e verificação de ROM';

  @override
  String get settings_homeLayout => 'Layout da Home';

  @override
  String get settings_homeLayoutGrid => 'Grade';

  @override
  String get settings_homeLayoutCarousel => 'Carrossel Horizontal';

  @override
  String get settings_hideEmptyConsoles => 'Ocultar Consoles Vazios';

  @override
  String get settings_hideEmptyConsolesSubtitle =>
      'Mostrar só sistemas com jogos';

  @override
  String get settings_controllerButtons => 'Botões do Controle';

  @override
  String get settings_controllerNintendo => 'Nintendo (padrão)';

  @override
  String get settings_controllerXbox => 'XBOX';

  @override
  String get settings_controllerPs => 'PS';

  @override
  String get settings_controllerNin => 'NIN';

  @override
  String get settings_sectionFeedback => 'Feedback';

  @override
  String get settings_vibration => 'Vibração';

  @override
  String get settings_vibrationSubtitle => 'Vibrar ao pressionar botões';

  @override
  String get settings_soundEffects => 'Efeitos Sonoros';

  @override
  String get settings_soundEffectsSubtitle => 'Tocar sons nas ações do menu';

  @override
  String get settings_sectionVolume => 'Volume';

  @override
  String get settings_music => 'Música';

  @override
  String get settings_musicSubtitle => 'Música de fundo ambiente';

  @override
  String get settings_effects => 'Efeitos';

  @override
  String get settings_effectsSubtitle => 'Efeitos sonoros da interface';

  @override
  String get settings_sectionDownloads => 'Downloads';

  @override
  String get settings_simultaneousDownloads => 'Downloads Simultâneos';

  @override
  String get settings_simultaneousDownloadsSubtitle =>
      'Quantos arquivos baixar de uma vez';

  @override
  String get settings_downloadAllCovers => 'BAIXAR TODAS AS CAPAS';

  @override
  String get settings_downloadingCovers => 'BAIXANDO CAPAS...';

  @override
  String get settings_sectionSync => 'Sincronização';

  @override
  String get settings_syncTimeout => 'Timeout de Sinc.';

  @override
  String get settings_syncTimeoutSubtitle =>
      'Quanto tempo esperar cada servidor';

  @override
  String get settings_autoSyncInterval => 'Intervalo de Auto-Sinc.';

  @override
  String get settings_autoSyncIntervalSubtitle =>
      'Tempo mínimo entre sincs automáticas';

  @override
  String get settings_sectionDebug => 'Debug';

  @override
  String get settings_allowInsecure => 'Permitir Conexões Inseguras';

  @override
  String get settings_allowInsecureSubtitle =>
      'Habilitar HTTP para servidores sem HTTPS';

  @override
  String get settings_exportErrorLog => 'Exportar Log de Erros';

  @override
  String get settings_exportErrorLogSubtitle =>
      'Compartilhar log de erros pra diagnóstico';

  @override
  String get settings_sectionInfo => 'Info';

  @override
  String get settings_sectionLinks => 'Links';

  @override
  String get settings_github => 'GitHub';

  @override
  String get settings_githubSubtitle => 'Ver código fonte no GitHub';

  @override
  String get settings_issues => 'Problemas';

  @override
  String get settings_issuesSubtitle =>
      'Reportar bugs ou pedir funcionalidades';

  @override
  String get settings_tagline => 'INTENSIV, AGGRESSIV, MUTIG';

  @override
  String get settings_deviceMemoryLow => 'BAIXA';

  @override
  String get settings_deviceMemoryStandard => 'PADRÃO';

  @override
  String get settings_deviceMemoryHigh => 'ALTA';

  @override
  String get settings_fetchingCovers => 'Buscando capas...';

  @override
  String settings_coversResult(int ok, int failed) {
    return 'Capas: $ok ok, $failed falharam';
  }

  @override
  String settings_coversLoaded(int count) {
    return '$count capas carregadas!';
  }

  @override
  String get settings_noErrorLog => 'Nenhum log de erro disponível';

  @override
  String get settings_configImported => 'Config importada!';

  @override
  String get settings_controllerXboxFull => 'Xbox (A/B e X/Y invertidos)';

  @override
  String get settings_controllerPlaystationFull => 'PlayStation (✕ ○ □ △)';

  @override
  String get settings_allCoversCached => 'Todas as capas em cache';

  @override
  String get settings_downloadCoverArt => 'Baixar capas de todos os jogos';

  @override
  String settings_coverCacheInfo(String size, int count) {
    return '$size ($count em cache)';
  }

  @override
  String settings_coversRemaining(int count, String size) {
    return '$count restantes (~$size MB)';
  }

  @override
  String settings_coversProgress(int completed, int total) {
    return '$completed / $total jogos';
  }

  @override
  String get configMode_title => 'CONFIG. DE CONSOLES';

  @override
  String get configMode_globalTitle => 'CONFIG. GLOBAL';

  @override
  String get configMode_noFolderSet => 'Nenhuma pasta definida';

  @override
  String get configMode_notConfigured => 'Não configurado';

  @override
  String get configMode_export => 'Exportar';

  @override
  String get configMode_import => 'Importar';

  @override
  String get systemDetail_sectionStorage => 'Armazenamento';

  @override
  String get systemDetail_selectRomFolder => 'Selecionar pasta de ROMs';

  @override
  String get systemDetail_tapToChangeFolder => 'Toque pra trocar a pasta';

  @override
  String get systemDetail_sectionBehavior => 'Comportamento';

  @override
  String get systemDetail_autoExtractZips => 'Auto-Extrair ZIPs';

  @override
  String get systemDetail_autoExtractEnabled =>
      'ROMs zipadas são extraídas após download';

  @override
  String get systemDetail_autoExtractDisabled =>
      'ROMs ficam zipadas após download';

  @override
  String get systemDetail_autoSyncOnLaunch => 'Auto-Sinc. ao Iniciar';

  @override
  String get systemDetail_autoSyncEnabled =>
      'Sincroniza automaticamente (respeita cooldown)';

  @override
  String get systemDetail_autoSyncDisabled =>
      'Só sincroniza manualmente pelo menu Start';

  @override
  String get systemDetail_sectionSources => 'Fontes';

  @override
  String get sources_title => 'FONTES';

  @override
  String get sources_noSourcesConfigured => 'Nenhuma fonte configurada';

  @override
  String get sources_noSourcesYet => 'Nenhuma fonte ainda';

  @override
  String get sources_noSourcesDescription =>
      'Pareie um servidor RomM pra começar a baixar jogos. ';

  @override
  String get sources_addSource => 'Adicionar fonte';

  @override
  String get sources_whereDoGamesComeFrom => 'De onde vêm seus jogos?';

  @override
  String get sources_sourceTypeRomm => 'Servidor RomM';

  @override
  String get sources_sourceTypeRommHint =>
      'Pareie via QR ou código de 8 dígitos';

  @override
  String get sources_sourceTypeRommLegacy => 'RomM Login (servidores antigos)';

  @override
  String get sources_sourceTypeSmb => 'Compartilhamento SMB';

  @override
  String get sources_sourceTypeFtp => 'Servidor FTP';

  @override
  String get sources_sourceTypeWeb => 'Mirror Web';

  @override
  String get sources_sourceTypeWebHint => 'Listagem de diretório HTTPS';

  @override
  String get sources_expired => 'EXPIRADO';

  @override
  String get sources_borrowed => 'EMPRESTADO';

  @override
  String get sources_off => 'OFF';

  @override
  String get sources_noPlatforms => 'Sem plataformas';

  @override
  String get sources_rePair => 'Parear de novo';

  @override
  String get sources_editMappings => 'Editar mapeamentos';

  @override
  String get sources_disable => 'Desabilitar';

  @override
  String get sources_enable => 'Habilitar';

  @override
  String get manualSource_defaultNameSmb => 'Meu NAS';

  @override
  String get manualSource_defaultNameFtp => 'Meu FTP';

  @override
  String get manualSource_defaultNameWeb => 'Mirror Web';

  @override
  String get manualSource_defaultNameOther => 'Fonte';

  @override
  String get manualSource_name => 'Nome';

  @override
  String get manualSource_url => 'URL';

  @override
  String get manualSource_urlHint => 'https://exemplo.com/roms';

  @override
  String get manualSource_host => 'Host';

  @override
  String get manualSource_hostHint => 'nas.local ou 192.168.1.10';

  @override
  String get manualSource_port => 'Port';

  @override
  String get manualSource_share => 'Compartilhamento';

  @override
  String get manualSource_shareHint => 'roms';

  @override
  String get manualSource_usernameOptional => 'Usuário (opcional)';

  @override
  String get manualSource_usernameHint => 'deixe em branco pra convidado';

  @override
  String get manualSource_passwordOptional => 'Senha (opcional)';

  @override
  String get manualSource_nameRequired => 'Nome é obrigatório';

  @override
  String get manualSource_urlRequired => 'URL é obrigatória';

  @override
  String get manualSource_hostRequired => 'Host é obrigatório';

  @override
  String get manualSource_shareRequired => 'Compartilhamento é obrigatório';

  @override
  String get manualSource_saveSource => 'Salvar fonte';

  @override
  String get manualSource_smb => 'SMB';

  @override
  String get manualSource_ftp => 'FTP';

  @override
  String get manualSource_web => 'Web';

  @override
  String get manualSource_searchingNetwork => 'Buscando na rede…';

  @override
  String get manualSource_foundOnNetwork => 'Encontrado na sua rede';

  @override
  String get sourceMappings_title => 'Mapeamento de sistemas';

  @override
  String get sourceMappings_instruction =>
      'Digite a pasta remota de cada sistema que essa fonte deve servir. Deixe em branco pra pular.';

  @override
  String get sourceMappings_save => 'Salvar mapeamentos';

  @override
  String get library_title => 'BIBLIOTECA';

  @override
  String get library_tabAll => 'Todos';

  @override
  String get library_tabInstalled => 'Instalados';

  @override
  String get library_tabFavorites => 'Favoritos';

  @override
  String get library_sortSystem => 'Ordenar por Sistema';

  @override
  String get library_sortManual => 'Ordem Manual';

  @override
  String get library_sortAZ => 'Ordenar A-Z';

  @override
  String get library_sortIndicatorAZ => 'A-Z';

  @override
  String get library_sortIndicatorBySystem => 'POR SISTEMA';

  @override
  String get library_sortIndicatorManual => 'MANUAL';

  @override
  String get library_searchHint => 'Buscar na biblioteca...';

  @override
  String get library_zoomIn => 'Mais Zoom';

  @override
  String get library_zoomOut => 'Menos Zoom';

  @override
  String get library_newShelf => 'Nova Estante';

  @override
  String get library_editShelf => 'Editar Estante';

  @override
  String get library_addToShelf => 'Adicionar à Estante';

  @override
  String get library_removeFromShelf => 'Remover da Estante';

  @override
  String get library_reorderGames => 'Reordenar Jogos';

  @override
  String library_noResults(String query) {
    return 'Sem resultados para \"$query\"';
  }

  @override
  String get library_tryShorterSearch => 'Tente um termo mais curto';

  @override
  String get library_noInstalledGames => 'Nenhum jogo instalado';

  @override
  String get library_downloadGamesToSee => 'Baixe jogos pra ver aqui';

  @override
  String get library_noFavoritesYet => 'Nenhum favorito ainda';

  @override
  String get library_pressFavoriteHint =>
      'Aperte SELECT num jogo pra favoritar';

  @override
  String get library_noGamesInShelf => 'Nenhum jogo nessa estante';

  @override
  String get library_addGamesViaEditor =>
      'Adicione jogos pelo editor da estante';

  @override
  String get library_noGamesInLibrary => 'Nenhum jogo na biblioteca';

  @override
  String get library_gamesAfterSync =>
      'Os jogos vão aparecer após a sincronização';

  @override
  String get shelfEdit_title => 'EDITAR ESTANTE';

  @override
  String get shelfEdit_titleNew => 'NOVA ESTANTE';

  @override
  String get shelfEdit_nameSection => 'NOME';

  @override
  String get shelfEdit_shelfName => 'Nome da Estante';

  @override
  String get shelfEdit_filterText => 'Texto do Filtro';

  @override
  String get shelfEdit_tapToSet => 'Toque pra definir...';

  @override
  String get shelfEdit_filterRules => 'REGRAS DE FILTRO';

  @override
  String get shelfEdit_resetManualOrder => 'Resetar Ordem Manual';

  @override
  String get shelfEdit_saveButton => 'SALVAR';

  @override
  String get shelfEdit_deleteShelf => 'APAGAR ESTANTE';

  @override
  String get shelfEdit_anyText => 'Qualquer texto';

  @override
  String get shelfEdit_allSystems => 'Todos os sistemas';

  @override
  String get shelfPicker_title => 'ADICIONAR À ESTANTE';

  @override
  String get systemSelector_title => 'SELECIONAR SISTEMAS';

  @override
  String get textInput_hint => 'Digite o texto...';

  @override
  String get textInput_ok => 'OK';

  @override
  String get gameListOverlay_hiddenGames => 'JOGOS OCULTOS';

  @override
  String get gameListOverlay_addedGames => 'JOGOS ADICIONADOS';

  @override
  String get gameListOverlay_restore => 'Restaurar';

  @override
  String get gameListOverlay_noGames => 'Nenhum jogo';

  @override
  String get gameListOverlay_clearAll => 'Limpar Tudo';

  @override
  String get home_allGames => 'TODOS OS JOGOS';

  @override
  String get home_library => 'Biblioteca';

  @override
  String get home_noConsoles => 'Nenhum console configurado';

  @override
  String get home_pressStartForMenu => 'Aperte Start pro Menu';

  @override
  String get home_settings => 'Configurações';

  @override
  String home_syncSystem(String system) {
    return 'Sincronizar $system';
  }

  @override
  String get home_syncAll => 'Sincronizar Tudo';

  @override
  String get home_lastSyncNever => 'Nunca sincronizado';

  @override
  String get home_lastSyncJustNow => 'Sincronizado agora';

  @override
  String home_lastSyncMinutes(int minutes) {
    return 'Sincronizado há ${minutes}min';
  }

  @override
  String home_lastSyncHours(int hours) {
    return 'Sincronizado há ${hours}h';
  }

  @override
  String home_lastSyncDays(int days) {
    return 'Sincronizado há ${days}d';
  }

  @override
  String get common_exit => 'Sair';

  @override
  String gameList_gamesCount(int count) {
    return '$count Jogos';
  }

  @override
  String get gameList_offline => 'Offline';

  @override
  String get gameList_zoomIn => 'Mais Zoom';

  @override
  String get gameList_zoomOut => 'Menos Zoom';

  @override
  String get gameList_filterActive => 'Filtro (ativo)';

  @override
  String get gameList_filter => 'Filtro';

  @override
  String gameList_noGamesMatchSearch(String query) {
    return 'Nenhum jogo encontrado pra \'$query\'';
  }

  @override
  String get gameList_tryShorterSearch => 'Tente um termo mais curto';

  @override
  String get gameList_noGamesMatchFilters =>
      'Nenhum jogo com os filtros atuais';

  @override
  String get gameList_changeFilters => 'Mude ou resete os filtros no menu';

  @override
  String gameList_noRomsFound(String folder) {
    return 'Nenhuma ROM encontrada em $folder';
  }

  @override
  String get gameList_addRomFiles =>
      'Adicione arquivos ROM nessa pasta e atualize';

  @override
  String get gameList_couldNotLoadGames => 'Não foi possível carregar os jogos';

  @override
  String get gameList_checkConnection =>
      'Verifique sua conexão e tente de novo';

  @override
  String get gameList_errorLoadingGames => 'Erro ao carregar jogos';

  @override
  String get gameList_gamesAppearShortly => 'Os jogos vão aparecer em breve';

  @override
  String get gameList_syncingLibrary => 'Sincronizando biblioteca…';

  @override
  String get gameList_localFilesOnly =>
      'Só arquivos locais · Adicione um provedor pra baixar mais';

  @override
  String get gameList_pressMenuHint => 'Aperte  +  pro menu';

  @override
  String filter_activeCount(int count) {
    return '$count ativos';
  }

  @override
  String get shelfEdit_addFilter => '+ ADICIONAR FILTRO';

  @override
  String shelfEdit_hiddenGamesCount(int count) {
    return 'Jogos Ocultos ($count)';
  }

  @override
  String shelfEdit_addedGamesCount(int count) {
    return 'Jogos Adicionados ($count)';
  }

  @override
  String get shelfEdit_textHint => '← Texto  Sist →';

  @override
  String gameListOverlay_gameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$_temp0';
  }

  @override
  String gameListOverlay_actionHint(String action) {
    return 'A: $action';
  }

  @override
  String systemSelector_selectedCount(int count) {
    return '$count selecionados';
  }

  @override
  String get filter_favoritesOnly => 'Só Favoritos';

  @override
  String get filter_installedOnly => 'Só Instalados';

  @override
  String get filter_regions => 'REGIÕES';

  @override
  String get filter_languages => 'IDIOMAS';

  @override
  String get filter_title => 'FILTRO';

  @override
  String get onboarding_welcomeTitle => 'Bem-vindo ao R-Shop';

  @override
  String get onboarding_welcomeSubtitle => 'De onde vêm seus jogos?';

  @override
  String get onboarding_pairQrTitle => 'Parear RomM via QR';

  @override
  String get onboarding_pairQrSubtitle =>
      'Escaneie um código do seu servidor RomM';

  @override
  String get onboarding_legacyLoginTitle => 'RomM login (servidores antigos)';

  @override
  String get onboarding_legacyLoginSubtitle => 'Usuário + senha pra RomM < 4.8';

  @override
  String get onboarding_addServerTitle => 'Adicionar meu servidor';

  @override
  String get onboarding_addServerSubtitle =>
      'SMB, FTP ou mirror Web — mapeie sistemas manualmente';

  @override
  String get onboarding_localOnlyTitle => 'Só jogos locais';

  @override
  String get onboarding_localOnlySubtitle => 'ROMs já estão neste dispositivo';

  @override
  String get onboarding_working => 'Trabalhando…';

  @override
  String get onboarding_scanningFolders => 'Escaneando pastas de ROM locais…';

  @override
  String get onboarding_discoveringPlatforms => 'Descobrindo plataformas…';

  @override
  String get onboarding_savingSource => 'Salvando fonte…';

  @override
  String get onboarding_allSet => 'Tudo pronto';

  @override
  String get onboarding_noSystems =>
      'Nenhum sistema configurado ainda — você pode adicionar fontes depois em Configurações.';

  @override
  String onboarding_systemsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sistemas prontos pra navegar',
      one: '1 sistema pronto pra navegar',
    );
    return '$_temp0';
  }

  @override
  String get onboarding_jumpIn => 'Bora lá';

  @override
  String get onboarding_jumpInSubtitle =>
      'Abrir a tela inicial e começar a sincronizar';

  @override
  String get onboarding_retroachievements => 'RetroAchievements';

  @override
  String get onboarding_retroachievementsSubtitle =>
      'Acompanhe suas conquistas de jogos retrô';

  @override
  String get onboarding_exportConfig => 'Exportar config';

  @override
  String get onboarding_exportConfigSubtitle =>
      'Reutilize essa configuração em outro dispositivo';

  @override
  String get onboarding_importConfig => 'Importar config';

  @override
  String get onboarding_configImported => 'Config importada!';

  @override
  String onboarding_exportFailed(String error) {
    return 'Falha ao exportar: $error';
  }

  @override
  String onboarding_invalidConfig(String error) {
    return 'Config inválida: $error';
  }

  @override
  String onboarding_failedToSave(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get onboarding_selectFolderPrompt =>
      'Escolha a pasta onde as ROMs devem ser salvas';

  @override
  String get onboarding_serverType => 'Tipo de servidor';

  @override
  String get onboarding_folderExplanationTitle =>
      'Configure o caminho da sua biblioteca';

  @override
  String get onboarding_folderExplanationMessage =>
      'O R-Shop precisa de uma pasta base para guardar os jogos baixados. Isso ajuda a organizar seus arquivos e é necessário para as permissões de pasta do Android.\n\nRecomendamos criar uma pasta chamada \'ROMs\' e selecioná-la.';

  @override
  String get onboarding_continueToPicker => 'Selecionar pasta';

  @override
  String get onboarding_hangOn => 'Um momento, testando a conexão...';

  @override
  String get onboarding_foundConsole =>
      'Achei esse console no seu servidor RomM! Confirme ou escolha outro.';

  @override
  String get onboarding_pickPlatform =>
      'Escolha a plataforma correspondente no seu servidor RomM.';

  @override
  String get onboarding_couldNotReach =>
      'Não consegui alcançar seu servidor RomM. Verifique a URL e tente de novo.';

  @override
  String get onboarding_connectionGood =>
      'Conexão tá boa! Tudo pronto pra salvar essa fonte.';

  @override
  String get onboarding_couldNotConnect =>
      'Hmm, não consegui conectar. Confira o endereço e as credenciais.';

  @override
  String get onboarding_whatKindOfSource =>
      'Que tipo de fonte é essa? Escolha o tipo de conexão.';

  @override
  String get onboarding_lookingGood =>
      'Tá ótimo! Adicione mais fontes ou aperte Pronto quando estiver ok.';

  @override
  String get onboarding_localCollection =>
      'Essa é uma coleção local. Adicione uma fonte pra baixar mais, ou só aperte Pronto!';

  @override
  String get onboarding_addMoreSources =>
      'Agora adicione pelo menos uma fonte pra eu saber onde achar as ROMs.';

  @override
  String get onboarding_letsSetUp =>
      'Vamos configurar seus consoles! Selecione qualquer sistema pra começar.';

  @override
  String get onboarding_romFolder => 'PASTA DE ROMs';

  @override
  String get onboarding_options => 'OPÇÕES';

  @override
  String get onboarding_autoExtractZips => 'Auto-extrair ROMs zipadas';

  @override
  String get onboarding_autoSyncLabel => 'Auto-sinc. ao abrir o app';

  @override
  String get onboarding_autoSyncEnabled =>
      'Sincroniza automaticamente (respeita cooldown)';

  @override
  String get onboarding_autoSyncDisabled =>
      'Só sincroniza manualmente pelo menu Start';

  @override
  String get onboarding_selectFolder => 'Selecionar pasta...';

  @override
  String get providerForm_addSource => 'Adicionar Fonte';

  @override
  String get providerForm_editSource => 'Editar Fonte';

  @override
  String get providerForm_url => 'URL';

  @override
  String get providerForm_urlPlaceholder => 'https://...';

  @override
  String get providerForm_path => 'Caminho';

  @override
  String get providerForm_pathPlaceholder => '/roms/nes/ (opcional)';

  @override
  String get providerForm_username => 'Usuário';

  @override
  String get providerForm_usernameOptional => '(opcional)';

  @override
  String get providerForm_password => 'Senha';

  @override
  String get providerForm_host => 'Host';

  @override
  String get providerForm_hostPlaceholder => '192.168.1.100';

  @override
  String get providerForm_port => 'Port';

  @override
  String get providerForm_share => 'Compartilhamento';

  @override
  String get providerForm_sharePlaceholder => 'roms';

  @override
  String get providerForm_domain => 'Domínio';

  @override
  String get providerForm_domainOptional => '(opcional)';

  @override
  String get providerForm_rommUrl => 'URL';

  @override
  String get providerForm_rommUrlPlaceholder => 'https://romm.exemplo.com';

  @override
  String get providerForm_apiKey => 'API Key';

  @override
  String get providerForm_apiKeyOptional => '(opcional)';

  @override
  String get providerForm_httpBlocked =>
      'HTTP pra servidores não-locais é bloqueado. Use HTTPS, ou habilite depois em Configurações.';

  @override
  String get providerForm_httpWarning =>
      'Credenciais serão enviadas sem criptografia via HTTP';

  @override
  String get providerForm_testingConnection => 'Testando conexão...';

  @override
  String get providerForm_connectionSuccessful => 'Conexão bem-sucedida!';

  @override
  String get providerForm_fetchingPlatforms => 'Buscando plataformas...';

  @override
  String get providerForm_noPlatformsFound =>
      'Nenhuma plataforma encontrada neste servidor RomM.';

  @override
  String get providerForm_platform => 'PLATAFORMA';

  @override
  String get providerForm_pickPlatform => 'Escolha uma plataforma...';

  @override
  String get providerForm_testAndSave => 'Testar e Salvar';

  @override
  String get providerForm_connectionFailed => 'Falha na conexão';

  @override
  String get providerForm_hostMissing => 'Host';

  @override
  String get providerForm_portMissing => 'Port';

  @override
  String get providerForm_pathMissing => 'Caminho';

  @override
  String get providerForm_shareMissing => 'Compartilhamento';

  @override
  String get providerForm_urlMissing => 'URL';

  @override
  String get rommLogin_title => 'Login no RomM';

  @override
  String get rommLogin_name => 'Nome';

  @override
  String get rommLogin_nameDefault => 'Meu RomM';

  @override
  String get rommLogin_serverUrl => 'URL do Servidor';

  @override
  String get rommLogin_username => 'Usuário';

  @override
  String get rommLogin_usernameHint => 'admin';

  @override
  String get rommLogin_password => 'Senha';

  @override
  String get rommLogin_passwordHint => '••••••••';

  @override
  String get rommLogin_nameRequired => 'Nome é obrigatório';

  @override
  String get rommLogin_serverUrlRequired => 'URL do servidor é obrigatória';

  @override
  String get rommLogin_credentialsRequired => 'Usuário ou senha obrigatórios';

  @override
  String get ra_title => 'RetroAchievements';

  @override
  String get ra_subtitle => 'Acompanhe suas conquistas de jogos retrô. ';

  @override
  String get ra_usernameLabel => 'Usuário';

  @override
  String get ra_usernameHint => 'seu usuário RA';

  @override
  String get ra_apiKeyLabel => 'API Key';

  @override
  String get ra_apiKeyHint => 'cole de retroachievements.org';

  @override
  String get ra_usernameRequired => 'Usuário é obrigatório';

  @override
  String get ra_apiKeyRequired => 'API Key é obrigatória';

  @override
  String get ra_connectionFailed => 'Falha na conexão';

  @override
  String get ra_disconnect => 'Desconectar';

  @override
  String get ra_syncNow => 'Sincronizar conquistas agora';

  @override
  String get ra_skipForNow => 'Pular por enquanto';

  @override
  String get pairing_scanQrTitle => 'Escanear código QR';

  @override
  String get pairing_scanQrHint => 'Segure o código QR dentro da moldura';

  @override
  String get pairing_enterManually => 'Digitar código manualmente';

  @override
  String get pairing_invalidQr =>
      'Código QR não é um link de pareamento RomM válido';

  @override
  String get pairing_manualTitle => 'Pareamento manual';

  @override
  String get pairing_manualInstructions =>
      'Gere o código na interface web do RomM em ';

  @override
  String get pairing_serverUrl => 'URL do Servidor';

  @override
  String get pairing_pairingCode => 'Código de pareamento';

  @override
  String get pairing_pairingCodeHint => 'ABCD-1234';

  @override
  String get pairing_probingServer => 'Verificando servidor…';

  @override
  String get pairing_serverNotReachable =>
      'Servidor não acessível ou não é uma instância RomM';

  @override
  String get pairing_serverUrlRequired =>
      'URL do servidor e código são obrigatórios';

  @override
  String get pairing_successTitle => 'Pareamento bem-sucedido';

  @override
  String get pairing_server => 'Servidor';

  @override
  String get pairing_token => 'Token';

  @override
  String get pairing_userId => 'ID do Usuário';

  @override
  String get pairing_expiry => 'Validade';

  @override
  String get pairing_neverExpires => 'Nunca expira';

  @override
  String get pairing_alreadyExpired => 'Já expirou';

  @override
  String get pairing_permissions => 'PERMISSÕES';

  @override
  String get pairing_addServer => 'Adicionar servidor';

  @override
  String get service_notificationTitle => 'R-Shop';

  @override
  String get service_channelName => 'Downloads';

  @override
  String get service_channelDescription => 'Mostra o progresso ao baixar jogos';

  @override
  String get service_downloadComplete => 'Downloads concluídos';

  @override
  String service_downloading(String details) {
    return 'Baixando: $details';
  }

  @override
  String service_activeCount(int count) {
    return '$count ativos';
  }

  @override
  String service_queuedCount(int count) {
    return '$count na fila';
  }

  @override
  String get sources_connectionRoute => 'Rota de ligação';

  @override
  String get sources_routeAuto => 'Automático';

  @override
  String get sources_routeAutoHint =>
      'Usar a rota mais rápida que responder; volta a verificar quando a rede muda';

  @override
  String get sources_routeInUse => 'Em uso';

  @override
  String get sources_routePinned => 'Fixada';

  @override
  String get sources_routeReachable => 'Acessível';

  @override
  String get sources_routeNoAnswer => 'Sem resposta';

  @override
  String get sources_routeChecking => 'A verificar…';

  @override
  String sources_routeLatencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String sources_routeAutoPicks(String route) {
    return 'Usaria $route';
  }

  @override
  String get sources_routeAutoNoneReachable => 'Nada respondeu';

  @override
  String get sources_routeFastest => 'Mais rápida';

  @override
  String get sources_routeReleasePin =>
      'Liberta a fixação e volta a escolher a mais rápida';

  @override
  String get sources_routeOwnLogin => 'Início de sessão próprio';

  @override
  String get sources_routeAuthTitle => 'Início de sessão desta rota';

  @override
  String get sources_routeAuthHint =>
      'Deixe em branco para usar o início de sessão da fonte. Preencha apenas se este endereço pedir outro.';

  @override
  String get sources_routeAuthInherited => 'A usar o início de sessão da fonte';

  @override
  String get sources_routeAuthOwn => 'Esta rota inicia sessão por si própria';

  @override
  String get sources_routeOnlyOne => 'Esta fonte só tem uma rota';

  @override
  String get sources_addRoute => 'Adicionar rota';

  @override
  String get sources_editRoute => 'Editar rota';

  @override
  String get sources_removeRoute => 'Remover rota';

  @override
  String get sources_routeDuplicate =>
      'Esta fonte já tem uma rota para esse endereço';

  @override
  String get sources_activeSource => 'Em uso';

  @override
  String get sources_switchSource => 'Mudar fonte';

  @override
  String get sources_prevSource => 'Fonte anterior';

  @override
  String get sources_nextSource => 'Fonte seguinte';

  @override
  String get sources_setFallback => 'Fonte de reserva';

  @override
  String get sources_fallbackNone => 'Nenhuma';

  @override
  String get sources_fallbackShort => 'Reserva';

  @override
  String get sources_routeSameServerHint =>
      'Todas as rotas chegam ao mesmo servidor. Uma rota pode ter o seu próprio início de sessão se esse endereço pedir outro.';

  @override
  String get sources_routeCannotRemoveLast =>
      'Não é possível remover a última rota';

  @override
  String sources_countLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fontes',
      one: '1 fonte',
    );
    return '$_temp0';
  }

  @override
  String get sources_useThisShort => 'Usar esta';

  @override
  String get sources_stopUsingShort => 'Parar de usar';

  @override
  String get sources_removeConfirmTitle => 'Remover a fonte?';

  @override
  String sources_removeConfirmMessage(String name) {
    return 'Remover \"$name\"? A lista dela desaparece da biblioteca, mas os jogos já baixados neste aparelho são mantidos.';
  }

  @override
  String get sources_groupBadge => 'Grupo';

  @override
  String get sources_groupCreate => 'Agrupar com outra fonte…';

  @override
  String get sources_groupCreateHint =>
      'Para dois endereços que são, na verdade, o mesmo servidor';

  @override
  String get sources_groupPickMember => 'Escolha a fonte para agrupar';

  @override
  String get sources_groupSameTypeOnly =>
      'Só é possível agrupar fontes do mesmo tipo';

  @override
  String get sources_groupNoCandidates => 'Não há outra fonte deste tipo';

  @override
  String get sources_groupManage => 'Definições do grupo';

  @override
  String get sources_groupRename => 'Mudar o nome do grupo';

  @override
  String get sources_groupNameLabel => 'Nome do grupo';

  @override
  String get sources_groupModeTitle => 'Qual membro usar';

  @override
  String get sources_groupModeAuto => 'Automático';

  @override
  String get sources_groupModeAutoHint =>
      'Sem ordem a manter — o endereço que responde primeiro é o que dá para usar primeiro';

  @override
  String get sources_groupModeOrdered => 'A minha ordem';

  @override
  String get sources_groupModeOrderedHint =>
      'Usa o primeiro da tua ordem que responder';

  @override
  String get sources_groupPreferred => 'Primeira escolha';

  @override
  String get sources_groupAddMember => 'Adicionar uma fonte';

  @override
  String get sources_groupLeave => 'Sair do grupo';

  @override
  String sources_groupLeaveConfirm(String name) {
    return '«$name» não fica com jogos nenhuns e terá de sincronizar de novo. A lista partilhada fica com o grupo.';
  }

  @override
  String get sources_groupLeaveTitle => 'Sair do grupo?';

  @override
  String get sources_groupDissolve => 'Dissolver o grupo';

  @override
  String sources_groupDissolveConfirm(String name) {
    return 'A lista partilhada fica com «$name»; as outras terão de sincronizar de novo.';
  }

  @override
  String get sources_groupDissolveTitle => 'Dissolver o grupo?';

  @override
  String sources_groupMembersCount(int count) {
    return '$count fontes';
  }

  @override
  String sources_groupUsing(String name) {
    return 'A usar «$name»';
  }

  @override
  String get sources_moveUp => 'Mover para cima';

  @override
  String get sources_moveDown => 'Mover para baixo';

  @override
  String get sources_routeOrdered => 'A minha ordem';

  @override
  String get sources_routeOrderedHint =>
      'Usar a primeira rota da tua ordem que responder';

  @override
  String get sources_reorderHint =>
      'Move com cima e baixo e carrega outra vez para terminar';

  @override
  String get sources_groupMemberHint => '▶ tira-a do grupo; [A] reordena';

  @override
  String get sources_routeRowHint =>
      'Seleciona a linha para reordenar; ▶ para os ícones: editar ou remover';

  @override
  String get sources_routeUse => 'Usar esta rota';

  @override
  String get sources_routeLock => 'Bloquear nesta rota';

  @override
  String get sources_routeUnlock => 'Desbloquear';

  @override
  String sources_removeRouteConfirm(String name) {
    return 'Remover «$name»? A lista guardada desta fonte fica; só desaparece o endereço.';
  }
}
