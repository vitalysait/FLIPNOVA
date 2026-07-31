import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  static const _channel = MethodChannel('com.flipnova/qr');
  final _textController = TextEditingController();
  String _qrData = '';
  String _scanResult = '';
  bool _showGenerator = true;
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[ QR CODE ]')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToggle(),
            const SizedBox(height: 12),
            Expanded(
              child: _showGenerator ? _buildGenerator() : _buildScanner(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() {
              _showGenerator = false;
              _scanResult = '';
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: !_showGenerator ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: !_showGenerator ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
            ),
            child: const Text('[ SCANNER ]'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _showGenerator = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showGenerator ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: _showGenerator ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
            ),
            child: const Text('[ GENERATOR ]'),
          ),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: FlipNovaTheme.bgCard,
              borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
              border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
            ),
            child: _scanResult.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 64, color: FlipNovaTheme.green),
                        const SizedBox(height: 12),
                        Text(
                          'QR BARCODE SCANNER',
                          style: FlipNovaTheme.mono(
                            color: FlipNovaTheme.green,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap button below to scan',
                          style: FlipNovaTheme.mono(
                            color: FlipNovaTheme.gray,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SCAN RESULT:', style: FlipNovaTheme.mono(
                          color: FlipNovaTheme.green,
                          fontSize: 10,
                          weight: FontWeight.bold,
                        )),
                        const SizedBox(height: 8),
                        SelectableText(
                          _scanResult,
                          style: FlipNovaTheme.mono(
                            color: FlipNovaTheme.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isScanning ? null : _startScan,
                child: Text(_isScanning ? '[ SCANNING... ]' : '[ SCAN ]'),
              ),
            ),
            if (_scanResult.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _scanResult = ''),
                  child: const Text('[ CLEAR ]'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildGenerator() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: TextField(
            controller: _textController,
            style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Enter text for QR code...',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _qrData = v),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _qrData.isEmpty
              ? Center(
                  child: Text(
                    '> Enter text above to generate QR',
                    style: FlipNovaTheme.mono(
                      color: FlipNovaTheme.gray,
                      fontSize: 12,
                    ),
                  ),
                )
              : Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlipNovaTheme.bgCard,
                      borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
                      border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
                    ),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: FlipNovaTheme.bgCard,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: FlipNovaTheme.white,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: FlipNovaTheme.white,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          '> ${_qrData.length} chars',
          style: FlipNovaTheme.mono(
            color: FlipNovaTheme.gray,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      final result = await _channel.invokeMethod<Map>('scanQr');
      if (result != null && mounted) {
        if (result.containsKey('error')) {
          setState(() => _scanResult = 'ERROR: ${result['error']}');
        } else {
          setState(() {
            _scanResult = result['content'] as String? ?? '';
          });
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _scanResult = 'ERROR: ${e.message}');
      }
    }
    if (mounted) setState(() => _isScanning = false);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
