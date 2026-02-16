import 'package:flutter/material.dart';

enum DeviceSize { small, medium, large }

class Breakpoints {
  static const double smallMax = 600;
  static const double mediumMax = 900;

  static DeviceSize getDeviceSize(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    if (shortestSide < smallMax) return DeviceSize.small;
    if (shortestSide < mediumMax) return DeviceSize.medium;
    return DeviceSize.large;
  }

  static bool isSmall(BuildContext context) =>
      getDeviceSize(context) == DeviceSize.small;

  static bool isMedium(BuildContext context) =>
      getDeviceSize(context) == DeviceSize.medium;

  static bool isLarge(BuildContext context) =>
      getDeviceSize(context) == DeviceSize.large;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;
}
