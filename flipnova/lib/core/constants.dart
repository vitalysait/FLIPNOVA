import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'FLIPNOVA';
  static const String version = 'v1.0.0';

  static final List<ModuleItem> modules = [
    ModuleItem(
      id: 'nfc',
      title: 'NFC',
      icon: Icons.nfc,
      route: '/nfc',
      color: FlipNovaTheme.cyan,
      description: 'Read / Write / Emulate',
    ),
    ModuleItem(
      id: 'ir',
      title: 'IR REMOTE (Beta)',
      icon: Icons.waves,
      route: '/ir',
      color: FlipNovaTheme.orange,
      description: 'Infrared Control',
    ),
    ModuleItem(
      id: 'wifi',
      title: 'WI-FI',
      icon: Icons.wifi_find,
      route: '/wifi',
      color: FlipNovaTheme.cyan,
      description: 'Network Scanner',
    ),
    ModuleItem(
      id: 'ble',
      title: 'BLE',
      icon: Icons.bluetooth_searching,
      route: '/ble',
      color: FlipNovaTheme.cyan,
      description: 'BLE Scanner',
    ),
    ModuleItem(
      id: 'network',
      title: 'NETWORK',
      icon: Icons.hub,
      route: '/network',
      color: FlipNovaTheme.green,
      description: 'Ping / Ports / DNS',
    ),
    ModuleItem(
      id: 'cast',
      title: 'CAST',
      icon: Icons.cast,
      route: '/cast',
      color: FlipNovaTheme.yellow,
      description: 'Cast screen or video to TV',
    ),
    ModuleItem(
      id: 'qr',
      title: 'QR CODE',
      icon: Icons.qr_code_scanner,
      route: '/qr',
      color: FlipNovaTheme.pink,
      description: 'Scan / Generate',
    ),
    ModuleItem(
      id: 'plugins',
      title: 'PLUGINS',
      icon: Icons.extension,
      route: '/plugins',
      color: FlipNovaTheme.green,
      description: 'Plugin manager and extensions',
    ),
    ModuleItem(
      id: 'chameleon',
      title: 'CHAMELEON (Beta)',
      icon: Icons.pets,
      route: '/chameleon',
      color: FlipNovaTheme.cyan,
      description: 'Chameleon Ultra NFC',
    ),
  ];
}

class ModuleItem {
  final String id;
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  final String description;

  const ModuleItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
    required this.description,
  });
}
