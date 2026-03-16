import 'package:flutter/material.dart';

/// Scrolls text horizontally like a ticker when [animate] is true and the text
/// overflows. Shows static ellipsis text otherwise.
class MarqueeText extends StatefulWidget {
  final String text;
  final bool animate;
  final TextStyle style;

  const MarqueeText({
    super.key,
    required this.text,
    required this.animate,
    required this.style,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final ScrollController _scroll = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)
      ..addListener(_onTick);
    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryStart());
    }
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryStart());
    } else if (!widget.animate && _running) {
      _stop();
    }
  }

  void _tryStart() {
    if (!mounted || !_scroll.hasClients || _running) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    // 30px/s + 2s pauses
    final ms = (max / 30 * 1000).round() + 2000;
    _anim.duration = Duration(milliseconds: ms);
    _anim.repeat();
    _running = true;
  }

  void _stop() {
    _anim.stop();
    _anim.value = 0;
    _running = false;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onTick() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final t = _anim.value;
    // 0.0–0.15: pause at start, 0.15–0.85: scroll, 0.85–1.0: pause at end
    final double fraction;
    if (t < 0.15) {
      fraction = 0;
    } else if (t > 0.85) {
      fraction = 1;
    } else {
      fraction = (t - 0.15) / 0.7;
    }
    _scroll.jumpTo(max * fraction);
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
