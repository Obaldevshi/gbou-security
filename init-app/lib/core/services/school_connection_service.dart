import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_template/core/services/session_service.dart';

/// A connection is selected explicitly. There is no cloud fallback on failure.
class SchoolConnection {
  const SchoolConnection({required this.apiBaseUrl, this.caPem});

  final String apiBaseUrl;
  final String? caPem;

  static SchoolConnection parse(String address, {String? caPem}) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !const ['', '/', '/api/v1', '/api/v1/'].contains(uri.path)) {
      throw const FormatException(
        'Укажите HTTPS-адрес школьного сервера без дополнительных путей.',
      );
    }
    final pem = caPem?.trim();
    if (pem != null && pem.isNotEmpty) {
      certificateFingerprint(pem); // Validate exactly one public certificate.
    }
    return SchoolConnection(
      apiBaseUrl: '${uri.origin}/api/v1',
      caPem: pem == null || pem.isEmpty ? null : pem,
    );
  }

  static String certificateFingerprint(String pem) {
    final match = RegExp(
      r'^\s*-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+/=\s]+)\s*-----END CERTIFICATE-----\s*$',
    ).firstMatch(pem);
    if (match == null || pem.length > 32768) {
      throw const FormatException(
        'Нужен один публичный сертификат школы в формате PEM, без закрытого ключа.',
      );
    }
    final der = base64Decode(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
    if (der.length < 64 || der.first != 0x30) {
      throw const FormatException('Некорректный сертификат школы.');
    }
    return sha256.convert(der).toString().toUpperCase();
  }

  String get scope =>
      '$apiBaseUrl|${caPem == null ? 'system' : certificateFingerprint(caPem!)}';

  Map<String, dynamic> toJson() => {'url': apiBaseUrl, 'ca_pem': caPem};
}

class SchoolConnectionService extends ChangeNotifier {
  SchoolConnectionService._(
    this._storage,
    this._session,
    this.defaultBaseUrl,
    this._connection,
    this.supportsDiscovery,
  );

  static const _connectionKey = 'school_connection_v1';
  static const _scopeKey = 'school_session_scope_v1';
  final FlutterSecureStorage _storage;
  final SessionService _session;
  final String defaultBaseUrl;
  SchoolConnection _connection;
  bool _changing = false;
  int _revision = 0;
  final bool supportsDiscovery;
  bool _automaticDiscovery = true;
  String? _confirmedLoginDigest;
  int? _confirmedSchoolId;
  bool get automaticDiscovery => _automaticDiscovery;
  String? get confirmedLoginDigest => _confirmedLoginDigest;
  int? get confirmedSchoolId => _confirmedSchoolId;

  SchoolConnection get connection => _connection;
  bool get isLocal => _connection.apiBaseUrl != defaultBaseUrl;
  bool get isChanging => _changing;
  int get revision => _revision;

  static Future<SchoolConnectionService> create({
    required FlutterSecureStorage storage,
    required SessionService session,
    required String defaultBaseUrl,
    bool? enableDiscovery,
  }) async {
    final supportsDiscovery = enableDiscovery ?? !kIsWeb;
    var automatic = true;
    String? confirmedDigest;
    int? confirmedSchool;
    var connection = kIsWeb
        ? SchoolConnection(apiBaseUrl: defaultBaseUrl)
        : SchoolConnection.parse(defaultBaseUrl);
    if (!kIsWeb || supportsDiscovery) {
      final saved = await storage.read(key: _connectionKey);
      if (saved != null) {
        try {
          final data = jsonDecode(saved) as Map<String, dynamic>;
          connection = SchoolConnection.parse(
            data['url'] as String,
            caPem: data['ca_pem'] as String?,
          );
          automatic = data['automatic'] == true;
          confirmedDigest = data['login_digest'] as String?;
          confirmedSchool = data['school_id'] as int?;
          if (confirmedDigest == null ||
              !RegExp(r'^[a-f0-9]{64}$').hasMatch(confirmedDigest) ||
              confirmedSchool == null ||
              confirmedSchool <= 0) {
            confirmedDigest = null;
            confirmedSchool = null;
          }
        } catch (_) {
          // Do not silently route a formerly local session back to the cloud.
          await session.clearSession();
          await storage.delete(key: _connectionKey);
        }
      }
      final scope = await storage.read(key: _scopeKey);
      if (scope != connection.scope && (scope != null || saved != null)) {
        await session.clearSession();
      }
      await storage.write(key: _scopeKey, value: connection.scope);
    }
    return SchoolConnectionService._(
        storage,
        session,
        defaultBaseUrl,
        connection,
        supportsDiscovery,
      )
      .._automaticDiscovery = automatic
      .._confirmedLoginDigest = confirmedDigest
      .._confirmedSchoolId = confirmedSchool;
  }

  Future<void> select(
    SchoolConnection connection, {
    bool discovered = false,
    String? loginDigest,
    int? schoolId,
  }) async {
    if (kIsWeb && !supportsDiscovery) {
      throw StateError('Web использует адрес текущего сайта.');
    }
    if (_changing) throw StateError('Настройка подключения уже выполняется.');
    final scopeChanged = _connection.scope != connection.scope;
    _changing = true;
    _revision++;
    notifyListeners();
    try {
      if (scopeChanged) await _session.clearSession();
      await _storage.write(
        key: _connectionKey,
        value: jsonEncode({
          ...connection.toJson(),
          'automatic': discovered,
          'login_digest': loginDigest,
          'school_id': schoolId,
        }),
      );
      await _storage.write(key: _scopeKey, value: connection.scope);
      _connection = connection;
      _automaticDiscovery = discovered;
      _confirmedLoginDigest = loginDigest;
      _confirmedSchoolId = schoolId;
    } finally {
      _changing = false;
      notifyListeners();
    }
  }

  Future<void> rememberDiscovered(
    SchoolConnection connection,
    String digest,
    int schoolId,
  ) => select(
    connection,
    discovered: true,
    loginDigest: digest,
    schoolId: schoolId,
  );

  Future<void> enableAutomaticDiscovery() async {
    if (!supportsDiscovery) return;
    await select(
      _connection,
      discovered: true,
      loginDigest: _confirmedLoginDigest,
      schoolId: _confirmedSchoolId,
    );
  }
}
