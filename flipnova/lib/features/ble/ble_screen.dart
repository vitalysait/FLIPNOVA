import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/theme.dart';
import '../../core/services/permissions_service.dart';

class BleScreen extends StatefulWidget {
  const BleScreen({super.key});

  @override
  State<BleScreen> createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {
  bool _isScanning = false;
  final List<ScanResult> _devices = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];
  // Known CHAMELEON ULTRA service UUIDs (full and short forms).
  final Set<String> _chameleonUuidSet = {
    '0000fff0-0000-1000-8000-00805f9b34fb',
    '0000fff1-0000-1000-8000-00805f9b34fb',
    '0000ffe0-0000-1000-8000-00805f9b34fb',
    'fff0',
    'fff1',
    'ffe0',
  };

  @override
  void initState() {
    super.initState();
    _loadChameleonUuids();
  }

  Future<void> _loadChameleonUuids() async {
    try {
      final raw = await rootBundle.loadString('assets/chameleon_uuids.json');
      final List<dynamic> parsed = raw.isNotEmpty ? (jsonDecode(raw) as List<dynamic>) : [];
      for (final e in parsed) {
        if (e is String) _chameleonUuidSet.add(e.toLowerCase());
      }
    } catch (_) {
      // Ignore missing/invalid asset and continue with defaults.
    }
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('[ BLE SCAN ]'),
        actions: [
          if (_devices.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_devices.length}',
                  style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.green,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _connectedDevice != null ? _buildDeviceDetail() : _buildScanList(),
    );
  }

