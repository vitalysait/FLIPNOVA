import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dart_ping/dart_ping.dart';
import '../../core/theme.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final _hostController = TextEditingController(text: '8.8.8.8');
  final _portStartController = TextEditingController(text: '1');
  final _portEndController = TextEditingController(text: '1024');
  final List<String> _results = [];
  bool _isRunning = false;
  int _selectedTab = 0;
  String _dnsInput = 'google.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[ NETWORK ]')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTabBar(),
            const SizedBox(height: 12),
            Expanded(child: _buildTabContent()),
          ],
        ),
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
          child: const Text('[ PING ]'),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: () => setState(() => _selectedTab = 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedTab == 1 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
            foregroundColor: _selectedTab == 1 ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
          ),
          child: const Text('[ PORTS ]'),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: () => setState(() => _selectedTab = 2),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedTab == 2 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
            foregroundColor: _selectedTab == 2 ? FlipNovaTheme.bgCard : FlipNovaTheme.green,
          ),
          child: const Text('[ DNS ]'),
        )),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0: return _buildPingTab();
      case 1: return _buildPortScanTab();
      case 2: return _buildDnsTab();
      default: return _buildPingTab();
    }
  }

  Widget _buildPingTab() {
    return Column(
      children: [
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
              Text('PING', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostController,
                      style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Host / IP',
                        isDense: true,
                        contentPadding: EdgeInsets.all(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isRunning ? null : _runPing,
                    child: const Text('[ PING ]'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildPortScanTab() {
    return Column(
      children: [
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
              Text('PORT SCAN', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostController,
                      style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Target',
                        isDense: true,
                        contentPadding: EdgeInsets.all(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _portStartController,
                      keyboardType: TextInputType.number,
                      style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'From',
                        isDense: true,
                        contentPadding: EdgeInsets.all(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _portEndController,
                      keyboardType: TextInputType.number,
                      style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'To',
                        isDense: true,
                        contentPadding: EdgeInsets.all(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isRunning ? null : _runPortScan,
                    child: const Text('[ SCAN ]'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_isRunning) ...[
          LinearProgressIndicator(
            backgroundColor: FlipNovaTheme.bgCard,
            valueColor: AlwaysStoppedAnimation<Color>(FlipNovaTheme.green),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildDnsTab() {
    return Column(
      children: [
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
              Text('DNS LOOKUP', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: _dnsInput),
                      style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Domain name',
                        isDense: true,
                        contentPadding: EdgeInsets.all(8),
                      ),
                      onChanged: (v) => _dnsInput = v,
                      onSubmitted: (_) => _runDnsLookup(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isRunning ? null : _runDnsLookup,
                    child: const Text('[ LOOKUP ]'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('OUTPUT:', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
              )),
              if (_results.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _results.clear()),
                  child: Text('[ CLEAR ]', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.gray, fontSize: 10,
                  )),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _results.isEmpty ? '> Ready...' : _results.join('\n'),
                style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runPing() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _isRunning = true;
      _results.clear();
      _results.add('> Pinging $host...');
    });

    try {
      final ping = Ping(host, count: 5);
      await for (final event in ping.stream) {
        if (!mounted) break;
        if (event is PingResponse) {
          final time = event.time?.inMilliseconds ?? 0;
          final ttl = event.ttl ?? 0;
          setState(() {
            _results.add('> 64 bytes: time=${time}ms TTL=$ttl');
          });
        } else if (event is PingSummary) {
          setState(() {
            _results.add('> ${event.transmitted} transmitted, ${event.received} received, ${event.packetLoss.toStringAsFixed(0)}% loss');
            if (event.stats != null) {
              _results.add('> avg: ${event.stats!.avg?.inMilliseconds ?? 0}ms');
            }
          });
        } else if (event is PingError) {
          setState(() {
            _results.add('> ERROR: ${event.error.toString()}');
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _results.add('> ERROR: $e');
      });
    }

    if (mounted) setState(() => _isRunning = false);
  }

  Future<void> _runPortScan() async {
    final host = _hostController.text.trim();
    final startPort = int.tryParse(_portStartController.text) ?? 1;
    final endPort = int.tryParse(_portEndController.text) ?? 1024;
    if (host.isEmpty) return;

    setState(() {
      _isRunning = true;
      _results.clear();
      _results.add('> Scanning $host ports $startPort-$endPort...');
      _results.add('> PORT      STATE    SERVICE');
    });

    final commonServices = {
      21: 'ftp', 22: 'ssh', 23: 'telnet', 25: 'smtp', 53: 'dns',
      80: 'http', 110: 'pop3', 143: 'imap', 443: 'https', 993: 'imaps',
      995: 'pop3s', 3306: 'mysql', 3389: 'rdp', 5432: 'postgresql',
      8080: 'http-alt', 8443: 'https-alt', 6379: 'redis', 27017: 'mongodb',
    };

    int openCount = 0;
    final total = endPort - startPort + 1;
    const batchSize = 100;

    for (var batchStart = startPort; batchStart <= endPort; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize - 1).clamp(startPort, endPort);
      final futures = <Future<void>>[];

      for (var port = batchStart; port <= batchEnd; port++) {
        futures.add(_checkPort(host, port).then((isOpen) {
          if (isOpen) {
            openCount++;
            final service = commonServices[port] ?? 'unknown';
            setState(() {
              _results.add('> ${port.toString().padRight(9)}open     $service');
            });
          }
        }));
      }

      await Future.wait(futures);
      if (!mounted) return;

      final scanned = (batchEnd - startPort + 1);
      setState(() {
        if (_results.length > 2) {
          _results[0] = '> Scanning... ($scanned/$total)';
        }
      });
    }

    setState(() {
      _results[0] = '> Scan complete: $openCount open ports found in $total scanned';
      _isRunning = false;
    });
  }

  Future<bool> _checkPort(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 500));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _runDnsLookup() async {
    final domain = _dnsInput.trim();
    if (domain.isEmpty) return;

    setState(() {
      _isRunning = true;
      _results.clear();
      _results.add('> DNS Lookup: $domain');
      _results.add('> ---');
    });

    try {
      final addresses = await InternetAddress.lookup(domain);
      setState(() {
        for (final addr in addresses) {
          _results.add('> ${addr.type.name}: ${addr.address}');
        }
        _results.add('> ---');
        _results.add('> ${addresses.length} record(s) found');
      });
    } on SocketException catch (e) {
      if (mounted) setState(() {
        _results.add('> ERROR: ${e.message}');
      });
    } catch (e) {
      if (mounted) setState(() {
        _results.add('> ERROR: $e');
      });
    }

    if (mounted) setState(() => _isRunning = false);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portStartController.dispose();
    _portEndController.dispose();
    super.dispose();
  }
}
