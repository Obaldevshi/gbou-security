import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SessionStatus {
  bootstrapping,
  unauthenticated,
  authenticated,
  temporarilyUnavailable,
}

@lazySingleton
class SessionService extends ChangeNotifier {
  static const String _accessTokenKey = 'access_token';
  static const String _tokenTypeKey = 'token_type';
  static const String _expiresInKey = 'expires_in';
  static const String _loginTimeKey = 'login_time';

  SessionService._(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  String? _accessToken;
  String? _tokenType;
  int? _expiresIn;
  int? _loginTime;
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
    if (!service.hasRestorableToken) {
      service._resetInMemorySession();
      await service._deleteStoredSession();
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
    } catch (error, stackTrace) {
      // WebCrypto throws OperationError when legacy values were encrypted by
      // different keys. Treat an unreadable token as an expired session.
      debugPrint('Failed to restore secure session: $error');
      debugPrintStack(stackTrace: stackTrace);
      _resetInMemorySession();

      try {
        await _deleteStoredSession();
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
    _resetInMemorySession();
    await _deleteStoredSession();
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  void _resetInMemorySession() {
    _accessToken = null;
    _tokenType = null;
    _expiresIn = null;
    _loginTime = null;
    _currentUser = null;
  }

  Future<void> _deleteStoredSession() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _tokenTypeKey);
    await _secureStorage.delete(key: _expiresInKey);
    await _secureStorage.delete(key: _loginTimeKey);
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
