import 'package:flutter/foundation.dart';
import 'dart:io';

class PlatformCheck {
  PlatformCheck._();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMobile => isAndroid || isIOS;

  static bool get hasIrSupport => isAndroid;
  static bool get hasNfcReadSupport => isMobile;
  static bool get hasNfcEmulationSupport => isAndroid;
  static bool get hasBleSupport => isMobile;
  static bool get hasWifiScanSupport => isAndroid;
  static bool get hasSensorsSupport => isMobile;
  static bool get hasQrScanSupport => isMobile;
  static bool get hasNetworkToolsSupport => isMobile;
  static bool get hasCastSupport => isMobile;
}
