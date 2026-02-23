import 'dart:async';
import 'package:flutter/material.dart';

class InputDebouncer {
  static const int _actionCooldownMs = 300;
  static const int _maxHoldDurationMs = 10000;

  int _lastActionTime = 0;
  bool _isHolding = false;
  Timer? _holdTimer;
  Timer? _holdTimeout;
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

    // Stop any existing hold before starting a new one
    if (_isHolding) stopHold();
    _isHolding = true;
    _currentHoldAction = action;
    _holdIntervalMs = 100;
    _holdCount = 0;

    action();

    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 400), _executeHold);

    // Safety timeout: auto-stop hold after max duration
    _holdTimeout?.cancel();
    _holdTimeout = Timer(const Duration(milliseconds: _maxHoldDurationMs), stopHold);

    return true;
  }

  void _executeHold() {
    if (!_isHolding || _currentHoldAction == null) return;

    _currentHoldAction!();
    _holdCount++;

    if (_holdCount > 8) {
      _holdIntervalMs = 60;
    } else if (_holdCount > 4) {
      _holdIntervalMs = 80;
    }

    _holdTimer?.cancel();
    _holdTimer = Timer(Duration(milliseconds: _holdIntervalMs), _executeHold);
  }

  void stopHold() {
    _isHolding = false;
    _holdTimer?.cancel();
    _holdTimeout?.cancel();
    _currentHoldAction = null;
    _holdCount = 0;
  }

  void dispose() {
    stopHold();
  }
}
