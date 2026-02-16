import 'breakpoints.dart';

class AppTypography {
  final DeviceSize deviceSize;
  final double _scaleFactor;

  AppTypography(this.deviceSize)
      : _scaleFactor = switch (deviceSize) {
          DeviceSize.small => 0.75,
          DeviceSize.medium => 1.0,
          DeviceSize.large => 1.2,
        };

  double get hero => 48.0 * _scaleFactor;
  double get headline => 32.0 * _scaleFactor;
  double get titleLarge => 28.0 * _scaleFactor;
  double get title => 24.0 * _scaleFactor;
  double get titleSmall => 20.0 * _scaleFactor;
  double get bodyLarge => 18.0 * _scaleFactor;
  double get body => 16.0 * _scaleFactor;
  double get bodySmall => 14.0 * _scaleFactor;
  double get caption => 12.0 * _scaleFactor;
  double get captionSmall => 10.0 * _scaleFactor;
  double get micro => 8.0 * _scaleFactor;

  double scale(double baseValue) => baseValue * _scaleFactor;

  double letterSpacing(String type) {
    return switch (type) {
      'hero' => 6.0 * _scaleFactor,
      'headline' => 4.0 * _scaleFactor,
      'title' => 2.0 * _scaleFactor,
      'button' => 1.5 * _scaleFactor,
      'caption' => 1.0 * _scaleFactor,
      _ => 0.0,
    };
  }
}
