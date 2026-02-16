import 'dart:io';
import 'dart:ui';
import '../models/system_model.dart';

class FolderInfo {
  final String folderName;
  final String systemName;
  final bool exists;
  final int gameCount;
  final Color accentColor;
  const FolderInfo({
    required this.folderName,
    required this.systemName,
    required this.exists,
    required this.gameCount,
    required this.accentColor,
  });
}

class FolderAnalysisResult {
  final List<FolderInfo> folders;
  final int totalGames;
  final int existingFoldersCount;
  final int missingFoldersCount;
  const FolderAnalysisResult({
    required this.folders,
    required this.totalGames,
    required this.existingFoldersCount,
    required this.missingFoldersCount,
  });
  List<FolderInfo> get missingFolders =>
      folders.where((f) => !f.exists).toList();
  List<FolderInfo> get existingFolders =>
      folders.where((f) => f.exists).toList();
}

class RomFolderService {
  static const ignoredFolders = {'3dsupdates', 'switchupdates'};
  List<String> get supportedFolderNames =>
      SystemModel.supportedSystems.map((s) => s.esdeFolder).toList();
  Future<int> _countGamesInFolder(
      String folderPath, List<String> extensions) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return 0;
    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.path.toLowerCase();
        final hasValidExt = extensions.any((ext) => name.endsWith(ext));
        if (hasValidExt || name.endsWith('.zip') || name.endsWith('.7z')) {
          count++;
        }
      }
    }
    return count;
  }

  Future<FolderAnalysisResult> analyze(String romPath) async {
    final folders = <FolderInfo>[];
    int totalGames = 0;
    int existingCount = 0;
    int missingCount = 0;
    for (final system in SystemModel.supportedSystems) {
      final folderPath = '$romPath/${system.esdeFolder}';
      final dir = Directory(folderPath);
      final exists = await dir.exists();
      final gameCount = exists
          ? await _countGamesInFolder(folderPath, system.romExtensions)
          : 0;
      folders.add(FolderInfo(
        folderName: system.esdeFolder,
        systemName: system.name,
        exists: exists,
        gameCount: gameCount,
        accentColor: system.accentColor,
      ));
      if (exists) {
        existingCount++;
        totalGames += gameCount;
      } else {
        missingCount++;
      }
    }
    return FolderAnalysisResult(
      folders: folders,
      totalGames: totalGames,
      existingFoldersCount: existingCount,
      missingFoldersCount: missingCount,
    );
  }

  Future<List<String>> createMissingFolders(String romPath) async {
    final created = <String>[];
    for (final system in SystemModel.supportedSystems) {
      final folderPath = '$romPath/${system.esdeFolder}';
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
          created.add(system.esdeFolder);
        } catch (_) {
        }
      }
    }
    return created;
  }
}
