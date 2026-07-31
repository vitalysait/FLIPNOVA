import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/theme.dart';
import 'package:multicast_dns/multicast_dns.dart';

class CastScreen extends StatefulWidget {
  const CastScreen({super.key});

  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  // Use static API from FlutterBluePlus
  final List<ScanResult> _bleDevices = [];
  final List<String> _wifiDevices = [];
  bool _scanningBle = false;
  bool _scanningWifi = false;
  StreamSubscription<List<ScanResult>>? _bleSubscription;
  MDnsClient? _mdnsClient;
  bool _scanCancelled = false;

  void _startBleScan() async {
    if (!mounted) return;
    setState(() {
      _bleDevices.clear();
      _scanningBle = true;
    });

    _bleSubscription?.cancel();
    _bleSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _bleDevices.clear();
        _bleDevices.addAll(results);
      });
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    await Future.delayed(const Duration(seconds: 6));
    FlutterBluePlus.stopScan();
    await _bleSubscription?.cancel();
    _bleSubscription = null;
    if (!mounted) return;
    setState(() => _scanningBle = false);
  }

  Future<void> _scanWifiQuick() async {
    if (!mounted) return;
    setState(() {
      _scanningWifi = true;
      _scanCancelled = false;
    });
    _mdnsClient?.stop();
    _mdnsClient = MDnsClient();

    try {
      await _mdnsClient!.start();
      await for (final PtrResourceRecord ptr
          in _mdnsClient!.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('_googlecast._tcp.local'),
          )) {
        if (!mounted || _scanCancelled) break;
        final String domain = ptr.domainName;
        await for (final SrvResourceRecord srv
            in _mdnsClient!.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(domain),
            )) {
          if (!mounted || _scanCancelled) break;
          final ipName = srv.target;
          await for (final IPAddressResourceRecord ip
              in _mdnsClient!.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(ipName),
              )) {
            if (!mounted || _scanCancelled) break;
            if (!_wifiDevices.contains(ip.address.address)) {
              setState(() => _wifiDevices.add(ip.address.address));
            }
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('mDNS discovery failed or returned no devices'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _scanningWifi = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[ CAST ]')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Screen Cast',
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green,
                fontSize: 18,
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _scanningBle ? null : _startBleScan,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: Text(
                    _scanningBle ? 'Scanning...' : 'Discover via BLE',
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _scanningWifi ? null : _scanWifiQuick,
                  icon: const Icon(Icons.wifi),
                  label: Text(
                    _scanningWifi ? 'Scanning...' : 'Discover via Wi‑Fi',
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final ip = await _promptManualIp();
                    if (ip != null && ip.isNotEmpty) {
                      setState(() {
                        if (!_wifiDevices.contains(ip)) {
                          _wifiDevices.add(ip);
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Wi‑Fi device'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildDevicesList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList() {
    final total = _bleDevices.length + _wifiDevices.length;
    if (total == 0) {
      return Center(
        child: Text(
          'No devices found',
          style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      itemCount: total,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i < _bleDevices.length) {
          final r = _bleDevices[i];
          final name = r.device.name.isNotEmpty
              ? r.device.name
              : r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.id.str;
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(
              name,
              style: FlipNovaTheme.mono(color: FlipNovaTheme.white),
            ),
            subtitle: Text(
              'BLE • RSSI: ${r.rssi}',
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.gray,
                fontSize: 11,
              ),
            ),
            trailing: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Connect to $name — not implemented')),
                );
              },
              child: const Text('Connect'),
            ),
          );
        }

        final idx = i - _bleDevices.length;
        final ip = _wifiDevices[idx];
        return ListTile(
          leading: const Icon(Icons.tv),
          title: Text(
            ip,
            style: FlipNovaTheme.mono(color: FlipNovaTheme.white),
          ),
          subtitle: Text(
            'Wi‑Fi device',
            style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 11),
          ),
          trailing: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Connect to $ip — not implemented')),
              );
            },
            child: const Text('Connect'),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _bleSubscription?.cancel();
    _scanCancelled = true;
    _mdnsClient?.stop();
    super.dispose();
  }

  Future<String?> _promptManualIp() async {
    String? value;
    await showDialog(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Add Wi‑Fi device IP'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'e.g. 192.168.1.42'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                value = ctrl.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    return value;
  }
}
