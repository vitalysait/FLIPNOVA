import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  static const _eventChannel = EventChannel('com.flipnova/sensors/events');
  static const _methodChannel = MethodChannel('com.flipnova/sensors');

  double _accelX = 0, _accelY = 0, _accelZ = 0;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double _compassHeading = 0;
  double _lightLevel = 0;
  double _proximity = -1;
  double _pressure = 0;
  StreamSubscription? _eventSub;
  bool _isStreaming = false;
  List<Map<String, dynamic>> _sensorList = [];

  @override
  void initState() {
    super.initState();
    _startListening();
    _getSensorList();
  }

  void _startListening() {
    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        (dynamic data) {
          if (data is Map && mounted) {
            setState(() {
              _isStreaming = true;
              if (data.containsKey('accel')) {
                final a = data['accel'] as List;
                _accelX = (a[0] as num).toDouble();
                _accelY = (a[1] as num).toDouble();
                _accelZ = (a[2] as num).toDouble();
              }
              if (data.containsKey('gyro')) {
                final g = data['gyro'] as List;
                _gyroX = (g[0] as num).toDouble();
                _gyroY = (g[1] as num).toDouble();
                _gyroZ = (g[2] as num).toDouble();
              }
              if (data.containsKey('compass')) {
                _compassHeading = (data['compass'] as num).toDouble();
              }
              if (data.containsKey('light')) {
                _lightLevel = (data['light'] as num).toDouble();
              }
              if (data.containsKey('proximity')) {
                _proximity = (data['proximity'] as num).toDouble();
              }
              if (data.containsKey('pressure')) {
                _pressure = (data['pressure'] as num).toDouble();
              }
            });
          }
        },
        onError: (dynamic error) {
          if (mounted) {
            setState(() => _isStreaming = false);
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _getSensorList() async {
    try {
      final result = await _methodChannel.invokeMethod<List>('getSensorList');
      if (result != null && mounted) {
        setState(() {
          _sensorList = result.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('[ SENSORS ]', style: FlipNovaTheme.mono(
          color: FlipNovaTheme.green, fontSize: 14, weight: FontWeight.bold,
        )),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isStreaming ? FlipNovaTheme.green : FlipNovaTheme.red,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isStreaming ? 'LIVE' : 'OFF',
                    style: FlipNovaTheme.mono(
                      color: _isStreaming ? FlipNovaTheme.green : FlipNovaTheme.red,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCompass(),
            const SizedBox(height: 16),
            _buildSensorCard('ACCELEROMETER [m/s²]', [
              ('X', _accelX.toStringAsFixed(3)),
              ('Y', _accelY.toStringAsFixed(3)),
              ('Z', _accelZ.toStringAsFixed(3)),
              ('MAG', _magnitude(_accelX, _accelY, _accelZ).toStringAsFixed(2)),
            ]),
            const SizedBox(height: 12),
            _buildSensorCard('GYROSCOPE [rad/s]', [
              ('X', _gyroX.toStringAsFixed(3)),
              ('Y', _gyroY.toStringAsFixed(3)),
              ('Z', _gyroZ.toStringAsFixed(3)),
            ]),
            const SizedBox(height: 12),
            _buildSensorCard('COMPASS', [
              ('HEADING', '${_compassHeading.toStringAsFixed(1)}°'),
              ('DIR', _getDirection(_compassHeading)),
              ('RAD', (_compassHeading * pi / 180).toStringAsFixed(3)),
            ]),
            const SizedBox(height: 12),
            _buildSensorCard('ENVIRONMENT', [
              ('LIGHT', '${_lightLevel.toStringAsFixed(1)} lux'),
              ('PROX', _proximity < 0 ? 'N/A' : '${_proximity.toStringAsFixed(1)} cm'),
              ('PRESS', '${_pressure.toStringAsFixed(1)} hPa'),
            ]),
            const SizedBox(height: 12),
            _buildAccelBar(),
            const SizedBox(height: 12),
            if (_sensorList.isNotEmpty) _buildSensorInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompass() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FlipNovaTheme.bgCard,
        border: Border.all(color: FlipNovaTheme.border, width: 2.0),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: _compassHeading * pi / 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation, color: FlipNovaTheme.red, size: 40),
                Container(width: 2, height: 40, color: FlipNovaTheme.green),
              ],
            ),
          ),
          Text('N', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.red, fontSize: 16, weight: FontWeight.bold,
          )),
          Positioned(
            top: 8,
            child: Text('${_compassHeading.toStringAsFixed(0)}°', style: FlipNovaTheme.mono(
              color: FlipNovaTheme.green, fontSize: 14, weight: FontWeight.bold,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(String title, List<(String, String)> values) {
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
          Text(title, style: FlipNovaTheme.mono(
            color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
          )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: values.map((v) => Column(
              children: [
                Text(v.$1, style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.gray, fontSize: 10,
                )),
                const SizedBox(height: 4),
                Text(v.$2, style: FlipNovaTheme.mono(
                  color: FlipNovaTheme.white, fontSize: 14, weight: FontWeight.bold,
                )),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccelBar() {
    final maxVal = max(_accelX.abs(), max(_accelY.abs(), _accelZ.abs()));
    final scale = maxVal > 0 ? 1.0 / maxVal : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(color: FlipNovaTheme.green, width: FlipNovaTheme.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACCEL VISUAL', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
          )),
          const SizedBox(height: 8),
          _buildBar('X', _accelX, scale, FlipNovaTheme.green),
          const SizedBox(height: 4),
          _buildBar('Y', _accelY, scale, FlipNovaTheme.green.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          _buildBar('Z', _accelZ, scale, FlipNovaTheme.green.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double value, double scale, Color color) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(label, style: FlipNovaTheme.mono(
          color: FlipNovaTheme.green, fontSize: 10, weight: FontWeight.bold,
        ))),
        Expanded(
          child: LinearProgressIndicator(
            value: (value.abs() * scale).clamp(0.0, 1.0),
            backgroundColor: FlipNovaTheme.bgPrimary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 12,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(value.toStringAsFixed(1), style: FlipNovaTheme.mono(
            color: FlipNovaTheme.white, fontSize: 11,
          ), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildSensorInfo() {
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
          Text('DEVICE SENSORS:', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
          )),
          const SizedBox(height: 8),
          ..._sensorList.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '> ${s['name']} (${s['type']})',
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.gray, fontSize: 10,
              ),
            ),
          )),
        ],
      ),
    );
  }

  double _magnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  String _getDirection(double heading) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((heading + 22.5) / 45).floor() % 8];
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
