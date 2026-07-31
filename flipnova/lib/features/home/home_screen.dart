import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/module_card.dart';
import '../../shared/widgets/glitch_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _bootComplete = false;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _bootComplete = true);
      _scanLineController.forward();
    });
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlipNovaTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _bootComplete ? _buildModuleGrid(context) : _buildBootScreen(),
            ),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBootScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, child) {
              return Opacity(
                opacity: _scanLineController.value,
                child: GlitchText(
                  text: 'FLIPNOVA',
                  style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.green,
                    fontSize: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: FlipNovaTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(FlipNovaTheme.green),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'LOADING SYSTEMS...',
            style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FlipNovaTheme.border, width: 2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlipNovaTheme.green,
                ),
              ),
              const SizedBox(width: 10),
              GlitchText(
                text: AppConstants.appName,
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.green,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlipNovaTheme.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '[ MULTITOOL v${AppConstants.version} ]',
            style: FlipNovaTheme.mono(
              color: FlipNovaTheme.gray,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: AppConstants.modules.length,
      itemBuilder: (context, index) {
        final module = AppConstants.modules[index];
        return ModuleCard(
          module: module,
          onTap: () => Navigator.pushNamed(context, module.route),
        );
      },
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: FlipNovaTheme.border, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '[SYS:READY]',
            style: FlipNovaTheme.mono(
              color: FlipNovaTheme.green,
              fontSize: 9,
            ),
          ),
          Text(
            '[${AppConstants.version}]',
            style: FlipNovaTheme.mono(
              color: FlipNovaTheme.gray,
              fontSize: 9,
            ),
          ),
          Text(
            '[BAT:--%]',
            style: FlipNovaTheme.mono(
              color: FlipNovaTheme.gray,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
