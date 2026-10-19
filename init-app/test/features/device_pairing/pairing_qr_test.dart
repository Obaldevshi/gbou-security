import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing_qr.dart';

void main() {
  const id = '53535162-f12c-4ed3-9215-b78874169816';
  test(
    'real agent hash QR and manual ID, never chooses another API origin',
    () {
      for (final value in [
        id,
        'https://gbousecurity.ru/#/connect/$id',
        'https://gbousecurity.ru/connect/$id',
        'https://GBOUSECURITY.RU:443/#/connect/${id.toUpperCase()}',
      ]) {
        expect(PairingQr.requestId(value), id);
      }
    },
  );
  test(
    'QR rejects credentials, foreign origins, query secrets and arbitrary routes',
    () {
      for (final value in [
        'http://gbousecurity.ru/#/connect/$id',
        'https://gbousecurity.ru.evil.example/#/connect/$id',
        'https://gbousecurity.ru@evil.example/#/connect/$id',
        'https://user:password@gbousecurity.ru/#/connect/$id',
        'https://gbousecurity.ru:8443/#/connect/$id',
        'https://gbousecurity.ru/?token=secret#/connect/$id',
        'https://gbousecurity.ru/#/connect/$id?token=secret',
        'https://gbousecurity.ru/#/system/schools',
        'https://gbousecurity.ru/#/connect/../../system',
        'https://gbousecurity.ru/#/connect/$id/extra',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'not a QR',
        '1' * 513,
      ]) {
        expect(
          PairingQr.requestId(value),
          isNull,
          reason: 'Untrusted QR must not navigate',
        );
      }
    },
  );
}
