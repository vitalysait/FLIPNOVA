import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({super.key});

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  static const _eventChannel = EventChannel('com.flipnova/plugins/events');

  // Event streaming state placeholder (not used yet)
  StreamSubscription? _eventSub;
  final List<String> _plugins = [];

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        (dynamic data) {
          if (mounted) setState(() {});
        },
        onError: (_) {
          if (mounted) setState(() {});
        },
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '[ PLUGINS ]',
          style: FlipNovaTheme.mono(
            color: FlipNovaTheme.green,
            fontSize: 14,
            weight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _pickPlugin,
            icon: const Icon(Icons.add),
            tooltip: 'Add plugin',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plugins manager',
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green,
                fontSize: 18,
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your own plugins in JavaScript or Python. Press + to pick a plugin file (zip, js, py).',
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.white,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _buildPluginsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPluginsList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(
          color: FlipNovaTheme.border,
          width: FlipNovaTheme.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSTALLED PLUGINS:',
            style: FlipNovaTheme.mono(
              color: FlipNovaTheme.green,
              fontSize: 12,
              weight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_plugins.isEmpty)
            Text(
              'No plugins installed',
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.gray,
                fontSize: 11,
              ),
            ),
          ..._plugins.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p,
                      style: FlipNovaTheme.mono(
                        color: FlipNovaTheme.white,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: load or remove plugin
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Plugin selected: $p')),
                      );
                    },
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPlugin() async {
    try {
      final typeGroup = XTypeGroup(
        label: 'plugins',
        extensions: ['js', 'py', 'zip'],
      );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      final path = file.path;
      if (path.isEmpty) return;

      setState(() {
        _plugins.add(path);
      });

      final name = path.split(Platform.pathSeparator).last;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plugin added: $name')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick plugin: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
