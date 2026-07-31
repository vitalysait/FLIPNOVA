import 'package:flutter/material.dart';
import '../../core/theme.dart';

class StubScreen extends StatelessWidget {
  final String title;
  final String feature;
  final IconData icon;

  const StubScreen({
    super.key,
    required this.title,
    required this.feature,
    this.icon = Icons.phone_android,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: FlipNovaTheme.green),
              const SizedBox(height: 16),
              Text(
                feature,
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.white,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '> Feature not available\n> on this platform/device',
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.gray,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
