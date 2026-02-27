enum RaMatchType { none, nameMatch, hashVerified, hashIncompatible }

class RaGame {
  final int raGameId;
  final String title;
  final int consoleId;
  final int numAchievements;
  final int points;
  final String? imageIcon;
  final List<String> hashes;

  const RaGame({
    required this.raGameId,
    required this.title,
    required this.consoleId,
    this.numAchievements = 0,
    this.points = 0,
    this.imageIcon,
    this.hashes = const [],
  });

  factory RaGame.fromJson(Map<String, dynamic> json) {
    final rawHashes = json['Hashes'];
    return RaGame(
      raGameId: json['ID'] as int,
      title: json['Title'] as String? ?? '',
      consoleId: json['ConsoleID'] as int,
      numAchievements: json['NumAchievements'] as int? ?? 0,
      points: json['Points'] as int? ?? 0,
      imageIcon: json['ImageIcon'] as String?,
      hashes: rawHashes is List
          ? rawHashes.whereType<String>().toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'ID': raGameId,
        'Title': title,
        'ConsoleID': consoleId,
        'NumAchievements': numAchievements,
        'Points': points,
        'ImageIcon': imageIcon,
        'Hashes': hashes,
      };
}

class RaHashEntry {
  final String md5;
  final String? name;
  final List<String> labels;

  const RaHashEntry({
    required this.md5,
    this.name,
    this.labels = const [],
  });

  factory RaHashEntry.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['Labels'];
    return RaHashEntry(
      md5: json['MD5'] as String? ?? '',
      name: json['Name'] as String?,
      labels: rawLabels is List
          ? rawLabels.whereType<String>().toList()
          : const [],
    );
  }
}

class RaAchievement {
  final int id;
  final String title;
  final String description;
  final int points;
  final int trueRatio;
  final String badgeName;
  final int displayOrder;
  final String? type;
  final int numAwarded;
  final int numAwardedHardcore;
  final DateTime? dateEarned;
  final DateTime? dateEarnedHardcore;

  const RaAchievement({
    required this.id,
    required this.title,
    this.description = '',
    this.points = 0,
    this.trueRatio = 0,
    this.badgeName = '',
    this.displayOrder = 0,
    this.type,
    this.numAwarded = 0,
    this.numAwardedHardcore = 0,
    this.dateEarned,
    this.dateEarnedHardcore,
  });

  bool get isEarned => dateEarned != null;
  bool get isEarnedHardcore => dateEarnedHardcore != null;

  factory RaAchievement.fromJson(Map<String, dynamic> json) {
    return RaAchievement(
      id: json['ID'] as int,
      title: json['Title'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      points: json['Points'] as int? ?? 0,
      trueRatio: json['TrueRatio'] as int? ?? 0,
      badgeName: json['BadgeName'] as String? ?? '',
      displayOrder: json['DisplayOrder'] as int? ?? 0,
      type: json['type'] as String?,
      numAwarded: json['NumAwarded'] as int? ?? 0,
      numAwardedHardcore: json['NumAwardedHardcore'] as int? ?? 0,
      dateEarned: _parseDate(json['DateEarned']),
      dateEarnedHardcore: _parseDate(json['DateEarnedHardcore']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value == '') return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class RaMatchResult {
  final RaMatchType type;
  final int? raGameId;
  final String? raTitle;
  final int? achievementCount;
  final int? points;
  final String? imageIcon;
  final bool isMastered;

  const RaMatchResult({
    required this.type,
    this.raGameId,
    this.raTitle,
    this.achievementCount,
    this.points,
    this.imageIcon,
    this.isMastered = false,
  });

  const RaMatchResult.none() : this(type: RaMatchType.none);

  RaMatchResult.nameMatch(RaGame game)
      : this(
          type: RaMatchType.nameMatch,
          raGameId: game.raGameId,
          raTitle: game.title,
          achievementCount: game.numAchievements,
          points: game.points,
          imageIcon: game.imageIcon,
        );

  RaMatchResult.hashVerified(RaGame game)
      : this(
          type: RaMatchType.hashVerified,
          raGameId: game.raGameId,
          raTitle: game.title,
          achievementCount: game.numAchievements,
          points: game.points,
          imageIcon: game.imageIcon,
        );

  const RaMatchResult.hashIncompatible({int? raGameId, String? raTitle})
      : this(
          type: RaMatchType.hashIncompatible,
          raGameId: raGameId,
          raTitle: raTitle,
        );

  bool get hasMatch => type != RaMatchType.none;
  bool get isVerified => type == RaMatchType.hashVerified;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'raGameId': raGameId,
        'raTitle': raTitle,
        'achievementCount': achievementCount,
        'points': points,
        'imageIcon': imageIcon,
        'isMastered': isMastered,
      };

  factory RaMatchResult.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'none';
    return RaMatchResult(
      type: RaMatchType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => RaMatchType.none,
      ),
      raGameId: json['raGameId'] as int?,
      raTitle: json['raTitle'] as String?,
      achievementCount: json['achievementCount'] as int?,
      points: json['points'] as int?,
      imageIcon: json['imageIcon'] as String?,
      isMastered: json['isMastered'] as bool? ?? false,
    );
  }
}

/// Summary of a user's progress on a game.
class RaGameProgress {
  final int raGameId;
  final String title;
  final String? imageIcon;
  final int numAchievements;
  final int points;
  final List<RaAchievement> achievements;

  const RaGameProgress({
    required this.raGameId,
    required this.title,
    this.imageIcon,
    this.numAchievements = 0,
    this.points = 0,
    this.achievements = const [],
  });

  int get earnedCount => achievements.where((a) => a.isEarned).length;
  int get earnedHardcoreCount =>
      achievements.where((a) => a.isEarnedHardcore).length;
  int get earnedPoints =>
      achievements.where((a) => a.isEarned).fold(0, (s, a) => s + a.points);

  double get completionPercent =>
      numAchievements > 0 ? earnedCount / numAchievements : 0.0;
  bool get isCompleted =>
      numAchievements > 0 && earnedCount >= numAchievements;
}
