import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../providers/app_providers.dart';
import '../../../services/audio_manager.dart';
class ChatBubble extends ConsumerStatefulWidget {
  final String message;
  final VoidCallback? onComplete;
  final Duration typewriterSpeed;
  final Color? accentColor;
  const ChatBubble({
    super.key,
    required this.message,
    this.onComplete,
    this.typewriterSpeed = const Duration(milliseconds: 30),
    this.accentColor,
  });
  @override
  ConsumerState<ChatBubble> createState() => _ChatBubbleState();
}
class _ChatBubbleState extends ConsumerState<ChatBubble> {
  String _displayedText = '';
  int _charIndex = 0;
  Timer? _timer;
  bool _isComplete = false;
  bool _typingSoundStarted = false;
  late final AudioManager _audioManager;
  @override
  void initState() {
    super.initState();
    _audioManager = ref.read(audioManagerProvider);
    _startTypewriter();
  }
  @override
  void dispose() {
    _timer?.cancel();
    _stopTypingSound();
    super.dispose();
  }
  void _stopTypingSound() {
    if (_typingSoundStarted) {
      try {
        _audioManager.stopTyping();
        _typingSoundStarted = false;
      } catch (_) {}
    }
  }
  void _startTypewriter() {
    try {
      _audioManager.startTyping();
      _typingSoundStarted = true;
    } catch (_) {}
    _timer = Timer.periodic(widget.typewriterSpeed, (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_charIndex < widget.message.length) {
        setState(() {
          _displayedText = widget.message.substring(0, _charIndex + 1);
          _charIndex++;
        });
      } else {
        timer.cancel();
        _stopTypingSound();
        setState(() => _isComplete = true);
        widget.onComplete?.call();
      }
    });
  }
  void _skipToEnd() {
    _timer?.cancel();
    _stopTypingSound();
    setState(() {
      _displayedText = widget.message;
      _charIndex = widget.message.length;
      _isComplete = true;
    });
    widget.onComplete?.call();
  }
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final marginLeft = rs.isSmall ? 40.0 : 60.0;
    final marginRight = rs.isSmall ? rs.spacing.md : rs.spacing.lg;
    final paddingH = rs.isSmall ? rs.spacing.md : rs.spacing.lg;
    final paddingV = rs.isSmall ? rs.spacing.sm : rs.spacing.md;
    final fontSize = rs.isSmall ? 14.0 : 16.0;
    final cursorHeight = rs.isSmall ? 14.0 : 18.0;
    final cursorWidth = rs.isSmall ? 1.5 : 2.0;
    return GestureDetector(
      onTap: _isComplete ? null : _skipToEnd,
      child: Container(
        margin: EdgeInsets.only(left: marginLeft, right: marginRight),
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (widget.accentColor ?? Colors.white).withValues(alpha: 0.12),
              (widget.accentColor ?? Colors.white).withValues(alpha: 0.06),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(
            color: (widget.accentColor ?? Colors.white).withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                _displayedText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  height: 1.4,
                ),
              ),
            ),
            if (!_isComplete)
              Padding(
                padding: EdgeInsets.only(left: rs.spacing.sm),
                child: Container(
                  width: cursorWidth,
                  height: cursorHeight,
                  color: (widget.accentColor ?? Colors.white).withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
