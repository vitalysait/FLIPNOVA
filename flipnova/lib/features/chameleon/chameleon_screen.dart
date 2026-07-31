import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/theme.dart';
import '../../core/services/permissions_service.dart';

class ChameleonScreen extends StatefulWidget {
  const ChameleonScreen({super.key});

  @override
  State<ChameleonScreen> createState() => _ChameleonScreenState();
}

class _ChameleonScreenState extends State<ChameleonScreen> {
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isBusy = false;
  int _selectedTab = 0;

  final List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  BluetoothDevice? _device;
  StreamSubscription? _disconnectSub;
  StreamSubscription? _rxSub;
  BluetoothCharacteristic? _txChar;
  BluetoothCharacteristic? _rxChar;

  String _firmwareVersion = '--';
  String _batteryLevel = '--';
  String _deviceName = '';
  int _activeSlot = 0;

  final List<SlotInfo> _slots = List.generate(8, (i) => SlotInfo(index: i));
  int _selectedSlot = 0;
  bool _isEmulating = false;
  bool _isReading = false;
  final List<String> _log = [];
  Uint8List? _lastReadData;

  final _rxBuffer = <int>[];
  Completer<Uint8List?> _pendingResponse = Completer<Uint8List?>();
  bool _hasPending = false;

  static const _sof = 0x11;

  @override
  void dispose() {
    _scanSub?.cancel();
    _rxSub?.cancel();
    _disconnectSub?.cancel();
    _cleanupDevice();
    super.dispose();
  }

