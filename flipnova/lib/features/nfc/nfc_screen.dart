import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/platform/platform_check.dart';

class NfcScreen extends StatefulWidget {
  const NfcScreen({super.key});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends State<NfcScreen> {
  static const _channel = MethodChannel('com.flipnova/nfc');
  String _status = 'IDLE';
  String _tagInfo = '';
  bool _isScanning = false;
  bool _nfcAvailable = false;
  bool _isEmulating = false;
  int _selectedTab = 0;

  final _emulateDataController = TextEditingController(text: '4F4C49564941');
  final _writeDataController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    if (!PlatformCheck.isMobile) {
      if (mounted) setState(() => _nfcAvailable = false);
      return;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isNfcAvailable');
      if (mounted) setState(() => _nfcAvailable = result ?? false);
    } catch (e) {
      if (mounted) setState(() => _nfcAvailable = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[ NFC ]')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusBar(),
            const SizedBox(height: 12),
            _buildTabBar(),
            const SizedBox(height: 12),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('STATUS:', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.gray, fontSize: 12,
          )),
          Text(
            _nfcAvailable
                ? (_isScanning ? 'SCANNING' : (_isEmulating ? 'EMULATING' : _status))
                : 'NFC NOT AVAILABLE',
            style: FlipNovaTheme.mono(
              color: _nfcAvailable
                  ? (_isScanning || _isEmulating ? FlipNovaTheme.green : FlipNovaTheme.green)
                  : FlipNovaTheme.red,
              fontSize: 12,
              weight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        Expanded(child: ElevatedButton(
          onPressed: () => setState(() => _selectedTab = 0),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedTab == 0 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
            foregroundColor: _selectedTab == 0 ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
          ),
          child: Text('[ READ ]', style: FlipNovaTheme.mono(
            color: _selectedTab == 0 ? FlipNovaTheme.bgCard : FlipNovaTheme.green, fontSize: 10,
          )),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: () => setState(() => _selectedTab = 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedTab == 1 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
            foregroundColor: _selectedTab == 1 ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
          ),
          child: Text('[ WRITE ]', style: FlipNovaTheme.mono(
            color: _selectedTab == 1 ? FlipNovaTheme.bgCard : FlipNovaTheme.green, fontSize: 10,
          )),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: (_nfcAvailable && PlatformCheck.isAndroid)
              ? () => setState(() => _selectedTab = 2)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedTab == 2 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
            foregroundColor: _selectedTab == 2 ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
          ),
          child: Text('[ EMULATE ]', style: FlipNovaTheme.mono(
            color: _selectedTab == 2 ? FlipNovaTheme.bgCard : FlipNovaTheme.green, fontSize: 10,
          )),
        )),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0: return _buildReadTab();
      case 1: return _buildWriteTab();
      case 2: return _buildEmulateTab();
      default: return _buildReadTab();
    }
  }

