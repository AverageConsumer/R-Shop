import 'dart:async';
import 'package:flutter/material.dart';

class InputDebouncer {
  static const int _actionCooldownMs = 300;

  int _lastActionTime = 0;
  bool _isHolding = false;
  Timer? _holdTimer;
  int _holdIntervalMs = 100;
  VoidCallback? _currentHoldAction;
  int _holdCount = 0;

  bool get isHolding => _isHolding;

  bool canPerformAction() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastActionTime < _actionCooldownMs) {
      return false;
    }
    _lastActionTime = now;
    return true;
  }

  bool startHold(VoidCallback action) {
    if (!canPerformAction()) return false;

    _isHolding = true;
    _currentHoldAction = action;
    _holdIntervalMs = 100;
    _holdCount = 0;

    action();

    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 400), _executeHold);

    return true;
  }

  void _executeHold() {
    if (!_isHolding || _currentHoldAction == null) return;

    _currentHoldAction!();
    _holdCount++;

    if (_holdCount > 8) {
      _holdIntervalMs = 30;
    } else if (_holdCount > 4) {
      _holdIntervalMs = 50;
    }

    _holdTimer?.cancel();
    _holdTimer = Timer(Duration(milliseconds: _holdIntervalMs), _executeHold);
  }

  void stopHold() {
    _isHolding = false;
    _holdTimer?.cancel();
    _currentHoldAction = null;
    _holdCount = 0;
  }

  void dispose() {
    stopHold();
  }
}