  void _s(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('[ CHAMELEON ]', style: FlipNovaTheme.mono(
          color: FlipNovaTheme.cyan, fontSize: 14, weight: FontWeight.bold,
        )),
        actions: [
          if (_isConnected)
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: FlipNovaTheme.green,
                )),
                const SizedBox(width: 6),
                Text('ONLINE', style: FlipNovaTheme.mono(color: FlipNovaTheme.green, fontSize: 10)),
              ]),
            )),
        ],
      ),
      body: _isConnected ? _buildConnectedView() : _buildScanView(),
    );
  }

  // ==================== SCAN VIEW ====================

  Widget _buildScanView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.cyan, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CHAMELEON ULTRA', style: FlipNovaTheme.mono(
              color: FlipNovaTheme.cyan, fontSize: 12, weight: FontWeight.bold,
            )),
            const SizedBox(height: 4),
            Text('> NFC emulator + reader via BLE\n> 8 slots | MIFARE Classic / Ultralight / NTAG\n> Binary protocol: SOF(0x11)+CMD+LEN+DATA+CRC8',
              style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: _isScanning ? null : _startScan,
            child: Text(_isScanning ? '[ SCANNING... ]' : '[ SCAN ]'),
          )),
          if (_isScanning) ...[
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: _stopScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.red,
                side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
              ),
              child: const Text('[ STOP ]'),
            )),
          ],
        ]),
        const SizedBox(height: 12),
        Expanded(child: _buildDeviceList()),
      ]),
    );
  }

  Widget _buildDeviceList() {
    if (_scanResults.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: FlipNovaTheme.bgCard,
          borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
          border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(_isScanning
            ? '> Scanning for Chameleon Ultra...\n> Device name contains "Chameleon"\n> Service UUID: FFF0'
            : '> No devices found\n> Press SCAN',
          style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 12)),
      );
    }

    return ListView.builder(
      itemCount: _scanResults.length,
      itemBuilder: (context, i) {
        final r = _scanResults[i];
        final d = r.device;
        final name = d.platformName.isNotEmpty ? d.platformName : 'Chameleon Ultra';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.cyan, width: FlipNovaTheme.borderWidth),
          ),
          child: InkWell(
            onTap: () => _connectDevice(d),
            child: Row(children: [
              const Icon(Icons.pets, color: FlipNovaTheme.cyan, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11, weight: FontWeight.bold)),
                Text(d.remoteId.str, style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${r.rssi} dBm', style: FlipNovaTheme.mono(color: FlipNovaTheme.cyan, fontSize: 12, weight: FontWeight.bold)),
                Text('TAP TO CONNECT', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 8)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  // ==================== CONNECTED VIEW ====================

  Widget _buildConnectedView() {
    return Column(children: [
      _buildInfoBar(),
      const SizedBox(height: 8),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        _tab('SLOTS', 0), const SizedBox(width: 6),
        _tab('EMULATE', 1), const SizedBox(width: 6),
        _tab('READER', 2), const SizedBox(width: 6),
        _tab('LOG', 3),
      ])),
      const SizedBox(height: 8),
      Expanded(child: [
        _buildSlotsTab, _buildEmulateTab, _buildReaderTab, _buildLogTab,
      ][_selectedTab]()),
    ]);
  }

  Widget _buildInfoBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
      ),
      child: Row(children: [
        const Icon(Icons.pets, color: FlipNovaTheme.green, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_deviceName.isNotEmpty ? _deviceName : 'Chameleon Ultra', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.white, fontSize: 11, weight: FontWeight.bold)),
          Text('FW: $_firmwareVersion | BAT: $_batteryLevel | SLOT: ${_activeSlot + 1}',
            style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 9)),
        ])),
        if (_isBusy) const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: FlipNovaTheme.cyan)),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _disconnect, style: ElevatedButton.styleFrom(
          backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.red,
          side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
        ), child: const Text('[ DISCONNECT ]')),
      ]),
    );
  }

  Widget _tab(String label, int index) {
    final sel = _selectedTab == index;
    return Expanded(child: ElevatedButton(
      onPressed: () => _s(() => _selectedTab = index),
      style: ElevatedButton.styleFrom(
        backgroundColor: sel ? FlipNovaTheme.cyan : FlipNovaTheme.bgCard,
        foregroundColor: sel ? FlipNovaTheme.bgPrimary : FlipNovaTheme.cyan,
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(label, style: FlipNovaTheme.mono(fontSize: 9)),
    ));
  }

  // ==================== SLOTS ====================

  Widget _buildSlotsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: _isBusy ? null : _cmdGetSlotInfo,
            child: const Text('[ REFRESH SLOTS ]'),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            onPressed: _isBusy ? null : _cmdActivateSlot,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.green,
              side: const BorderSide(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
            ),
            child: const Text('[ ACTIVATE ]'),
          )),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 2.0, crossAxisSpacing: 8, mainAxisSpacing: 8,
            ),
            itemCount: 8,
            itemBuilder: (context, i) {
              final slot = _slots[i];
              final sel = _selectedSlot == i;
              final active = _activeSlot == i;
              final isEmpty = slot.type == 0;
              return GestureDetector(
                onTap: () => _s(() => _selectedSlot = i),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sel ? FlipNovaTheme.bgCardHover : FlipNovaTheme.bgCard,
                    borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
                    border: Border.all(
                      color: active ? FlipNovaTheme.green : sel ? FlipNovaTheme.cyan : FlipNovaTheme.border,
                      width: sel ? 2 : FlipNovaTheme.borderWidth,
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Row(children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEmpty ? FlipNovaTheme.gray : active ? FlipNovaTheme.green : FlipNovaTheme.cyan,
                      )),
                      const SizedBox(width: 4),
                      Text('SLOT ${i + 1}', style: FlipNovaTheme.mono(
                        color: sel ? FlipNovaTheme.cyan : FlipNovaTheme.white, fontSize: 9, weight: FontWeight.bold)),
                      const Spacer(),
                      if (active) Text('ACT', style: FlipNovaTheme.mono(color: FlipNovaTheme.green, fontSize: 7)),
                    ]),
                    const SizedBox(height: 2),
                    Text(slot.typeName, style: FlipNovaTheme.mono(
                      color: isEmpty ? FlipNovaTheme.gray : FlipNovaTheme.green, fontSize: 8)),
                    if (!isEmpty)
                      Text('UID: ${slot.uid}', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 7), overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: _isBusy ? null : _cmdGetSlotData,
            child: const Text('[ READ DUMP ]'),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            onPressed: _isBusy ? null : _cmdDeleteSlot,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.red,
              side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
            ),
            child: const Text('[ CLEAR SLOT ]'),
          )),
        ]),
        const SizedBox(height: 8),
        if (_lastReadData != null) Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LAST DATA (${_lastReadData!.length}B):', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 9)),
            const SizedBox(height: 4),
            Text(_formatHex(_lastReadData!), style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 8)),
          ]),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ==================== EMULATE ====================

  Widget _buildEmulateTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NFC EMULATION', style: FlipNovaTheme.mono(color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('> CMD 0x0413 → device starts NFC-A emulation\n> SLOT ${_activeSlot + 1} | ${_slots[_activeSlot].typeName}\n> Hold Chameleon near NFC reader',
              style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: _isEmulating ? FlipNovaTheme.green : FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Column(children: [
              Text(_isEmulating ? 'ACTIVE' : 'IDLE', style: FlipNovaTheme.mono(
                color: _isEmulating ? FlipNovaTheme.green : FlipNovaTheme.gray, fontSize: 14, weight: FontWeight.bold)),
              Text('STATUS', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 8)),
            ]),
            Column(children: [
              Text('SLOT ${_activeSlot + 1}', style: FlipNovaTheme.mono(color: FlipNovaTheme.cyan, fontSize: 14, weight: FontWeight.bold)),
              Text('SLOT', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 8)),
            ]),
            Column(children: [
              Text(_slots[_activeSlot].typeName, style: FlipNovaTheme.mono(color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold)),
              Text('TYPE', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 8)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: (_isEmulating || _isBusy) ? null : _cmdStartEmulation,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.green,
              side: const BorderSide(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_isEmulating ? '[ EMULATING... ]' : '[ START EMULATION ]'),
          )),
          if (_isEmulating) ...[
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: _cmdStopEmulation,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.red,
                side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('[ STOP ]'),
            )),
          ],
        ]),
        const SizedBox(height: 12),
        Expanded(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SLOT DATA:', style: FlipNovaTheme.mono(color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: _slots[_activeSlot].type == 0
                ? Text('> Slot ${_activeSlot + 1} empty\n> REFRESH SLOTS to check device', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 11))
                : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _dr('TYPE', _slots[_activeSlot].typeName),
                    _dr('UID', _slots[_activeSlot].uid),
                    _dr('ATQA', _slots[_activeSlot].atqa),
                    _dr('SAK', _slots[_activeSlot].sak),
                    if (_lastReadData != null) ...[
                      const SizedBox(height: 8),
                      Text('RAW (${_lastReadData!.length}B):', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 9)),
                      Text(_formatHex(_lastReadData!), style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 8)),
                    ],
                  ])),
          ),
          ]),
        )),
      ]),
    );
  }

  // ==================== READER ====================

  Widget _buildReaderTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NFC READER', style: FlipNovaTheme.mono(color: FlipNovaTheme.orange, fontSize: 10, weight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('> CMD 0x0412 → Chameleon reads NFC-A tag\n> Hold tag near device antenna\n> UID, ATQA, SAK returned via BLE',
              style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
          ]),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: (_isReading || _isBusy) ? null : _cmdReaderScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.orange,
            side: const BorderSide(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(_isReading ? '[ READING... ]' : '[ SCAN NFC TAG ]'),
        ),
        const SizedBox(height: 12),
        Expanded(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('READER OUTPUT:', style: FlipNovaTheme.mono(color: FlipNovaTheme.orange, fontSize: 10, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: _lastReadData != null
                ? SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('RAW HEX (${_lastReadData!.length} bytes):', style: FlipNovaTheme.mono(color: FlipNovaTheme.orange, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(_formatHex(_lastReadData!), style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 9)),
                  ]))
                : Text('> Tap [ SCAN NFC TAG ]\n> Hold tag near Chameleon Ultra',
                    style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 11)),
            ),
          ]),
        )),
        const SizedBox(height: 12),
      ]),
    );
  }

  // ==================== LOG ====================

  Widget _buildLogTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('BLE LOG:', style: FlipNovaTheme.mono(color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold)),
            if (_log.isNotEmpty) TextButton(
              onPressed: () => _s(() => _log.clear()),
              child: Text('[ CLEAR ]', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 9)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: _log.isEmpty
              ? Text('> No events', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 11))
              : ListView(children: _log.map((l) => Text(l, style: FlipNovaTheme.mono(
                  color: l.contains('ERR') ? FlipNovaTheme.red : l.contains('OK') ? FlipNovaTheme.green : FlipNovaTheme.gray,
                  fontSize: 10))).toList()),
        )),
        const SizedBox(height: 12),
      ]),
    );
  }

  // ==================== HELPERS ====================

  Widget _dr(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $value', style: FlipNovaTheme.mono(
        color: value.isEmpty ? FlipNovaTheme.gray : FlipNovaTheme.white, fontSize: 10)));
  }

  String _formatHex(Uint8List data) {
    final sb = StringBuffer();
    for (var i = 0; i < data.length; i += 16) {
      final end = (i + 16 < data.length ? i + 16 : data.length);
      final chunk = data.sublist(i, end);
      final hex = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final ascii = String.fromCharCodes(chunk.map((b) => (b >= 32 && b < 127) ? b : 46));
      sb.writeln('${i.toRadixString(16).padLeft(4, '0')}  $hex  $ascii');
    }
    return sb.toString();
  }

  void _logMsg(String message) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _s(() {
      _log.add('[$ts] $message');
      if (_log.length > 200) _log.removeAt(0);
    });
  }

  bool _isChameleonDevice(ScanResult r) {
    try {
      final name = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : '';
      if (name.toUpperCase().contains('CHAMELEON')) return true;
      if (name.toUpperCase().contains('FLIPPER')) return true;
      for (final u in r.advertisementData.serviceUuids) {
        final s = u.toString().toLowerCase();
        if (s.contains('fff0') || s.contains('ffe0')) return true;
      }
    } catch (_) {}
    return false;
  }

  // ==================== BLE PROTOCOL ====================

  int _crc8(List<int> data) {
    int crc = 0x00;
    for (final byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        crc = (crc & 0x80) != 0 ? ((crc << 1) ^ 0x31) & 0xFF : (crc << 1) & 0xFF;
      }
    }
    return crc;
  }

  Uint8List _buildFrame(int cmd, [List<int>? data]) {
    final payload = data ?? [];
    final len = payload.length;
    final body = <int>[
      (cmd >> 8) & 0xFF, cmd & 0xFF,
      (len >> 8) & 0xFF, len & 0xFF,
      ...payload,
    ];
    final frame = <int>[_sof, ...body, _crc8(body)];
    return Uint8List.fromList(frame);
  }

  void _onBleData(List<int> raw) {
    _rxBuffer.addAll(raw);

    while (_rxBuffer.length >= 6) {
      final sofIdx = _rxBuffer.indexOf(_sof);
      if (sofIdx < 0) { _rxBuffer.clear(); break; }
      if (sofIdx > 0) { _rxBuffer.removeRange(0, sofIdx); continue; }

      final cmdH = _rxBuffer[1];
      final cmdL = _rxBuffer[2];
      final status = _rxBuffer[3];
      final lenH = _rxBuffer[4];
      final lenL = _rxBuffer[5];
      final dataLen = (lenH << 8) | lenL;
      final totalLen = 6 + dataLen + 1;

      if (_rxBuffer.length < totalLen) break;

      final frame = Uint8List.fromList(_rxBuffer.sublist(0, totalLen));
      _rxBuffer.removeRange(0, totalLen);

      final cmd = (cmdH << 8) | cmdL;
      final data = (dataLen > 0) ? frame.sublist(6, 6 + dataLen) : Uint8List(0);
      final expectedCrc = _crc8(frame.sublist(1, 6 + dataLen));
      final actualCrc = frame[6 + dataLen];

      _logMsg('< RX CMD:0x${cmd.toRadixString(16).padLeft(4, '0')} ST:$status [${data.length}B] CRC:${expectedCrc == actualCrc ? "OK" : "ERR(${actualCrc.toRadixString(16)})"}');

      if (data.isNotEmpty) {
        _lastReadData = data;
      }

      if (_hasPending && !_pendingResponse.isCompleted) {
        _pendingResponse.complete(frame);
      }

      _s(() {});
    }
  }

  Future<void> _startScan() async {
    final hasPermission = await PermissionsService.instance.requestBluetooth();
    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bluetooth permission required', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11)),
        backgroundColor: FlipNovaTheme.red));
      return;
    }

    _s(() { _isScanning = true; _scanResults.clear(); });

    try {
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        if (!mounted) return;
        final found = results.where((r) => _isChameleonDevice(r)).toList();
        _s(() { _scanResults.clear(); _scanResults.addAll(found); });
      }, onError: (e) => false);

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10), androidUsesFineLocation: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Scan error: $e', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11)),
        backgroundColor: FlipNovaTheme.red));
    }
    _s(() => _isScanning = false);
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _scanSub = null;
    _s(() => _isScanning = false);
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    _logMsg('> Connecting to ${device.platformName}...');
    _s(() => _isBusy = true);
    try {
      await device.connect(timeout: const Duration(seconds: 10), license: License.nonprofit);

      try { await device.requestMtu(512); } catch (_) {}
      try { await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high); } catch (_) {}

      _disconnectSub?.cancel();
      _disconnectSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          _logMsg('> Device disconnected');
          _s(() { _isConnected = false; _isEmulating = false; _isReading = false; _device = null; });
        }
      });

      final services = await device.discoverServices();
      _device = device;
      _deviceName = device.platformName.isNotEmpty ? device.platformName : 'Chameleon Ultra';

      for (final s in services) {
        for (final c in s.characteristics) {
          try {
            final uuid = c.uuid.str.toLowerCase();
            if (uuid.contains('fff1') && c.properties.writeWithoutResponse) {
              _txChar = c;
              _logMsg('> TX: ${c.uuid.str}');
            }
            if (uuid.contains('fff2') && (c.properties.notify || c.properties.read)) {
              _rxChar = c;
              if (c.properties.notify) {
                await c.setNotifyValue(true);
                _rxSub?.cancel();
                _rxSub = c.onValueReceived.listen((value) {
                  if (!mounted) return;
                  _onBleData(value);
                });
              }
              _logMsg('> RX: ${c.uuid.str}');
            }
            if (c.properties.read && uuid.contains('2a26')) {
              final v = await c.read();
              final ascii = String.fromCharCodes(v.where((b) => b >= 32 && b < 127));
              if (ascii.isNotEmpty) _firmwareVersion = ascii;
            }
            if (c.properties.read && uuid.contains('2a19')) {
              final v = await c.read();
              if (v.isNotEmpty) _batteryLevel = '${v[0]}%';
            }
          } catch (_) {}
        }
      }

      _s(() => _isConnected = true);
      _logMsg('> Connected | FW: $_firmwareVersion | BAT: $_batteryLevel');

      await _cmdGetDeviceInfo();
      await _cmdGetSlotInfo();
    } catch (e) {
      _logMsg('> ERR: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e', style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11)),
        backgroundColor: FlipNovaTheme.red));
    }
    _s(() => _isBusy = false);
  }

  void _cleanupDevice() {
    try { _txChar?.setNotifyValue(false).catchError((_) => false); } catch (_) {}
    try { _rxChar?.setNotifyValue(false).catchError((_) => false); } catch (_) {}
    _txChar = null;
    _rxChar = null;
  }

  Future<void> _disconnect() async {
    _cleanupDevice();
    try { await _device?.disconnect(); } catch (_) {}
    _rxSub?.cancel();
    _rxSub = null;
    _disconnectSub?.cancel();
    _disconnectSub = null;
    _s(() { _isConnected = false; _isEmulating = false; _isReading = false; _device = null; });
  }

  Future<void> _sendFrame(int cmd, [List<int>? data]) async {
    if (_txChar == null) { _logMsg('> ERR: TX not found'); return; }
    final frame = _buildFrame(cmd, data);
    _logMsg('> TX CMD:0x${cmd.toRadixString(16).padLeft(4, '0')} [${frame.length}B]');
    try {
      await _txChar!.write(frame, withoutResponse: true);
    } catch (e) {
      _logMsg('> ERR write: $e');
    }
  }

  Future<Uint8List?> _sendAndWait(int cmd, {List<int>? data, Duration timeout = const Duration(seconds: 3)}) async {
    _pendingResponse = Completer<Uint8List?>();
    _hasPending = true;
    final timer = Timer(timeout, () {
      if (!_pendingResponse.isCompleted) _pendingResponse.complete(null);
    });

    await _sendFrame(cmd, data);
    final result = await _pendingResponse.future;
    timer.cancel();
    _hasPending = false;
    return result;
  }

  // ==================== COMMANDS ====================

  static const _cmdDeviceInfo = 0x0001;
  static const _cmdSlotInfo = 0x0100;
  static const _cmdSetActiveSlot = 0x0103;
  static const _cmdGetActiveSlot = 0x0102;
  static const _cmdSlotData = 0x0106;
  static const _cmdSlotDelete = 0x0107;
  static const _cmdHf14aScan = 0x0412;
  static const _cmdHf14aEmulate = 0x0413;

  Future<void> _cmdGetDeviceInfo() async {
    _logMsg('> GET_DEVICE_INFO (0x0001)');
    _s(() => _isBusy = true);
    final resp = await _sendAndWait(_cmdDeviceInfo);
    if (resp != null && resp.length >= 7) {
      final data = resp.sublist(6, 6 + (resp[4] << 8 | resp[5]));
      if (data.isNotEmpty) {
        final fw = String.fromCharCodes(data.where((b) => b >= 32 && b < 127));
        if (fw.isNotEmpty) { _firmwareVersion = fw; _s(() {}); }
      }
      _logMsg('> Device info: ${data.length}B');
    } else {
      _logMsg('> No response');
    }
    _s(() => _isBusy = false);
  }

  Future<void> _cmdGetSlotInfo() async {
    _logMsg('> GET_SLOT_INFO (0x0100)');
    _s(() => _isBusy = true);
    final resp = await _sendAndWait(_cmdSlotInfo);
    if (resp != null && resp.length >= 6) {
      final dataLen = (resp[4] << 8) | resp[5];
      final data = resp.sublist(6, 6 + dataLen);
      _logMsg('> Slot info: ${data.length}B payload');
      _parseSlotInfo(data);
      _s(() {});
    } else {
      _logMsg('> No slot info response');
    }
    _s(() => _isBusy = false);
  }

  void _parseSlotInfo(Uint8List data) {
    int offset = 0;
    for (int i = 0; i < 8 && offset < data.length; i++) {
      final type = data[offset++];
      if (offset >= data.length) break;
      final uidLen = data[offset++];
      final uidBytes = (offset + uidLen <= data.length) ? data.sublist(offset, offset + uidLen) : <int>[];
      offset += uidLen;
      final atqaH = (offset < data.length) ? data[offset] : 0;
      final atqaL = (offset + 1 < data.length) ? data[offset + 1] : 0;
      offset += 2;
      final sak = (offset < data.length) ? data[offset] : 0;
      offset += 1;

      final uid = uidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
      final atqa = '${atqaH.toRadixString(16).padLeft(2, '0')}${atqaL.toRadixString(16).padLeft(2, '0')}';

      _slots[i]
        ..type = type
        ..uid = uid
        ..atqa = atqa
        ..sak = sak.toRadixString(16).padLeft(2, '0');

      _logMsg('> SLOT ${i + 1}: ${_slotTypeName(type)} UID:$uid');
    }
  }

  String _slotTypeName(int type) {
    switch (type) {
      case 0: return 'EMPTY';
      case 1: return 'MF_CLASSIC_1K';
      case 2: return 'MF_CLASSIC_4K';
      case 3: return 'MF_ULTRALIGHT';
      case 4: return 'NTAG213';
      case 5: return 'NTAG215';
      case 6: return 'NTAG216';
      case 7: return 'ISO14443A';
      default: return 'TYPE_0x${type.toRadixString(16).padLeft(2, '0')}';
    }
  }

  Future<void> _cmdGetSlotData() async {
    _s(() => _isBusy = true);
    _logMsg('> GET_SLOT_DATA (0x0106) SLOT:${_selectedSlot}');
    final resp = await _sendAndWait(_cmdSlotData, data: [_selectedSlot]);
    if (resp != null && resp.length >= 6) {
      final dataLen = (resp[4] << 8) | resp[5];
      final data = resp.sublist(6, 6 + dataLen);
      _lastReadData = data;
      _logMsg('> Slot data: ${data.length}B');
      _s(() {});
    } else {
      _logMsg('> No slot data response');
    }
    _s(() => _isBusy = false);
  }

  Future<void> _cmdActivateSlot() async {
    _s(() => _isBusy = true);
    _logMsg('> SET_ACTIVE_SLOT (0x0103) SLOT:${_selectedSlot}');
    final resp = await _sendAndWait(_cmdSetActiveSlot, data: [_selectedSlot]);
    if (resp != null && resp.length >= 6) {
      _activeSlot = _selectedSlot;
      _logMsg('> Slot ${_activeSlot + 1} activated (status:${resp[3]})');
      _s(() {});
    } else {
      _logMsg('> No response');
    }
    _s(() => _isBusy = false);
  }

  Future<void> _cmdDeleteSlot() async {
    _s(() => _isBusy = true);
    _logMsg('> DELETE_SLOT (0x0107) SLOT:${_selectedSlot}');
    final resp = await _sendAndWait(_cmdSlotDelete, data: [_selectedSlot]);
    if (resp != null) {
      _slots[_selectedSlot] = SlotInfo(index: _selectedSlot);
      _logMsg('> Slot ${_selectedSlot + 1} cleared (status:${resp[3]})');
      _s(() {});
    }
    _s(() => _isBusy = false);
  }

  Future<void> _cmdStartEmulation() async {
    _s(() { _isBusy = true; _isEmulating = true; });
    _logMsg('> HF14A_EMULATE (0x0413) SLOT:$_activeSlot');
    await _sendAndWait(_cmdHf14aEmulate, data: [_activeSlot], timeout: const Duration(seconds: 5));
    _logMsg('> Emulation active - hold near reader');
    _s(() => _isBusy = false);
  }

  Future<void> _cmdStopEmulation() async {
    _s(() => _isBusy = true);
    _logMsg('> STOP_EMULATION');
    await _sendFrame(_cmdHf14aEmulate, [0xFF]);
    _s(() { _isEmulating = false; _isBusy = false; });
    _logMsg('> Emulation stopped');
  }

  Future<void> _cmdReaderScan() async {
    _s(() { _isBusy = true; _isReading = true; _lastReadData = null; });
    _logMsg('> HF14A_SCAN (0x0412)');
    final resp = await _sendAndWait(_cmdHf14aScan, timeout: const Duration(seconds: 5));
    if (resp != null && resp.length >= 6) {
      final dataLen = (resp[4] << 8) | resp[5];
      final data = resp.sublist(6, 6 + dataLen);
      _lastReadData = data;
      if (data.isNotEmpty) {
        final uid = data.take(7).map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
        _logMsg('> TAG FOUND UID:$uid (${data.length}B)');
      } else {
        _logMsg('> No tag in range');
      }
      _s(() {});
    } else {
      _logMsg('> Scan timeout - no tag');
    }
    _s(() { _isReading = false; _isBusy = false; });
  }
}

class SlotInfo {
  final int index;
  int type;
  String uid;
  String atqa;
  String sak;

  SlotInfo({
    required this.index,
    this.type = 0,
    this.uid = '',
    this.atqa = '',
    this.sak = '',
  });

  String get typeName {
    switch (type) {
      case 0: return 'EMPTY';
      case 1: return 'MF_CLASSIC_1K';
      case 2: return 'MF_CLASSIC_4K';
      case 3: return 'MF_ULTRALIGHT';
      case 4: return 'NTAG213';
      case 5: return 'NTAG215';
      case 6: return 'NTAG216';
      case 7: return 'ISO14443A';
      default: return 'TYPE_0x${type.toRadixString(16).padLeft(2, '0')}';
    }
  }
}
