class SoundSettings {
  final bool enabled;
  final double bgmVolume;
  final double sfxVolume;

  const SoundSettings({
    this.enabled = true,
    this.bgmVolume = 0.3,
    this.sfxVolume = 0.7,
  });

  SoundSettings copyWith({
    bool? enabled,
    double? bgmVolume,
    double? sfxVolume,
  }) {
    return SoundSettings(
      enabled: enabled ?? this.enabled,
      bgmVolume: bgmVolume ?? this.bgmVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'bgmVolume': bgmVolume,
      'sfxVolume': sfxVolume,
    };
  }

  factory SoundSettings.fromJson(Map<String, dynamic> json) {
    return SoundSettings(
      enabled: json['enabled'] as bool? ?? true,
      bgmVolume: (json['bgmVolume'] as num?)?.toDouble() ?? 0.3,
      sfxVolume: (json['sfxVolume'] as num?)?.toDouble() ?? 0.7,
    );
  }
}
