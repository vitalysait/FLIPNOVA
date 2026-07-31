import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class ModuleCard extends StatefulWidget {
  final ModuleItem module;
  final VoidCallback onTap;

  const ModuleCard({
    super.key,
    required this.module,
    required this.onTap,
  });

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _isPressed
            ? Matrix4.translationValues(2, 2, 0)
            : Matrix4.translationValues(0, 0, 0),
        decoration: BoxDecoration(
          color: _isPressed ? FlipNovaTheme.bgCardHover : FlipNovaTheme.bgCard,
          borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
          border: Border.all(
            color: _isPressed ? FlipNovaTheme.green : FlipNovaTheme.border,
            width: FlipNovaTheme.borderWidth,
          ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
        ),
        padding: const EdgeInsets.all(FlipNovaTheme.padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.module.icon,
              size: 32,
              color: FlipNovaTheme.green,
            ),
            const SizedBox(height: 10),
            Text(
              widget.module.title,
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.white,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
