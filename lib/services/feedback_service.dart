import 'audio_manager.dart';
import 'haptic_service.dart';

class FeedbackService {
  final AudioManager _audio;
  final HapticService _haptic;

  FeedbackService(this._audio, this._haptic);

  void setEnabled(bool enabled) {
    _haptic.setEnabled(enabled);
  }

  void tick() {
    _haptic.tick();
    _audio.playNavigation();
  }

  void select() {
    _haptic.select();
    _audio.playConfirm();
  }

  void action() {
    _haptic.action();
    _audio.playConfirm();
  }

  void success() {
    _haptic.success();
    _audio.playConfirm();
  }

  void warning() {
    _haptic.warning();
    _audio.playCancel();
  }

  void error() {
    _haptic.error();
    _audio.playCancel();
  }

  void confirm() {
    _haptic.mediumImpact();
    _audio.playConfirm();
  }

  void cancel() {
    _haptic.mediumImpact();
    _audio.playCancel();
  }

  void mediumImpact() {
    _haptic.mediumImpact();
  }

  void lightImpact() {
    _haptic.lightImpact();
  }

  void heavyImpact() {
    _haptic.heavyImpact();
  }
}
