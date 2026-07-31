import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/nfc/nfc_screen.dart';
import 'features/ir/ir_screen.dart';
import 'features/wifi/wifi_screen.dart';
import 'features/ble/ble_screen.dart';
import 'features/network/network_screen.dart';
import 'features/cast/cast_screen.dart';
import 'features/qr/qr_screen.dart';
import 'features/plugins/plugins_screen.dart';
import 'features/chameleon/chameleon_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

class FlipperToolApp extends StatelessWidget {
  final SharedPreferences prefs;

  const FlipperToolApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final hasLaunched = prefs.getBool('hasLaunched') ?? false;

    return MaterialApp(
      title: 'FLIPNOVA',
      debugShowCheckedModeBanner: false,
      theme: FlipNovaTheme.theme,
      initialRoute: hasLaunched ? '/' : '/onboarding',
      routes: {
        '/': (context) => const HomeScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/nfc': (context) => const NfcScreen(),
        '/ir': (context) => const IrScreen(),
        '/wifi': (context) => const WifiScreen(),
        '/ble': (context) => const BleScreen(),
        '/network': (context) => const NetworkScreen(),
        '/cast': (context) => const CastScreen(),
        '/qr': (context) => const QrScreen(),
        '/sensors': (context) => const PluginsScreen(),
        '/plugins': (context) => const PluginsScreen(),
        '/chameleon': (context) => const ChameleonScreen(),
      },
    );
  }
}