  Widget _buildScanList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  child: Text(_isScanning ? '[ SCANNING... ]' : '[ SCAN ]'),
                ),
              ),
              if (_isScanning) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _stopScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlipNovaTheme.bgCard,
                      foregroundColor: FlipNovaTheme.red,
                      side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
                    ),
                    child: const Text('[ STOP ]'),
                  ),
                ),
              ],
              if (_devices.isNotEmpty && !_isScanning) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _devices.clear()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlipNovaTheme.bgCard,
                      foregroundColor: FlipNovaTheme.gray,
                      side: const BorderSide(color: FlipNovaTheme.gray, width: FlipNovaTheme.borderWidth),
                    ),
                    child: const Text('[ CLEAR ]'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildDeviceList()),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: FlipNovaTheme.bgCard,
          borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
          border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          _isScanning
              ? '> Scanning for BLE devices...\n> This may take a few seconds'
              : '> No BLE devices found\n> Press SCAN to search',
          style: FlipNovaTheme.mono(
            color: FlipNovaTheme.gray,
            fontSize: 12,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final result = _devices[index];
        final device = result.device;
        final name = device.platformName.isNotEmpty ? device.platformName : 'Unknown';
        final id = device.remoteId.str;
        final rssi = result.rssi;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
          ),
          child: InkWell(
            onTap: () => _showDeviceActionDialog(result),
            child: Row(
              children: [
                const Icon(Icons.bluetooth, color: FlipNovaTheme.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: FlipNovaTheme.mono(
                          color: FlipNovaTheme.white,
                          fontSize: 11,
                          weight: FontWeight.bold,
                        ),
                      ),
                      if (_isChameleonScanResult(result))
                        Text('CHAMELEON ULTRA', style: FlipNovaTheme.mono(color: FlipNovaTheme.cyan, fontSize: 8)),
                      Text(
                        id,
                        style: FlipNovaTheme.mono(
                          color: FlipNovaTheme.gray,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$rssi dBm',
                      style: FlipNovaTheme.mono(
                        color: FlipNovaTheme.green,
                        fontSize: 12,
                        weight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'TAP TO CONNECT',
                      style: FlipNovaTheme.mono(
                        color: FlipNovaTheme.gray,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceDetail() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlipNovaTheme.bgCard,
              borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
              border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bluetooth_connected, color: FlipNovaTheme.green, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _connectedDevice!.platformName.isNotEmpty
                                ? _connectedDevice!.platformName
                                : 'Unknown Device',
                            style: FlipNovaTheme.mono(
                              color: FlipNovaTheme.white,
                              fontSize: 11,
                              weight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _connectedDevice!.remoteId.str,
                            style: FlipNovaTheme.mono(
                              color: FlipNovaTheme.gray,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: FlipNovaTheme.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _disconnectDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlipNovaTheme.bgCard,
                    foregroundColor: FlipNovaTheme.red,
                    side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
                  ),
                  child: const Text('[ DISCONNECT ]'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _discoverServices,
                  child: const Text('[ DISCOVER ]'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildServicesList()),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    if (_services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlipNovaTheme.bgCard,
          borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
          border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
        ),
        child: Text(
          '> Tap [ DISCOVER ] to list services\n> Then explore characteristics',
          style: FlipNovaTheme.mono(
            color: FlipNovaTheme.gray,
            fontSize: 12,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _services.length,
      itemBuilder: (context, sIndex) {
        final service = _services[sIndex];
        final uuid = service.uuid.str.toUpperCase();
        final chars = service.characteristics;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SERVICE: $uuid',
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.green,
                  fontSize: 10,
                  weight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...chars.map((char) {
                final charUuid = char.uuid.str.toUpperCase();
                final props = <String>[];
                if (char.properties.read) props.add('READ');
                if (char.properties.write) props.add('WRITE');
                if (char.properties.notify) props.add('NOTIFY');
                if (char.properties.indicate) props.add('INDICATE');

                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FlipNovaTheme.bgPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: FlipNovaTheme.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              charUuid,
                              style: FlipNovaTheme.mono(
                                color: FlipNovaTheme.white,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              props.join(' | '),
                              style: FlipNovaTheme.mono(
                                color: FlipNovaTheme.gray,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (char.properties.read)
                        IconButton(
                          icon: const Icon(Icons.download, size: 16, color: FlipNovaTheme.green),
                          onPressed: () => _readCharacteristic(char),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startScan() async {
    final hasPermission = await PermissionsService.instance.requestBluetooth();
    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bluetooth permission required', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11)),
          backgroundColor: FlipNovaTheme.red,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      await FlutterBluePlus.stopScan();
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        if (mounted) {
          setState(() {
            _devices.clear();
            for (final r in results) {
              if (!_devices.any((d) => d.device.remoteId == r.device.remoteId)) {
                _devices.add(r);
              }
            }
          });
        }
      }, onError: (e) {});

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11)),
            backgroundColor: FlipNovaTheme.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _isScanning = false);
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10), license: License.nonprofit);
      if (mounted) {
        setState(() {
          _connectedDevice = device;
          _services.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11)),
            backgroundColor: FlipNovaTheme.red,
          ),
        );
      }
    }
  }

  // name-based check kept inline in scan-result detection; removed unused standalone helper.

  bool _isChameleonScanResult(ScanResult r) {
    try {
      final name = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : '';
      if (name.toUpperCase().contains('CHAMELEON')) return true;

      final adv = r.advertisementData.serviceUuids.map((s) => s.toString().toLowerCase()).toList();
      for (final u in adv) {
        if (_chameleonUuidSet.contains(u)) return true;
        for (final k in _chameleonUuidSet) {
          if (u.contains(k)) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _connectChameleonUltra(BluetoothDevice device) async {
    // Specialized connect flow for CHAMELEON ULTRA devices.
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connecting to CHAMELEON ULTRA...', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11))),
        );
      }

      await device.connect(timeout: const Duration(seconds: 12), license: License.nonprofit);

      // Discover services and try to locate a likely vendor characteristic.
      final services = await device.discoverServices();
      BluetoothCharacteristic? infoChar;
      for (final s in services) {
        for (final c in s.characteristics) {
          final u = c.uuid.str.toLowerCase();
          // Common vendor/service patterns: fff0/fff1 or 0000xxxx-0000-1000-8000-00805f9b34fb
          if (u.contains('fff') || u.contains('ffe') || u.contains('0000')) {
            infoChar = c;
            break;
          }
        }
        if (infoChar != null) break;
      }

      if (mounted) setState(() {
        _connectedDevice = device;
        _services = services;
      });

      if (infoChar != null) {
        try {
          // Attempt a read (may fail depending on permissions).
          final value = await infoChar.read();
          final ascii = String.fromCharCodes(value.where((b) => b >= 32 && b < 127));
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CHAMELEON info: ${ascii.isNotEmpty ? ascii : value}', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11))),
          );
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected to CHAMELEON ULTRA (no readable info).', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11))),
          );
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to CHAMELEON ULTRA (no known info characteristic found).', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11))),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CHAMELEON connect failed: $e', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11))),
      );
    }
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _connectedDevice = null;
        _services.clear();
      });
    }
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;
    try {
      final services = await _connectedDevice!.discoverServices();
      if (mounted) setState(() => _services = services);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discover error: $e', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11)),
            backgroundColor: FlipNovaTheme.red,
          ),
        );
      }
    }
  }

  Future<void> _readCharacteristic(BluetoothCharacteristic char) async {
    try {
      final value = await char.read();
      final hex = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final ascii = String.fromCharCodes(value.where((b) => b >= 32 && b < 127));

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: FlipNovaTheme.bgCard,
            title: Text('CHARACTERISTIC VALUE', style: FlipNovaTheme.mono(
              color: FlipNovaTheme.green,
              fontSize: 10,
              weight: FontWeight.bold,
            )),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HEX: $hex', style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.white,
                  fontSize: 11,
                )),
                const SizedBox(height: 8),
                Text('ASCII: $ascii', style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.green,
                  fontSize: 11,
                )),
                const SizedBox(height: 8),
                Text('BYTES: ${value.length}', style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.gray,
                  fontSize: 11,
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('[ CLOSE ]', style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.green,
                  fontSize: 10,
                )),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Read error: $e', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11)),
            backgroundColor: FlipNovaTheme.red,
          ),
        );
      }
    }
  }

  void _showDeviceActionDialog(ScanResult result) {
    final device = result.device;
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : result.advertisementData.advName.isNotEmpty
            ? result.advertisementData.advName
            : device.remoteId.str;
    final id = device.remoteId.str;
    final rssi = result.rssi;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlipNovaTheme.bgCard,
          borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
          border: Border.all(color: FlipNovaTheme.cyan, width: FlipNovaTheme.borderWidth),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.bluetooth, color: FlipNovaTheme.green, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: FlipNovaTheme.mono(
                        color: FlipNovaTheme.cyan, fontSize: 14, weight: FontWeight.bold,
                      )),
                      Text(id, style: FlipNovaTheme.mono(
                        color: FlipNovaTheme.gray, fontSize: 10,
                      )),
                    ],
                  ),
                ),
                Text('$rssi dBm', style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
                )),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BleJamScreen(deviceName: name, deviceId: id),
                  ));
                },
                icon: const Icon(Icons.volume_off, size: 18),
                label: Text('[ JAM DEVICE ]', style: FlipNovaTheme.mono(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlipNovaTheme.bgCard,
                  foregroundColor: FlipNovaTheme.red,
                  side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BleInterceptScreen(deviceName: name, deviceId: id),
                  ));
                },
                icon: const Icon(Icons.wifi_tethering, size: 18),
                label: Text('[ INTERCEPT SIGNAL ]', style: FlipNovaTheme.mono(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlipNovaTheme.bgCard,
                  foregroundColor: FlipNovaTheme.orange,
                  side: const BorderSide(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
                child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (_isChameleonScanResult(result)) {
                    _connectChameleonUltra(device);
                  } else {
                    _connectToDevice(device);
                  }
                },
                icon: const Icon(Icons.bluetooth_connected, size: 18),
                label: Text('[ CONNECT ]', style: FlipNovaTheme.mono(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlipNovaTheme.bgCard,
                  foregroundColor: FlipNovaTheme.green,
                  side: const BorderSide(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('[ CANCEL ]', style: FlipNovaTheme.mono(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BleJamScreen extends StatefulWidget {
  final String deviceName;
  final String deviceId;
  const BleJamScreen({super.key, required this.deviceName, required this.deviceId});

  @override
  State<BleJamScreen> createState() => _BleJamScreenState();
}

class _BleJamScreenState extends State<BleJamScreen> {
  static const _channel = MethodChannel('com.flipnova/ble');
  static const _eventChannel = EventChannel('com.flipnova/ble/events');
  bool _isJamming = false;
  int _packetCount = 0;
  int _targetRssi = 0;
  String _jamMode = 'BROADBAND';
  StreamSubscription? _eventSub;
  final List<String> _log = [];

  @override
  void dispose() {
    _stopJamming();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('[ JAM: ${widget.deviceName} ]')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlipNovaTheme.bgCard,
                borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
                border: Border.all(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TARGET: ${widget.deviceName}', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.red, fontSize: 12, weight: FontWeight.bold,
                  )),
                  const SizedBox(height: 4),
                  Text('ID: ${widget.deviceId}', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.gray, fontSize: 10,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('JAM MODE:', style: FlipNovaTheme.mono(
              color: FlipNovaTheme.cyan, fontSize: 10, weight: FontWeight.bold,
            )),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildJamModeButton('BROADBAND', 'All BLE channels\n37, 38, 39'),
                const SizedBox(width: 8),
                _buildJamModeButton('TARGETED', 'Target device\nspecific channel'),
                const SizedBox(width: 8),
                _buildJamModeButton('ADAPTIVE', 'Smart jamming\nfollow device'),
              ],
            ),
            const SizedBox(height: 12),
            if (_isJamming) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlipNovaTheme.bgCard,
                  borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
                  border: Border.all(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCounter('PACKETS', _packetCount, FlipNovaTheme.red),
                        _buildCounter('RSSI', _targetRssi, FlipNovaTheme.cyan),
                        _buildCounter('MODE', 0, FlipNovaTheme.orange),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: FlipNovaTheme.bgCard,
                      valueColor: const AlwaysStoppedAnimation<Color>(FlipNovaTheme.red),
                      minHeight: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isJamming ? null : _startJamming,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlipNovaTheme.bgCard,
                      foregroundColor: FlipNovaTheme.red,
                      side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_isJamming ? '[ JAMMING... ]' : '[ START JAM ]'),
                  ),
                ),
                if (_isJamming) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _stopJamming,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlipNovaTheme.bgCard,
                        foregroundColor: FlipNovaTheme.white,
                        side: const BorderSide(color: FlipNovaTheme.white, width: FlipNovaTheme.borderWidth),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('[ STOP ]'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlipNovaTheme.bgCard,
                  borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
                  border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OUTPUT:', style: FlipNovaTheme.mono(
                      color: FlipNovaTheme.red, fontSize: 10, weight: FontWeight.bold,
                    )),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _log.isEmpty
                          ? Text(
                              '> Ready to jam ${widget.deviceName}\n> Select jam mode above\n> Tap [ START JAM ]\n\n> BLE operates on 3 channels:\n> 37 (2402 MHz)\n> 38 (2426 MHz)\n> 39 (2480 MHz)',
                              style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 11),
                            )
                          : ListView(
                              children: _log.reversed.map((l) => Text(
                                l,
                                style: FlipNovaTheme.mono(
                                  color: l.contains('FOUND') || l.contains('OK') ? FlipNovaTheme.green : FlipNovaTheme.gray, fontSize: 10,
                                ),
                              )).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJamModeButton(String mode, String desc) {
    final isSelected = _jamMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _jamMode = mode),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(
              color: isSelected ? FlipNovaTheme.red : FlipNovaTheme.gray,
              width: FlipNovaTheme.borderWidth,
            ),
          ),
          child: Column(
            children: [
              Text(mode, style: FlipNovaTheme.mono(
                color: isSelected ? FlipNovaTheme.red : FlipNovaTheme.gray,
                fontSize: 10, weight: FontWeight.bold,
              )),
              const SizedBox(height: 4),
              Text(desc, style: FlipNovaTheme.mono(
                color: FlipNovaTheme.gray, fontSize: 8,
              ), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value', style: FlipNovaTheme.mono(
          color: color, fontSize: 16, weight: FontWeight.bold,
        )),
        Text(label, style: FlipNovaTheme.mono(
          color: FlipNovaTheme.gray, fontSize: 8,
        )),
      ],
    );
  }

  Future<void> _startJamming() async {
    setState(() {
      _log.clear();
      _log.add('> Starting BLE jam on ${widget.deviceName}...');
      _log.add('> Mode: $_jamMode');
    });

    try {
      final result = await _channel.invokeMethod<Map>('startJam', {
        'address': widget.deviceId,
        'mode': _jamMode,
      });
      final success = result?['success'] == true;
      if (!success) {
        final error = result?['error'] ?? 'Unknown error';
        if (mounted) {
          setState(() {
            _log.add('> ERROR: $error');
            _isJamming = false;
          });
        }
        return;
      }

      if (mounted) setState(() {
        _isJamming = true;
        _packetCount = 0;
      });

      _eventSub?.cancel();
      _eventSub = _eventChannel.receiveBroadcastStream().listen((event) {
        if (!mounted || !_isJamming) return;
        final data = Map<String, dynamic>.from(event);
        setState(() {
          _packetCount = data['count'] ?? _packetCount;
          _targetRssi = data['target_rssi'] ?? 0;
          if (_packetCount % 50 == 0) {
            _log.add('> [$_jamMode] $_packetCount packets sent | RSSI: $_targetRssi dBm');
            if (_log.length > 50) _log.removeAt(0);
          }
        });
      }, onError: (e) {
        if (mounted) setState(() => _log.add('> Stream error: $e'));
      });

      if (mounted) setState(() => _log.add('> Jamming started. Flood active...'));
    } on PlatformException catch (e) {
      if (mounted) setState(() {
        _log.add('> ERROR: ${e.message}');
        _isJamming = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _log.add('> ERROR: $e');
        _isJamming = false;
      });
    }
  }

  Future<void> _stopJamming() async {
    _eventSub?.cancel();
    _eventSub = null;

    try {
      final result = await _channel.invokeMethod<Map>('stopJam');
      final total = result?['total_packets'] ?? _packetCount;
      if (mounted) {
        setState(() {
          _isJamming = false;
          _log.add('> Jam stopped. Total packets: $total');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isJamming = false);
    }
  }
}

class BleInterceptScreen extends StatefulWidget {
  final String deviceName;
  final String deviceId;
  const BleInterceptScreen({super.key, required this.deviceName, required this.deviceId});

  @override
  State<BleInterceptScreen> createState() => _BleInterceptScreenState();
}

class _BleInterceptScreenState extends State<BleInterceptScreen> {
  static const _channel = MethodChannel('com.flipnova/ble');
  static const _eventChannel = EventChannel('com.flipnova/ble/events');
  bool _isCapturing = false;
  int _packetCount = 0;
  final List<Map<String, dynamic>> _capturedPackets = [];
  StreamSubscription? _eventSub;

  @override
  void dispose() {
    _stopCapture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('[ INTERCEPT: ${widget.deviceName} ]')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlipNovaTheme.bgCard,
                borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
                border: Border.all(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TARGET: ${widget.deviceName}', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.orange, fontSize: 12, weight: FontWeight.bold,
                  )),
                  const SizedBox(height: 4),
                  Text('ID: ${widget.deviceId}', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.gray, fontSize: 10,
                  )),
                  const SizedBox(height: 4),
                  Text('CAPTURED: $_packetCount packets', style: FlipNovaTheme.mono(
                    color: _isCapturing ? FlipNovaTheme.green : FlipNovaTheme.gray, fontSize: 10,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCapturing ? null : _startCapture,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlipNovaTheme.bgCard,
                      foregroundColor: FlipNovaTheme.orange,
                      side: const BorderSide(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth),
                    ),
                    child: Text(_isCapturing ? '[ CAPTURING... ]' : '[ START CAPTURE ]'),
                  ),
                ),
                if (_isCapturing) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _stopCapture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlipNovaTheme.bgCard,
                        foregroundColor: FlipNovaTheme.red,
                        side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
                      ),
                      child: const Text('[ STOP ]'),
                    ),
                  ),
                ],
                if (_capturedPackets.isNotEmpty && !_isCapturing) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _capturedPackets.clear()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlipNovaTheme.bgCard,
                        foregroundColor: FlipNovaTheme.gray,
                        side: const BorderSide(color: FlipNovaTheme.gray, width: FlipNovaTheme.borderWidth),
                      ),
                      child: const Text('[ CLEAR ]'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlipNovaTheme.bgCard,
                  borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
                  border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PACKETS:', style: FlipNovaTheme.mono(
                          color: FlipNovaTheme.orange, fontSize: 10, weight: FontWeight.bold,
                        )),
                        if (_capturedPackets.isNotEmpty)
                          Text('${_capturedPackets.length} total', style: FlipNovaTheme.mono(
                            color: FlipNovaTheme.gray, fontSize: 9,
                          )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _capturedPackets.isEmpty
                          ? Text(
                              _isCapturing
                                  ? '> Listening for BLE packets...\n> Capturing advertising data\n> Analyzing GATT responses...'
                                  : '> No packets captured yet\n> Tap [ START CAPTURE ]\n> to begin sniffing',
                              style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 11),
                            )
                          : ListView.builder(
                              itemCount: _capturedPackets.length,
                              itemBuilder: (ctx, i) {
                                final pkt = _capturedPackets[i];
                                final isTarget = pkt['is_target'] == true;
                                final rssi = pkt['rssi'] ?? 0;
                                final name = pkt['name'] ?? '';
                                final addr = pkt['address'] ?? '';
                                final hexData = pkt['data'] ?? '';
                                final services = (pkt['services'] as List?)?.join(', ') ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isTarget ? FlipNovaTheme.bgPrimary : FlipNovaTheme.bgPrimary.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: isTarget ? FlipNovaTheme.orange : FlipNovaTheme.border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isTarget) ...[
                                            const Icon(Icons.gps_fixed, size: 10, color: FlipNovaTheme.orange),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            '${isTarget ? "TARGET" : name.isNotEmpty ? name : addr} | $rssi dBm',
                                            style: FlipNovaTheme.mono(
                                              color: isTarget ? FlipNovaTheme.orange : FlipNovaTheme.cyan,
                                              fontSize: 9, weight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (hexData.isNotEmpty)
                                        Text(
                                          'HEX: $hexData',
                                          style: FlipNovaTheme.mono(
                                            color: FlipNovaTheme.gray, fontSize: 8,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (services.isNotEmpty)
                                        Text(
                                          'SVC: $services',
                                          style: FlipNovaTheme.mono(
                                            color: FlipNovaTheme.green, fontSize: 8,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCapture() async {
    setState(() {
      _isCapturing = true;
      _packetCount = 0;
      _capturedPackets.clear();
    });

    try {
      final result = await _channel.invokeMethod<Map>('startIntercept', {
        'address': widget.deviceId,
      });
      final success = result?['success'] == true;
      if (!success) {
        final error = result?['error'] ?? 'Unknown error';
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _capturedPackets.add({
              'time': '0.0s',
              'name': '',
              'address': '',
              'rssi': 0,
              'is_target': false,
              'data': 'ERROR: $error',
              'services': [],
            });
          });
        }
        return;
      }

      _eventSub?.cancel();
      _eventSub = _eventChannel.receiveBroadcastStream().listen((event) {
        if (!mounted || !_isCapturing) return;
        final data = Map<String, dynamic>.from(event);
        setState(() {
          _packetCount = data['total'] ?? _packetCount;
          _capturedPackets.insert(0, {
            'time': data['time'] ?? '${(_packetCount * 0.1).toStringAsFixed(1)}s',
            'address': data['address'] ?? '',
            'name': data['name'] ?? '',
            'rssi': data['rssi'] ?? 0,
            'is_target': data['is_target'] ?? false,
            'data': data['data'] ?? '',
            'services': data['services'] ?? [],
          });
          if (_capturedPackets.length > 200) _capturedPackets.removeLast();
        });
      }, onError: (e) {
        if (mounted) setState(() => _isCapturing = false);
      });

      if (mounted) {
        setState(() => _capturedPackets.insert(0, {
          'time': '0.0s',
          'name': '',
          'address': widget.deviceId,
          'rssi': 0,
          'is_target': true,
          'data': '>>> CAPTURE STARTED <<<',
          'services': [],
        }));
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() {
        _isCapturing = false;
        _capturedPackets.add({
          'time': '0.0s',
          'name': '',
          'address': '',
          'rssi': 0,
          'is_target': false,
          'data': 'ERROR: ${e.message}',
          'services': [],
        });
      });
    } catch (e) {
      if (mounted) setState(() {
        _isCapturing = false;
        _capturedPackets.add({
          'time': '0.0s',
          'name': '',
          'address': '',
          'rssi': 0,
          'is_target': false,
          'data': 'ERROR: $e',
          'services': [],
        });
      });
    }
  }

  Future<void> _stopCapture() async {
    _eventSub?.cancel();
    _eventSub = null;

    try {
      await _channel.invokeMethod<Map>('stopIntercept');
      if (mounted) setState(() => _isCapturing = false);
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }
}
