import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class CryptoScreen extends StatefulWidget {
  const CryptoScreen({super.key});

  @override
  State<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends State<CryptoScreen> {
  final _inputController = TextEditingController();
  final _aesKeyController = TextEditingController(text: '0123456789abcdef');
  final _aesIvController = TextEditingController(text: '0123456789abcdef');
  int _selectedTab = 0;

  String _md5Result = '';
  String _sha1Result = '';
  String _sha256Result = '';
  String _sha512Result = '';
  String _base64EncodeResult = '';
  String _hexEncodeResult = '';
  String _base64DecodeResult = '';
  String _hexDecodeResult = '';
  String _aesEncryptResult = '';
  String _aesDecryptResult = '';
  String _xorResult = '';
  String _xorKey = 'FF';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('[ CRYPTO ]')),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: ElevatedButton(
            onPressed: () => setState(() => _selectedTab = 0),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedTab == 0 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: _selectedTab == 0 ? FlipNovaTheme.white : FlipNovaTheme.green,
            ),
            child: Text('[ HASH ]'),
          )),
          SizedBox(width: 6),
          Expanded(child: ElevatedButton(
            onPressed: () => setState(() => _selectedTab = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedTab == 1 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: _selectedTab == 1 ? FlipNovaTheme.white : FlipNovaTheme.green,
            ),
            child: Text('[ ENCODE ]'),
          )),
          SizedBox(width: 6),
          Expanded(child: ElevatedButton(
            onPressed: () => setState(() => _selectedTab = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedTab == 2 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: _selectedTab == 2 ? FlipNovaTheme.white : FlipNovaTheme.green,
            ),
            child: Text('[ DECODE ]'),
          )),
          SizedBox(width: 6),
          Expanded(child: ElevatedButton(
            onPressed: () => setState(() => _selectedTab = 3),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedTab == 3 ? FlipNovaTheme.green : FlipNovaTheme.bgCard,
              foregroundColor: _selectedTab == 3 ? FlipNovaTheme.white : FlipNovaTheme.green,
            ),
            child: Text('[ AES ]'),
          )),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0: return _buildHashTab();
      case 1: return _buildEncodeTab();
      case 2: return _buildDecodeTab();
      case 3: return _buildAesTab();
      default: return _buildHashTab();
    }
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INPUT:', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
          )),
          SizedBox(height: 8),
          TextField(
            controller: _inputController,
            style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 12),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter text to process...',
              isDense: true,
            ),
            onChanged: (_) => _processInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(String title, List<(String, String)> items) {
    return Container(
      padding: EdgeInsets.all(12),
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
          SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: SelectableText(
              '${item.$1}: ${item.$2.isEmpty ? "---" : item.$2}',
              style: FlipNovaTheme.mono(
                color: FlipNovaTheme.white, fontSize: 10,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildHashTab() {
    return Column(
      children: [
        _buildInputSection(),
        SizedBox(height: 12),
        _buildResultCard('HASH', [
          ('MD5', _md5Result),
          ('SHA1', _sha1Result),
          ('SHA256', _sha256Result),
          ('SHA512', _sha512Result),
        ]),
        SizedBox(height: 12),
        _buildXorSection(),
        SizedBox(height: 12),
        _buildPasswordGenerator(),
      ],
    );
  }

  Widget _buildEncodeTab() {
    return Column(
      children: [
        _buildInputSection(),
        SizedBox(height: 12),
        _buildResultCard('ENCODE', [
          ('Base64', _base64EncodeResult),
          ('Hex', _hexEncodeResult),
        ]),
      ],
    );
  }

  Widget _buildDecodeTab() {
    return Column(
      children: [
        _buildInputSection(),
        SizedBox(height: 12),
        _buildResultCard('DECODE', [
          ('Base64', _base64DecodeResult),
          ('Hex', _hexDecodeResult),
        ]),
      ],
    );
  }

  Widget _buildAesTab() {
    return Column(
      children: [
        _buildInputSection(),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlipNovaTheme.bgCard,
            borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
            border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AES-128-CBC', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
              )),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('KEY: ', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.gray, fontSize: 11,
                  )),
                  Expanded(
                    child: TextField(
                      controller: _aesKeyController,
                      style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: '16 char key',
                        isDense: true,
                        contentPadding: EdgeInsets.all(6),
                      ),
                      onChanged: (_) => _processInput(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text('IV:  ', style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.gray, fontSize: 11,
                  )),
                  Expanded(
                    child: TextField(
                      controller: _aesIvController,
                      style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: '16 char IV',
                        isDense: true,
                        contentPadding: EdgeInsets.all(6),
                      ),
                      onChanged: (_) => _processInput(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _aesEncrypt,
                      child: Text('[ ENCRYPT ]'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _aesDecrypt,
                      child: Text('[ DECRYPT ]'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _buildResultCard('AES RESULT', [
          ('Encrypted', _aesEncryptResult),
          ('Decrypted', _aesDecryptResult),
        ]),
      ],
    );
  }

  Widget _buildXorSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('XOR', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
          )),
          SizedBox(height: 8),
          Row(
            children: [
              Text('KEY: ', style: FlipNovaTheme.mono(
                color: FlipNovaTheme.gray, fontSize: 11,
              )),
              SizedBox(
                width: 80,
                child: TextField(
                  style: FlipNovaTheme.mono(color: FlipNovaTheme.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'FF',
                    isDense: true,
                    contentPadding: EdgeInsets.all(6),
                  ),
                  onChanged: (v) {
                    _xorKey = v;
                    _processInput();
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  _xorResult.isEmpty ? '---' : _xorResult,
                  style: FlipNovaTheme.mono(
                    color: FlipNovaTheme.white, fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordGenerator() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlipNovaTheme.bgCard,
        borderRadius: BorderRadius.circular(FlipNovaTheme.borderRadius),
        border: Border.all(color: FlipNovaTheme.border, width: FlipNovaTheme.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PASSWORD GEN', style: FlipNovaTheme.mono(
            color: FlipNovaTheme.green, fontSize: 12, weight: FontWeight.bold,
          )),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _generatePassword(16),
                  child: Text('[ 16 CHARS ]'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _generatePassword(32),
                  child: Text('[ 32 CHARS ]'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _generatePassword(64),
                  child: Text('[ 64 CHARS ]'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _processInput() {
    final input = _inputController.text;
    if (input.isEmpty) {
      setState(() {
        _md5Result = '';
        _sha1Result = '';
        _sha256Result = '';
        _sha512Result = '';
        _base64EncodeResult = '';
        _hexEncodeResult = '';
        _base64DecodeResult = '';
        _hexDecodeResult = '';
        _xorResult = '';
      });
      return;
    }

    final bytes = utf8.encode(input);
    final xorKeyBytes = _parseHex(_xorKey);

    setState(() {
      _md5Result = crypto.md5.convert(bytes).toString();
      _sha1Result = crypto.sha1.convert(bytes).toString();
      _sha256Result = crypto.sha256.convert(bytes).toString();
      _sha512Result = crypto.sha512.convert(bytes).toString();
      _base64EncodeResult = base64.encode(bytes);
      _hexEncodeResult = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

      try {
        _base64DecodeResult = utf8.decode(base64.decode(input));
      } catch (_) {
        _base64DecodeResult = '(invalid base64)';
      }

      try {
        final hexBytes = _parseHex(input);
        _hexDecodeResult = utf8.decode(hexBytes);
      } catch (_) {
        _hexDecodeResult = '(invalid hex)';
      }

      if (xorKeyBytes.isNotEmpty) {
        final xorResult = [for (var i = 0; i < bytes.length; i++) bytes[i] ^ xorKeyBytes[i % xorKeyBytes.length]];
        _xorResult = xorResult.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      }
    });
  }

  void _aesEncrypt() {
    final input = _inputController.text;
    if (input.isEmpty) return;

    final keyBytes = utf8.encode(_aesKeyController.text.padRight(16, '0').substring(0, 16));
    final ivBytes = utf8.encode(_aesIvController.text.padRight(16, '0').substring(0, 16));
    final plainBytes = utf8.encode(input);

    try {
      final cipher = pc.CBCBlockCipher(pc.AESEngine());
      final params = pc.ParametersWithIV(pc.KeyParameter(keyBytes), ivBytes);
      cipher.init(true, params);

      final paddedInput = Uint8List.fromList(_pkcs7Pad(plainBytes, 16));
      final output = Uint8List(paddedInput.length);

      for (var i = 0; i < paddedInput.length; i += 16) {
        cipher.processBlock(paddedInput, i, output, i);
      }

      setState(() {
        _aesEncryptResult = base64.encode(output);
      });
    } catch (e) {
      setState(() => _aesEncryptResult = 'ERROR: $e');
    }
  }

  void _aesDecrypt() {
    final input = _inputController.text;
    if (input.isEmpty) return;

    final keyBytes = utf8.encode(_aesKeyController.text.padRight(16, '0').substring(0, 16));
    final ivBytes = utf8.encode(_aesIvController.text.padRight(16, '0').substring(0, 16));

    try {
      final cipherBytes = base64.decode(input);
      final cipher = pc.CBCBlockCipher(pc.AESEngine());
      final params = pc.ParametersWithIV(pc.KeyParameter(keyBytes), ivBytes);
      cipher.init(false, params);

      final output = Uint8List(cipherBytes.length);
      for (var i = 0; i < cipherBytes.length; i += 16) {
        cipher.processBlock(cipherBytes, i, output, i);
      }

      final unpadded = _pkcs7Unpad(output);
      setState(() {
        _aesDecryptResult = utf8.decode(unpadded);
      });
    } catch (e) {
      setState(() => _aesDecryptResult = 'ERROR: $e');
    }
  }

  List<int> _pkcs7Pad(List<int> data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    return [...data, ...List.filled(padLen, padLen)];
  }

  List<int> _pkcs7Unpad(List<int> data) {
    if (data.isEmpty) return data;
    final padLen = data.last;
    if (padLen < 1 || padLen > 16) return data;
    return data.sublist(0, data.length - padLen);
  }

  List<int> _parseHex(String hex) {
    try {
      final cleanHex = hex.replaceAll(RegExp(r'\s+'), '');
      final result = <int>[];
      for (var i = 0; i < cleanHex.length; i += 2) {
        result.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  void _generatePassword(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_+-=[]{}|;:,.<>?';
    final rng = Random.secure();
    final password = String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );
    _inputController.text = password;
    _processInput();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _aesKeyController.dispose();
    _aesIvController.dispose();
    super.dispose();
  }
}