  Widget _buildReadTab() {
    return Column(
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(
              color: _isScanning ? FlipNovaTheme.green : FlipNovaTheme.border,
              width: FlipNovaTheme.borderWidth,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.nfc,
                  size: 56,
                  color: FlipNovaTheme.green,
                ),
                const SizedBox(height: 12),
                Text(
                  _isScanning ? 'SCANNING... HOLD TAG NEAR PHONE' : 'TAP TO SCAN',
                  style: FlipNovaTheme.mono(
                    color: _isScanning ? FlipNovaTheme.green : FlipNovaTheme.gray,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _nfcAvailable ? _toggleScan : null,
                child: Text(_isScanning ? '[ STOP ]' : '[ SCAN ]'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: (_nfcAvailable && _isScanning) ? _readTag : null,
                child: Text('[ READ TAG ]'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildTagData()),
      ],
    );
  }

  Widget _buildTagData() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TAG DATA:', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold,
          )),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _tagInfo.isEmpty
                    ? '> No tag detected\n> Hold NFC tag near back of phone\n> Tap [ SCAN ] then [ READ TAG ]\n\n'
                        '> Supported read modes:\n'
                        '  - UID (all NFC tags)\n'
                        '  - NDEF records\n'
                        '  - MIFARE Classic sectors'
                    : _tagInfo,
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.white,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteTab() {
    return Column(
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
              Text('NFC WRITE', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              TextField(
                controller: _writeDataController,
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.white, fontSize: 12,
                ),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter text to write to NFC tag...',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _nfcAvailable ? _writeTag : null,
          child: Text('[ WRITE TO TAG ]'),
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
                Text('WRITE INSTRUCTIONS:', style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold,
                )),
                const SizedBox(height: 8),
                Text(
                  '> Enter text data above\n'
                  '> Tap [ WRITE TO TAG ]\n'
                  '> Hold writable NFC tag near phone\n'
                  '> Tag must be NDEF-writable\n\n'
                  '> Supported tag types:\n'
                  '  - NTAG213/215/216\n'
                  '  - MIFARE Classic (locked)\n'
                  '  - MIFARE Ultralight',
                  style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.gray,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmulateTab() {
    if (!PlatformCheck.isAndroid) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_android, size: 48, color: FlipNovaTheme.green),
              const SizedBox(height: 12),
              Text('NFC EMULATION', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green, fontSize: 14, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Text(
                '> HCE (Host Card Emulation)\n> is only available on Android\n> Use Android device to emulate NFC tags',
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.gray, fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
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
              Text('NFC EMULATION (HCE)', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Text(
                '> Emulate an NFC tag using Host Card Emulation\n'
                '> Other devices can read your emulated tag\n'
                '> UID will be visible to readers',
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.gray, fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emulateDataController,
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.white, fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: 'UID hex (e.g. 4F4C49564941)',
                  isDense: true,
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _nfcAvailable ? _toggleEmulation : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEmulating ? FlipNovaTheme.red : FlipNovaTheme.bgCard,
                  foregroundColor: _isEmulating ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
                  side: BorderSide(
                    color: _isEmulating ? FlipNovaTheme.red : FlipNovaTheme.green,
                    width: FlipNovaTheme.borderWidth,
                  ),
                ),
                child: Text(_isEmulating ? '[ STOP EMULATE ]' : '[ START EMULATE ]'),
              ),
            ),
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
                Text('EMULATION LOG:', style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold,
                )),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _isEmulating
                          ? '> Emulating NFC tag...\n> UID: ${_emulateDataController.text}\n> Hold phone near an NFC reader\n> Tag will be detected as MIFARE Classic'
                          : '> Ready to emulate\n> Enter UID data above\n> Tap [ START EMULATE ]',
                      style: FlipNovaTheme.mono(
                        color: FlipNovaTheme.white, fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _toggleScan() {
    setState(() {
      _isScanning = !_isScanning;
      _status = _isScanning ? 'SCANNING' : 'IDLE';
      if (_isScanning) _tagInfo = '> Scanning for NFC tags...\n> Hold tag near phone';
    });
    _channel.invokeMethod(_isScanning ? 'startNfcScan' : 'stopNfcScan');
  }

  Future<void> _readTag() async {
    try {
      final result = await _channel.invokeMethod<Map>('readTag');
      if (result != null && mounted) {
        if (result.containsKey('error')) {
          setState(() {
            _tagInfo = '> ERROR: ${result['error']}\n> Try holding tag closer';
            _status = 'ERROR';
          });
        } else {
          final id = result['id'] ?? '??';
          final size = result['size'] ?? 0;
          final writable = result['isWritable'] ?? false;
          final tech = (result['tech'] as List?)?.join(', ') ?? '';
          final records = (result['records'] as List?) ?? [];

          final buffer = StringBuffer();
          buffer.writeln('> TAG ID: $id');
          buffer.writeln('> SIZE: $size bytes');
          buffer.writeln('> WRITABLE: $writable');
          buffer.writeln('> TECH: $tech');
          buffer.writeln('--- NDEF RECORDS ---');
          for (final rec in records) {
            final payload = (rec['payload'] as String?) ?? '';
            final type = (rec['type'] as String?) ?? '';
            buffer.writeln('> TYPE: $type');
            buffer.writeln('> DATA: $payload');
          }

          setState(() {
            _tagInfo = buffer.toString();
            _status = 'TAG READ';
          });
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _tagInfo = '> ERROR: ${e.message}\n> No tag detected yet';
          _status = 'ERROR';
        });
      }
    }
  }

  Future<void> _writeTag() async {
    final data = _writeDataController.text;
    if (data.isEmpty) return;

    try {
      setState(() => _status = 'WRITING...');
      final result = await _channel.invokeMethod<bool>('writeTag', {'data': data});
      if (mounted) {
        setState(() {
          _status = (result == true) ? 'WRITE OK' : 'WRITE FAILED';
          _tagInfo = (result == true)
              ? '> Successfully wrote ${data.length} bytes to tag'
              : '> Write failed. Ensure tag is writable and held near phone.';
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _status = 'WRITE ERROR';
          _tagInfo = '> ERROR: ${e.message}';
        });
      }
    }
  }

  void _toggleEmulation() {
    setState(() {
      _isEmulating = !_isEmulating;
      _status = _isEmulating ? 'EMULATING' : 'IDLE';
    });
    _channel.invokeMethod(_isEmulating ? 'startEmulation' : 'stopEmulation', {
      'uid': _emulateDataController.text,
    });
  }

  @override
  void dispose() {
    _emulateDataController.dispose();
    _writeDataController.dispose();
    super.dispose();
  }
}
