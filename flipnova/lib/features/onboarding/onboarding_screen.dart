import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _ru = true;

  List<_OnbPage> get _pages => _ru ? _pagesRu : _pagesEn;

  static const _pagesRu = [
    _OnbPage(
      icon: Icons.bolt,
      iconColor: FlipNovaTheme.cyan,
      title: 'Добро пожаловать',
      lines: [
        '> FLIPNOVA — мультитул',
        '  для энтузиастов',
        '',
        '> Анализ, тестирование',
        '  и исследование устройств',
      ],
    ),
    _OnbPage(
      icon: Icons.nfc,
      iconColor: FlipNovaTheme.cyan,
      title: 'NFC',
      lines: [
        '> Чтение и запись NFC-меток',
        '> Эмуляция карт (MIFARE, NTAG)',
        '> Анализ бесконтактных систем',
      ],
    ),
    _OnbPage(
      icon: Icons.wifi_find,
      iconColor: FlipNovaTheme.cyan,
      title: 'Wi-Fi / Сеть',
      lines: [
        '> Сканирование Wi-Fi сетей',
        '> Ping, DNS-запросы, порты',
        '> Информация о подключении',
      ],
    ),
    _OnbPage(
      icon: Icons.bluetooth_searching,
      iconColor: FlipNovaTheme.cyan,
      title: 'BLE',
      lines: [
        '> Сканирование BLE-устройств',
        '> Подключение и обмен данными',
        '> Jamming / analysis (Beta)',
      ],
    ),
    _OnbPage(
      icon: Icons.waves,
      iconColor: FlipNovaTheme.orange,
      title: 'ИК-Пульт',
      lines: [
        '> Отправка ИК-команд',
        '> Обучение пультов',
        '> Библиотека ИК-кодов (Beta)',
      ],
    ),
    _OnbPage(
      icon: Icons.pets,
      iconColor: FlipNovaTheme.cyan,
      title: 'Chameleon Ultra',
      lines: [
        '> Эмуляция NFC через BLE',
        '> 8 слотов для карт',
        '> Чтение / запись / эмуляция (Beta)',
      ],
    ),
    _OnbPage(
      icon: Icons.cast,
      iconColor: FlipNovaTheme.yellow,
      title: 'Cast / QR / Плагины',
      lines: [
        '> Трансляция экрана на ТВ',
        '> Сканирование и генерация QR',
        '> Расширение функционала',
      ],
    ),
  ];

  static const _pagesEn = [
    _OnbPage(
      icon: Icons.bolt,
      iconColor: FlipNovaTheme.cyan,
      title: 'Welcome',
      lines: [
        '> FLIPNOVA — a multitool',
        '  for enthusiasts',
        '',
        '> Analyze, test, and',
        '  explore devices',
      ],
    ),
    _OnbPage(
      icon: Icons.nfc,
      iconColor: FlipNovaTheme.cyan,
      title: 'NFC',
      lines: [
        '> Read and write NFC tags',
        '> Emulate cards (MIFARE, NTAG)',
        '> Analyze contactless systems',
      ],
    ),
    _OnbPage(
      icon: Icons.wifi_find,
      iconColor: FlipNovaTheme.cyan,
      title: 'Wi-Fi / Network',
      lines: [
        '> Scan Wi-Fi networks',
        '> Ping, DNS lookups, ports',
        '> Connection info',
      ],
    ),
    _OnbPage(
      icon: Icons.bluetooth_searching,
      iconColor: FlipNovaTheme.cyan,
      title: 'BLE',
      lines: [
        '> Scan BLE devices',
        '> Connect and exchange data',
        '> Jamming / analysis (Beta)',
      ],
    ),
    _OnbPage(
      icon: Icons.waves,
      iconColor: FlipNovaTheme.orange,
      title: 'IR Remote',
      lines: [
        '> Send IR commands',
        '> Learn from remotes',
        '> IR code library (Beta)',
      ],
    ),
    _OnbPage(
      icon: Icons.pets,
      iconColor: FlipNovaTheme.cyan,
      title: 'Chameleon Ultra',
      lines: [
        '> NFC emulation via BLE',
        '> 8 card slots',
        '> Read / write / emulate (Beta)',
      ],
    ),
    _OnbPage(
      icon: Icons.cast,
      iconColor: FlipNovaTheme.yellow,
      title: 'Cast / QR / Plugins',
      lines: [
        '> Cast screen to TV',
        '> Scan and generate QR codes',
        '> Extend functionality',
      ],
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunched', true);
    await prefs.setBool('isRu', _ru);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: FlipNovaTheme.bgPrimary,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Text('FLIPNOVA', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.cyan, fontSize: 10, weight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _ru = !_ru;
                  _page = _page.clamp(0, _pages.length - 1);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: FlipNovaTheme.bgCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FlipNovaTheme.cyan, width: FlipNovaTheme.borderWidth),
                  ),
                  child: Text(_ru ? 'EN' : 'RU', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.cyan, fontSize: 11, weight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _buildPage(_pages[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              ...List.generate(_pages.length, (i) => Container(
                width: i == _page ? 24 : 8,
                height: 3,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i == _page ? FlipNovaTheme.cyan : FlipNovaTheme.gray,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const Spacer(),
              ElevatedButton(
                onPressed: isLast ? _finish : () {
                  _controller.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLast ? FlipNovaTheme.cyan : FlipNovaTheme.bgCard,
                  foregroundColor: isLast ? FlipNovaTheme.bgPrimary : FlipNovaTheme.cyan,
                  side: const BorderSide(color: FlipNovaTheme.cyan, width: FlipNovaTheme.borderWidth),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: Text(isLast
                    ? (_ru ? '[ НАЧАТЬ ]' : '[ START ]')
                    : (_ru ? '[ ДАЛЕЕ ]' : '[ NEXT ]'),
                  style: FlipNovaTheme.mono(fontSize: 12, weight: FontWeight.bold)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildPage(_OnbPage page) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlipNovaTheme.bgCard,
              borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
              border: Border.all(color: page.iconColor, width: FlipNovaTheme.borderWidth),
            ),
            child: Icon(page.icon, color: page.iconColor, size: 48),
          ),
          const SizedBox(height: 24),
          Text(page.title.toUpperCase(), style: FlipNovaTheme.mono(
            color: FlipNovaTheme.white, fontSize: 20, weight: FontWeight.bold,
          )),
          const SizedBox(height: 16),
          ...page.lines.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l, style: FlipNovaTheme.mono(
              color: l.startsWith('>') ? FlipNovaTheme.cyan : FlipNovaTheme.gray,
              fontSize: 13,
            )),
          )),
          const SizedBox(height: 16),
          Text('${_page + 1} / ${_pages.length}', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.gray, fontSize: 10,
          )),
        ],
      ),
    );
  }
}

class _OnbPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> lines;

  const _OnbPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.lines,
  });
}
