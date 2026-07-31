import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class GlitchText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool enableGlitch;

  const GlitchText({
    super.key,
    required this.text,
    this.style,
    this.enableGlitch = true,
  });

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _glitchTimer;
  Timer? _innerGlitchTimer;
  String _displayText = '';
  double _offsetX = 0;
  double _offsetY = 0;
  Color _glitchColor = FlipNovaTheme.cyan;
  bool _isGlitching = false;
  final _random = Random();

  static const _glitchChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*<>/\\|{}[]';

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    if (widget.enableGlitch) {
      _startGlitchLoop();
    }
  }

  void _startGlitchLoop() {
    _glitchTimer = Timer.periodic(
      Duration(milliseconds: 800 + _random.nextInt(2000)),
      (_) => _triggerGlitch(),
    );
  }

  void _triggerGlitch() {
    if (!mounted) return;
    setState(() => _isGlitching = true);

    final glitchDuration = 50 + _random.nextInt(150);
    final steps = 2 + _random.nextInt(4);

    Timer.periodic(Duration(milliseconds: glitchDuration ~/ steps), (timer) {
      _innerGlitchTimer = timer;
      if (!mounted || timer.tick >= steps) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isGlitching = false;
            _displayText = widget.text;
            _offsetX = 0;
            _offsetY = 0;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _displayText = _randomizeText(widget.text);
          _offsetX = (_random.nextDouble() - 0.5) * 8;
          _offsetY = (_random.nextDouble() - 0.5) * 4;
          _glitchColor = [FlipNovaTheme.cyan, FlipNovaTheme.pink, FlipNovaTheme.green][_random.nextInt(3)];
        });
      }
    });
  }

  String _randomizeText(String original) {
    final chars = original.split('');
    final numGlitches = 1 + _random.nextInt(3);
    for (int i = 0; i < numGlitches; i++) {
      final idx = _random.nextInt(chars.length);
      chars[idx] = _glitchChars[_random.nextInt(_glitchChars.length)];
    }
    return chars.join();
  }

  @override
  void dispose() {
    _glitchTimer?.cancel();
    _innerGlitchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? FlipNovaTheme.mono(
      color: FlipNovaTheme.cyan,
      fontSize: 20,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        // Cyan offset layer (left)
        if (_isGlitching)
          Transform.translate(
            offset: Offset(_offsetX - 2, _offsetY),
            child: Text(
              _displayText,
              style: baseStyle.copyWith(
                color: FlipNovaTheme.cyan.withValues(alpha: 0.7),
              ),
            ),
          ),
        // Pink offset layer (right)
        if (_isGlitching)
          Transform.translate(
            offset: Offset(_offsetX + 2, _offsetY + 1),
            child: Text(
              _displayText,
              style: baseStyle.copyWith(
                color: FlipNovaTheme.pink.withValues(alpha: 0.7),
              ),
            ),
          ),
        // Main text with glitch offset
        Transform.translate(
          offset: _isGlitching ? Offset(_offsetX, _offsetY) : Offset.zero,
          child: Text(
            _displayText,
            style: baseStyle.copyWith(
              color: _isGlitching ? _glitchColor : baseStyle.color,
              shadows: _isGlitching
                  ? [
                      BoxShadow(
                        color: _glitchColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        // Horizontal scan line effect
        if (_isGlitching && _random.nextBool())
          Positioned.fill(
            child: Align(
              alignment: Alignment(
                0,
                (_random.nextDouble() - 0.5) * 0.5,
              ),
              child: Container(
                height: 2,
                color: FlipNovaTheme.cyan.withValues(alpha: 0.3),
              ),
            ),
          ),
      ],
    );
  }
}
