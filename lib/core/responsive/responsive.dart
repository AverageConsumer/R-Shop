import 'package:flutter/widgets.dart';

import 'breakpoints.dart';
import 'spacing.dart';
import 'typography.dart';

export 'breakpoints.dart';
export 'spacing.dart';
export 'typography.dart';

class Responsive {
  final BuildContext context;
  final DeviceSize deviceSize;
  final bool isPortrait;
  final bool isLandscape;
  final bool isSmall;
  final bool isMedium;
  final bool isLarge;
  final AppSpacing spacing;
  final AppRadius radius;
  final AppTypography typography;
  final Size screenSize;
  final double screenWidth;
  final double screenHeight;
  final double shortestSide;
  final double longestSide;

  Responsive._({
    required this.context,
    required this.deviceSize,
    required this.isPortrait,
    required this.isLandscape,
    required this.isSmall,
    required this.isMedium,
    required this.isLarge,
    required this.spacing,
    required this.radius,
    required this.typography,
    required this.screenSize,
    required this.screenWidth,
    required this.screenHeight,
    required this.shortestSide,
    required this.longestSide,
  });

  factory Responsive.of(BuildContext context) {
    final deviceSize = Breakpoints.getDeviceSize(context);
    final size = MediaQuery.of(context).size;
    final isPortrait = Breakpoints.isPortrait(context);

    return Responsive._(
      context: context,
      deviceSize: deviceSize,
      isPortrait: isPortrait,
      isLandscape: !isPortrait,
      isSmall: deviceSize == DeviceSize.small,
      isMedium: deviceSize == DeviceSize.medium,
      isLarge: deviceSize == DeviceSize.large,
      spacing: AppSpacing(deviceSize),
      radius: AppRadius(deviceSize),
      typography: AppTypography(deviceSize),
      screenSize: size,
      screenWidth: size.width,
      screenHeight: size.height,
      shortestSide: size.shortestSide,
      longestSide: size.longestSide,
    );
  }

  double sp(double base) => spacing.scale(base);

  double font(double base) => typography.scale(base);

  double r(double base) => radius.scale(base);

  double wp(double percent) => screenWidth * (percent / 100);

  double hp(double percent) => screenHeight * (percent / 100);

  int gridColumns({
    double minItemWidth = 150,
    double maxItemWidth = 300,
    int minColumns = 2,
    int maxColumns = 8,
  }) {
    final availableWidth = screenWidth - (spacing.lg * 2);
    final idealColumns = (availableWidth / minItemWidth).floor();
    final columns = idealColumns.clamp(minColumns, maxColumns);

    if (isPortrait && columns > 4) return 4;
    if (isSmall && columns > 4) return columns.clamp(2, 3);

    return columns;
  }

  double get safeAreaTop => MediaQuery.of(context).padding.top;

  double get safeAreaBottom => MediaQuery.of(context).padding.bottom;

  double get safeAreaLeft => MediaQuery.of(context).padding.left;

  double get safeAreaRight => MediaQuery.of(context).padding.right;

  EdgeInsets get safeAreaPadding => MediaQuery.of(context).padding;

  EdgeInsets screenPadding({double horizontal = 0, double vertical = 0}) {
    return EdgeInsets.only(
      left: safeAreaLeft + sp(horizontal),
      right: safeAreaRight + sp(horizontal),
      top: safeAreaTop + sp(vertical),
      bottom: safeAreaBottom + sp(vertical),
    );
  }
}

extension ResponsiveContext on BuildContext {
  Responsive get rs => Responsive.of(this);
}
