/// Retrofit auth endpoint paths (relative to API base URL).
abstract final class AuthApiPaths {
  static const login = '/auth/login';
  static const trustedRefresh = '/auth/trusted-devices/refresh';
  static const trustedRevokeToken = '/auth/trusted-devices/revoke-token';

  static const Set<String> unauthenticated = {
    login,
    trustedRefresh,
    trustedRevokeToken,
  };

  static bool isUnauthenticated(String path) {
    return unauthenticated.any((endpoint) => _matches(path, endpoint));
  }

  static bool _matches(String path, String endpoint) {
    return path == endpoint || path.endsWith(endpoint);
  }
}
