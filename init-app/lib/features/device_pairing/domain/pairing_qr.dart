/// A QR never chooses an API origin and never carries an administrative token.
abstract final class PairingQr {
  static final _id = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static String? requestId(String input) {
    final raw = input.trim();
    if (raw.length > 512 || RegExp(r'\s').hasMatch(raw)) return null;
    if (_id.hasMatch(raw)) return raw.toLowerCase();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'gbousecurity.ru' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery) {
      return null;
    }
    final route = uri.hasFragment && (uri.path.isEmpty || uri.path == '/')
        ? uri.fragment
        : (!uri.hasFragment ? uri.path : '');
    const prefix = '/connect/';
    if (!route.startsWith(prefix)) return null;
    final id = route.substring(prefix.length);
    return _id.hasMatch(id) ? id.toLowerCase() : null;
  }
}
