import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SessionStatus {
  bootstrapping,
  locked,
  unauthenticated,
  authenticated,
  temporarilyUnavailable,
}

enum PinVerificationResult { success, invalid, lockedOut, unavailable }

@lazySingleton
class SessionService extends ChangeNotifier {
  static const String _accessTokenKey = 'access_token';
  static const String _tokenTypeKey = 'token_type';
  static const String _expiresInKey = 'expires_in';
  static const String _loginTimeKey = 'login_time';
  static const String _refreshTokenKey = 'trusted_refresh_token';
  static const String _trustedDeviceIdKey = 'trusted_device_id';
  static const String _pinSaltKey = 'pin_salt';
  static const String _pinHashKey = 'pin_hash';
  static const String _pinAttemptsKey = 'pin_attempts';
  static const String _pinOfferDismissedKey = 'pin_offer_dismissed';
  static const int maxPinAttempts = 5;

  SessionService._(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  String? _accessToken;
  String? _tokenType;
  int? _expiresIn;
  int? _loginTime;
  String? _refreshToken;
  int? _trustedDeviceId;
  String? _pinSalt;
  String? _pinHash;
  int _pinAttempts = 0;
  bool _pinOfferDismissed = false;
  CurrentUser? _currentUser;
  SessionStatus _status = SessionStatus.bootstrapping;

  @factoryMethod
  @preResolve
  static Future<SessionService> create(
    FlutterSecureStorage secureStorage,
    SharedPreferences prefs,
  ) async {
    final service = SessionService._(secureStorage);
    await service._loadFromStorage();
    await service._migrateFromSharedPreferences(prefs);
    if (service.hasPinConfigured && service.hasTrustedSession) {
      service._status = SessionStatus.locked;
    } else if (!service.hasRestorableToken) {
      service._resetAccessSession();
      await service._deleteAccessSession();
      if (service.hasPinConfigured || service.hasTrustedSession) {
        await service._deleteTrustedSession();
        service._resetTrustedSession();
      }
      service._status = SessionStatus.unauthenticated;
    }
    return service;
  }

  Future<void> _loadFromStorage() async {
    try {
      _accessToken = await _secureStorage.read(key: _accessTokenKey);
      _tokenType = await _secureStorage.read(key: _tokenTypeKey);
      _expiresIn = int.tryParse(
        await _secureStorage.read(key: _expiresInKey) ?? '',
      );
      _loginTime = int.tryParse(
        await _secureStorage.read(key: _loginTimeKey) ?? '',
      );
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      _trustedDeviceId = int.tryParse(
        await _secureStorage.read(key: _trustedDeviceIdKey) ?? '',
      );
      _pinSalt = await _secureStorage.read(key: _pinSaltKey);
      _pinHash = await _secureStorage.read(key: _pinHashKey);
      _pinAttempts = int.tryParse(
            await _secureStorage.read(key: _pinAttemptsKey) ?? '',
          ) ??
          0;
      _pinOfferDismissed =
          await _secureStorage.read(key: _pinOfferDismissedKey) == 'true';
    } catch (error, stackTrace) {
      // WebCrypto throws OperationError when legacy values were encrypted by
      // different keys. Treat an unreadable token as an expired session.
      debugPrint('Failed to restore secure session: $error');
      debugPrintStack(stackTrace: stackTrace);
      _resetAccessSession();
      _resetTrustedSession();

      try {
        await _deleteAccessSession();
        await _deleteTrustedSession();
      } catch (deleteError) {
        debugPrint('Failed to remove unreadable secure session: $deleteError');
      }
    }
  }

  Future<void> _migrateFromSharedPreferences(SharedPreferences prefs) async {
    final legacyToken = prefs.getString(_accessTokenKey);
    if (legacyToken == null || legacyToken.isEmpty) return;

    final tokenType = prefs.getString(_tokenTypeKey);
    final expiresIn = prefs.getInt(_expiresInKey);
    final loginTime = prefs.getInt(_loginTimeKey);

    if (tokenType != null && expiresIn != null && loginTime != null) {
      await saveToken(
        accessToken: legacyToken,
        tokenType: tokenType,
        expiresIn: expiresIn,
        loginTime: loginTime,
      );
    }

    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_tokenTypeKey),
      prefs.remove(_expiresInKey),
      prefs.remove(_loginTimeKey),
    ]);
  }

  Future<void> saveToken({
    required String accessToken,
    required String tokenType,
    required int expiresIn,
    int? loginTime,
  }) async {
    await _persistToken(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
      loginTime: loginTime,
    );
    notifyListeners();
  }

  Future<void> _persistToken({
    required String accessToken,
    required String tokenType,
    required int expiresIn,
    int? loginTime,
  }) async {
    final resolvedLoginTime =
        loginTime ?? DateTime.now().millisecondsSinceEpoch;

    // Keep writes sequential. On web the first write creates the WebCrypto
    // key; parallel writes can race and encrypt values with different keys.
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _tokenTypeKey, value: tokenType);
    await _secureStorage.write(key: _expiresInKey, value: expiresIn.toString());
    await _secureStorage.write(
      key: _loginTimeKey,
      value: resolvedLoginTime.toString(),
    );

    _accessToken = accessToken;
    _tokenType = tokenType;
    _expiresIn = expiresIn;
    _loginTime = resolvedLoginTime;
  }

  Future<void> establishSession(AuthSession session) async {
    await _persistToken(
      accessToken: session.accessToken,
      tokenType: session.tokenType,
      expiresIn: session.expiresIn,
    );
    _currentUser = session.user;
    _status = SessionStatus.authenticated;
    notifyListeners();
  }

  Future<void> establishTrustedSession({
    required AuthSession session,
    required String refreshToken,
    required int trustedDeviceId,
  }) async {
    await _persistToken(
      accessToken: session.accessToken,
      tokenType: session.tokenType,
      expiresIn: session.expiresIn,
    );
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.write(
      key: _trustedDeviceIdKey,
      value: trustedDeviceId.toString(),
    );
    _refreshToken = refreshToken;
    _trustedDeviceId = trustedDeviceId;
    _currentUser = session.user;
    _status = SessionStatus.authenticated;
    notifyListeners();
  }

  Future<void> configurePin({
    required String pin,
    required String refreshToken,
    required int trustedDeviceId,
  }) async {
    if (!supportsPin || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain exactly four digits');
    }
    final salt = _randomSalt();
    final pinHash = _derivePinHash(pin, salt);
    await _secureStorage.write(key: _pinSaltKey, value: salt);
    await _secureStorage.write(key: _pinHashKey, value: pinHash);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.write(
      key: _trustedDeviceIdKey,
      value: trustedDeviceId.toString(),
    );
    await _secureStorage.write(key: _pinAttemptsKey, value: '0');
    await _secureStorage.write(key: _pinOfferDismissedKey, value: 'false');
    _pinSalt = salt;
    _pinHash = pinHash;
    _refreshToken = refreshToken;
    _trustedDeviceId = trustedDeviceId;
    _pinAttempts = 0;
    _pinOfferDismissed = false;
    notifyListeners();
  }

  Future<void> changePin(String pin) async {
    if (!hasPinConfigured || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN is unavailable or invalid');
    }
    final salt = _randomSalt();
    final pinHash = _derivePinHash(pin, salt);
    await _secureStorage.write(key: _pinSaltKey, value: salt);
    await _secureStorage.write(key: _pinHashKey, value: pinHash);
    await _secureStorage.write(key: _pinAttemptsKey, value: '0');
    _pinSalt = salt;
    _pinHash = pinHash;
    _pinAttempts = 0;
    notifyListeners();
  }

  Future<PinVerificationResult> verifyPin(String pin) async {
    if (!hasPinConfigured || !hasTrustedSession) {
      return PinVerificationResult.unavailable;
    }
    if (_pinAttempts >= maxPinAttempts) {
      await clearSession();
      return PinVerificationResult.lockedOut;
    }
    final matches = _constantTimeEquals(
      _derivePinHash(pin, _pinSalt!),
      _pinHash!,
    );
    if (!matches) {
      _pinAttempts += 1;
      await _secureStorage.write(
        key: _pinAttemptsKey,
        value: _pinAttempts.toString(),
      );
      if (_pinAttempts >= maxPinAttempts) {
        await clearSession();
        return PinVerificationResult.lockedOut;
      }
      notifyListeners();
      return PinVerificationResult.invalid;
    }
    _pinAttempts = 0;
    await _secureStorage.write(key: _pinAttemptsKey, value: '0');
    return PinVerificationResult.success;
  }

  Future<void> dismissPinOffer() async {
    _pinOfferDismissed = true;
    await _secureStorage.write(key: _pinOfferDismissedKey, value: 'true');
    notifyListeners();
  }

  Future<void> lockSession() async {
    if (hasPinConfigured && hasTrustedSession) {
      _resetAccessSession();
      await _deleteAccessSession();
      _currentUser = null;
      _status = SessionStatus.locked;
      notifyListeners();
      return;
    }
    await clearSession();
  }

  void markAuthenticated(CurrentUser user) {
    _currentUser = user;
    _status = SessionStatus.authenticated;
    notifyListeners();
  }

  void markTemporarilyUnavailable() {
    _currentUser = null;
    _status = SessionStatus.temporarilyUnavailable;
    notifyListeners();
  }

  SessionStatus get status => _status;

  CurrentUser? get currentUser => _currentUser;

  bool get supportsPin =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get hasPinConfigured =>
      supportsPin &&
      _pinSalt?.isNotEmpty == true &&
      _pinHash?.isNotEmpty == true;

  bool get hasTrustedSession =>
      _refreshToken?.isNotEmpty == true && _trustedDeviceId != null;

  bool get shouldOfferPin =>
      supportsPin &&
      _status == SessionStatus.authenticated &&
      !hasPinConfigured &&
      !_pinOfferDismissed;

  int get remainingPinAttempts =>
      (maxPinAttempts - _pinAttempts).clamp(0, maxPinAttempts);

  String? getRefreshToken() => _refreshToken;

  int? getTrustedDeviceId() => _trustedDeviceId;

  bool get hasRestorableToken {
    final token = getAccessToken();
    return token != null && token.isNotEmpty && !isTokenExpired();
  }

  String? getAccessToken() => _accessToken;

  String? getTokenType() => _tokenType;

  bool isLoggedIn() {
    return _status == SessionStatus.authenticated &&
        _currentUser != null &&
        hasRestorableToken;
  }

  bool isTokenExpired() {
    final expiresIn = _expiresIn;
    final loginTime = _loginTime;

    if (expiresIn == null || loginTime == null) return true;

    final expirationTime = loginTime + (expiresIn * 1000);
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    return currentTime >= expirationTime;
  }

  String? getAuthHeader() {
    final tokenType = getTokenType();
    final accessToken = getAccessToken();

    if (tokenType == null || accessToken == null) return null;

    return '$tokenType $accessToken';
  }

  Future<void> clearSession() async {
    _resetAccessSession();
    _resetTrustedSession();
    await _deleteAccessSession();
    await _deleteTrustedSession();
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> disablePinLocal() async {
    _resetTrustedSession();
    await _deleteTrustedSession();
    notifyListeners();
  }

  void _resetAccessSession() {
    _accessToken = null;
    _tokenType = null;
    _expiresIn = null;
    _loginTime = null;
    _currentUser = null;
  }

  void _resetTrustedSession() {
    _refreshToken = null;
    _trustedDeviceId = null;
    _pinSalt = null;
    _pinHash = null;
    _pinAttempts = 0;
    _pinOfferDismissed = false;
  }

  Future<void> _deleteAccessSession() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _tokenTypeKey);
    await _secureStorage.delete(key: _expiresInKey);
    await _secureStorage.delete(key: _loginTimeKey);
  }

  Future<void> _deleteTrustedSession() async {
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _trustedDeviceIdKey);
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinHashKey);
    await _secureStorage.delete(key: _pinAttemptsKey);
    await _secureStorage.delete(key: _pinOfferDismissedKey);
  }

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _derivePinHash(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var iteration = 0; iteration < 50000; iteration++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64UrlEncode(bytes);
  }

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }

  DateTime? getLoginTime() {
    final loginTime = _loginTime;
    if (loginTime == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(loginTime);
  }

  Duration? getTokenRemainingTime() {
    final expiresIn = _expiresIn;
    final loginTime = _loginTime;

    if (expiresIn == null || loginTime == null) return null;

    final expirationTime = loginTime + (expiresIn * 1000);
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (currentTime >= expirationTime) return Duration.zero;

    return Duration(milliseconds: expirationTime - currentTime);
  }
}
