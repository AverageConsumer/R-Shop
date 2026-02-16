import 'breakpoints.dart';

class AppSpacing {
  static const double _xs = 4.0;
  static const double _sm = 8.0;
  static const double _md = 16.0;
  static const double _lg = 24.0;
  static const double _xl = 32.0;
  static const double _xxl = 48.0;
  static const double _xxxl = 64.0;

  final DeviceSize deviceSize;
  final double _scaleFactor;

  AppSpacing(this.deviceSize)
      : _scaleFactor = switch (deviceSize) {
          DeviceSize.small => 0.8,
          DeviceSize.medium => 1.0,
          DeviceSize.large => 1.15,
        };

  double get xs => _xs * _scaleFactor;
  double get sm => _sm * _scaleFactor;
  double get md => _md * _scaleFactor;
  double get lg => _lg * _scaleFactor;
  double get xl => _xl * _scaleFactor;
  double get xxl => _xxl * _scaleFactor;
  double get xxxl => _xxxl * _scaleFactor;

  double scale(double baseValue) => baseValue * _scaleFactor;
}

class AppRadius {
  static const double _sm = 4.0;
  static const double _md = 8.0;
  static const double _lg = 12.0;
  static const double _xl = 16.0;
  static const double _xxl = 24.0;
  static const double _round = 32.0;

  final DeviceSize deviceSize;
  final double _scaleFactor;

  AppRadius(this.deviceSize)
      : _scaleFactor = switch (deviceSize) {
          DeviceSize.small => 0.85,
          DeviceSize.medium => 1.0,
          DeviceSize.large => 1.1,
        };

  double get sm => _sm * _scaleFactor;
  double get md => _md * _scaleFactor;
  double get lg => _lg * _scaleFactor;
  double get xl => _xl * _scaleFactor;
  double get xxl => _xxl * _scaleFactor;
  double get round => _round * _scaleFactor;

  double scale(double baseValue) => baseValue * _scaleFactor;
}
