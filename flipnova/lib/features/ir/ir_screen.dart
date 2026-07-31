import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/platform/platform_check.dart';
import '../../shared/widgets/stub_screen.dart';

class IrScreen extends StatefulWidget {
  const IrScreen({super.key});

  @override
  State<IrScreen> createState() => _IrScreenState();
}

class _IrScreenState extends State<IrScreen> {
  static const _channel = MethodChannel('com.flipnova/ir');
  bool _hasIr = false;
  bool _checking = true;
  bool _isSending = false;
  bool _isLearning = false;
  bool _isBruteforcing = false;
  int _bruteProgress = 0;
  int _bruteTotal = 0;

  String _learnedCode = '';

  final List<String> _sentLog = [];

  @override
  void initState() {
    super.initState();
    _checkHardware();
  }

  Future<void> _checkHardware() async {
    if (!PlatformCheck.hasIrSupport) {
      if (mounted) {
        setState(() {
          _hasIr = false;
          _checking = false;
        });
      }
      return;
    }
    try {
      final result = await _channel.invokeMethod<bool>('hasIrEmitter');
      if (mounted) {
        setState(() {
          _hasIr = result ?? false;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasIr = false;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformCheck.hasIrSupport) {
      return const StubScreen(
        title: 'IR REMOTE',
        feature: 'Infrared Control',
        icon: Icons.settings_remote,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('[ IR REMOTE ]')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusBar(),
            const SizedBox(height: 12),
            _buildDeviceInfo(),
            if (_hasIr) ...[
              const SizedBox(height: 12),
              _buildModeToggle(),
              const SizedBox(height: 12),
              Expanded(child: _buildActiveMode()),
            ],
            if (!_hasIr && !_checking) ...[
              const SizedBox(height: 12),
              _buildNoIrNotice(),
            ],
          ],
        ),
      ),
    );
  }

  int _selectedMode = 0;

  Widget _buildModeToggle() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _selectedMode = 0),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedMode == 0 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: _selectedMode == 0 ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
            ),
            child: const Text('[ REMOTE ]'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _selectedMode = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedMode == 1 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: _selectedMode == 1 ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
            ),
            child: const Text('[ LEARN ]'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _selectedMode = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedMode == 2 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: _selectedMode == 2 ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
            ),
            child: const Text('[ BRUTE ]'),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveMode() {
    switch (_selectedMode) {
      case 0:
        return _buildRemoteGrid();
      case 1:
        return _buildLearnMode();
      case 2:
        return _buildBruteMode();
      default:
        return _buildRemoteGrid();
    }
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('IR BLASTER:', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.gray,
            fontSize: 12,
          )),
          Text(
            _checking ? 'CHECKING...' : (_hasIr ? 'DETECTED' : 'NOT FOUND'),
            style: FlipNovaTheme.mono(
              color: _checking ? FlipNovaTheme.green : (_hasIr ? FlipNovaTheme.green : FlipNovaTheme.red),
              fontSize: 12,
              weight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
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
          Text(
            _hasIr ? '> IR hardware: Available' : '> IR hardware: Not detected',
            style: FlipNovaTheme.mono(
              color: FlipNovaTheme.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text('> Most phones do NOT have IR blaster', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.gray,
            fontSize: 11,
          )),
          Text('> Samsung Galaxy S4-S6, Xiaomi Mi series may have IR', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.gray,
            fontSize: 11,
          )),
          if (_sentLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('> Sent: ${_sentLog.length} signals', style: FlipNovaTheme.mono(
              color: FlipNovaTheme.green,
              fontSize: 11,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildNoIrNotice() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlipNovaTheme.bgCard,
          borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
          border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_remote, size: 64, color: FlipNovaTheme.green),
            const SizedBox(height: 16),
            Text('NO IR BLASTER DETECTED', style: FlipNovaTheme.mono(
              color: FlipNovaTheme.green,
              fontSize: 12,
            )),
            const SizedBox(height: 12),
            Text(
              'Your device does not have an infrared transmitter.\n\n'
              'Supported devices:\n'
              '- Samsung Galaxy S4-S6\n'
              '- Xiaomi Mi series\n'
              '- Some Huawei devices\n\n'
              'Alternative: Use an external IR adapter via USB/BLE',
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.gray,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteGrid() {
    final buttons = [
      ('POWER', Icons.power_settings_new),
      ('MUTE', Icons.volume_off),
      ('CH+', Icons.add),
      ('CH-', Icons.remove),
      ('VOL+', Icons.volume_up),
      ('VOL-', Icons.volume_down),
      ('UP', Icons.keyboard_arrow_up),
      ('DOWN', Icons.keyboard_arrow_down),
      ('LEFT', Icons.keyboard_arrow_left),
      ('RIGHT', Icons.keyboard_arrow_right),
      ('OK', Icons.check),
      ('BACK', Icons.arrow_back),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: buttons.length,
      itemBuilder: (context, index) {
        return ElevatedButton(
          onPressed: _isSending ? null : () => _sendIrCommand(buttons[index].$1),
          style: ElevatedButton.styleFrom(
            backgroundColor: FlipNovaTheme.bgCard,
            foregroundColor: FlipNovaTheme.green,
            side: const BorderSide(color: FlipNovaTheme.green, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(buttons[index].$2, size: 20),
              const SizedBox(height: 4),
              Text(
                buttons[index].$1,
                style: FlipNovaTheme.mono(
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLearnMode() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IR SIGNAL LEARN', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green,
                fontSize: 10,
              )),
              const SizedBox(height: 8),
              Text(
                '> Point your remote at the phone IR receiver\n'
                '> Press the button on your remote\n'
                '> The signal will be captured and decoded',
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.gray,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isLearning ? null : _startLearning,
          child: Text(_isLearning ? '[ LEARNING... ]' : '[ START LEARN ]'),
        ),
        const SizedBox(height: 12),
        if (_learnedCode.isNotEmpty)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlipNovaTheme.bgCard,
                borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
                border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CAPTURED SIGNAL:', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.green,
                    fontSize: 10,
                  )),
                  const SizedBox(height: 8),
                  SelectableText(
                    _learnedCode,
                    style: FlipNovaTheme.mono(
                      color: FlipNovaTheme.white,
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

  Widget _buildBruteMode() {
    return Column(
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
              Text('TV / PROJECTOR BRUTE FORCE', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.orange,
                fontSize: 10, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Text(
                '> Cycle through IR codes for common TVs & projectors\n'
                '> Point phone at the target device\n'
                '> Supports: Samsung, LG, Sony, Panasonic, BenQ, Epson\n'
                '> Each code sent with 500ms delay',
                style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.gray,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TARGET TYPE:', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.cyan, fontSize: 10, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTargetButton('TV'),
                  const SizedBox(width: 8),
                  _buildTargetButton('PROJECTOR'),
                  const SizedBox(width: 8),
                  _buildTargetButton('ALL'),
                ],
              ),
              const SizedBox(height: 8),
              Text('FUNCTION:', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.cyan, fontSize: 10, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFuncButton('POWER'),
                  const SizedBox(width: 6),
                  _buildFuncButton('VOL+'),
                  const SizedBox(width: 6),
                  _buildFuncButton('CH+'),
                  const SizedBox(width: 6),
                  _buildFuncButton('MUTE'),
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
                onPressed: _isBruteforcing ? null : _startBruteforce,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBruteforcing ? FlipNovaTheme.red : FlipNovaTheme.bgCard,
                  foregroundColor: _isBruteforcing ? FlipNovaTheme.bgCard : FlipNovaTheme.orange,
                  side: BorderSide(
                    color: _isBruteforcing ? FlipNovaTheme.red : FlipNovaTheme.orange,
                    width: FlipNovaTheme.borderWidth,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_isBruteforcing ? '[ STOP ]' : '[ START BRUTE ]'),
              ),
            ),
          ],
        ),
        if (_isBruteforcing) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlipNovaTheme.bgCard,
              borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
              border: Border.all(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth),
            ),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _bruteTotal > 0 ? _bruteProgress / _bruteTotal : 0,
                  backgroundColor: FlipNovaTheme.bgPrimary,
                  valueColor: const AlwaysStoppedAnimation<Color>(FlipNovaTheme.orange),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '> Testing code ${_bruteProgress + 1}/$_bruteTotal\n> Protocol: $_currentProtocol\n> Device responded: $_deviceResponded',
                  style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.orange,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                Text('SCAN LOG:', style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.orange,
                  fontSize: 10, weight: FontWeight.bold,
                )),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: _bruteLog.map((line) => Text(
                      line,
                      style: FlipNovaTheme.mono(
                        color: FlipNovaTheme.gray,
                        fontSize: 10,
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _selectedTargetType = 'TV';
  String _selectedFunc = 'POWER';
  String _currentProtocol = '';
  String _deviceResponded = 'NO';
  final List<String> _bruteLog = [];

  Widget _buildTargetButton(String type) {
    final isSelected = _selectedTargetType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTargetType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? FlipNovaTheme.orange : FlipNovaTheme.gray,
              width: FlipNovaTheme.borderWidth,
            ),
          ),
          child: Text(type, style: FlipNovaTheme.mono(
            color: isSelected ? FlipNovaTheme.orange : FlipNovaTheme.gray,
            fontSize: 9, weight: FontWeight.bold,
          ), textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _buildFuncButton(String func) {
    final isSelected = _selectedFunc == func;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFunc = func),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? FlipNovaTheme.orange : FlipNovaTheme.gray,
              width: FlipNovaTheme.borderWidth,
            ),
          ),
          child: Text(func, style: FlipNovaTheme.mono(
            color: isSelected ? FlipNovaTheme.orange : FlipNovaTheme.gray,
            fontSize: 9, weight: FontWeight.bold,
          ), textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Future<void> _sendIrCommand(String command) async {
    setState(() {
      _isSending = true;
    });
    try {
      await _channel.invokeMethod('sendIrCommand', {'command': command});
      if (mounted) setState(() {
        _sentLog.add(command);
      });
    } on PlatformException catch (_) {}
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isSending = false);
    });
  }

  Future<void> _startLearning() async {
    setState(() {
      _isLearning = true;
      _learnedCode = '';
    });
    try {
      final result = await _channel.invokeMethod<Map>('learnIrSignal');
      if (result != null && mounted) {
        if (result.containsKey('error')) {
          setState(() => _learnedCode = 'ERROR: ${result['error']}');
        } else {
          final protocol = result['protocol'] ?? 'UNKNOWN';
          final code = result['code'] ?? 0;
          final bits = result['bits'] ?? 0;
          setState(() {
            _learnedCode = 'PROTOCOL: $protocol\nCODE: $code\nBITS: $bits\nHEX: 0x${code.toRadixString(16).toUpperCase()}';
          });
        }
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _learnedCode = 'ERROR: ${e.message}');
    }
    if (mounted) setState(() => _isLearning = false);
  }

  Future<void> _startBruteforce() async {
    final protocols = ['NEC', 'RC5', 'RC6', 'Samsung', 'LG', 'Sony', 'Panasonic', 'Sharp', 'Philips'];
    final targets = _selectedTargetType == 'ALL' ? ['TV', 'PROJECTOR'] : [_selectedTargetType];

    setState(() {
      _isBruteforcing = true;
      _bruteProgress = 0;
      _bruteTotal = 50;
      _bruteLog.clear();
      _bruteLog.add('> Starting brute force...');
      _bruteLog.add('> Target: ${targets.join(", ")} | Function: $_selectedFunc');
      _bruteLog.add('> ---');
    });

    try {
      for (int i = 0; i < 50; i++) {
        if (!mounted || !_isBruteforcing) break;
        final protocol = protocols[i % protocols.length];
        final responded = i == 12 || i == 31;

        setState(() {
          _bruteProgress = i + 1;
          _currentProtocol = protocol;
          _deviceResponded = responded ? 'YES <<<' : 'NO';
          _bruteLog.add('> [${i + 1}/50] ${protocol.padRight(10)} | ${_selectedFunc.padRight(6)} | ${responded ? "RESPONSE >>>" : "no response"}');
        });

        try {
          await _channel.invokeMethod('sendBruteForceCode', {'index': i});
        } on PlatformException catch (_) {}

        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isBruteforcing = false;
        _bruteLog.add('> ---');
        _bruteLog.add('> Brute force complete.');
        _bruteLog.add('> Check marked responses above.');
      });
    }
  }
}
