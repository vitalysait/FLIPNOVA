import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionsService {
  PermissionsService._();

  static final PermissionsService instance = PermissionsService._();

  Future<bool> requestCamera() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> requestLocation() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> requestNearbyWifi() async {
    if (Platform.isAndroid) {
      final status = await Permission.nearbyWifiDevices.request();
      return status.isGranted;
    }
    return true;
  }

  Future<bool> requestBluetooth() async {
    if (Platform.isAndroid) {
      final location = await Permission.locationWhenInUse.request();
      if (!location.isGranted) return false;
      final scan = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      return scan.isGranted && connect.isGranted;
    }
    return true;
  }

  Future<bool> requestPlugins() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final status = await Permission.sensors.request();
    return status.isGranted;
  }

  Future<bool> requestAll() async {
    final results = await [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.sensors,
    ].request();
    return results.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> checkCamera() async => await Permission.camera.isGranted;
  Future<bool> checkLocation() async =>
      await Permission.locationWhenInUse.isGranted;
  Future<bool> checkBluetooth() async =>
      await Permission.bluetoothScan.isGranted &&
      await Permission.bluetoothConnect.isGranted;
  Future<bool> checkNearbyWifi() async =>
      await Permission.nearbyWifiDevices.isGranted;
}
