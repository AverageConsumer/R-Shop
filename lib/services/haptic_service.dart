import 'package:flutter/services.dart';

class HapticService {
  bool _enabled = true;

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
  }

  void tick() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  void select() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  void action() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  void success() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.lightImpact();
    });
  }

  void warning() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  void error() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  void mediumImpact() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  void lightImpact() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  void heavyImpact() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }
}
