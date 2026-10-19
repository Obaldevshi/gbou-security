import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/privacy/data/bundled_privacy_repository.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.source);
  final String source;
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'policy is available from the bundle without HTTP and explicitly draft',
    () async {
      final result = await BundledPrivacyRepository().load();
      final policy = result.getOrElse(
        (_) => throw StateError('Bundled policy missing'),
      );
      expect(policy.sections.length, greaterThan(5));
      expect(policy.ready, isFalse);
      expect(policy.operatorName, 'Росляков Алексей Николаевич');
      expect(policy.contactEmail, 'Obaldevshi@gmail.com');
      expect(policy.retentionPolicy, contains('один год'));
      expect(policy.sections.any((e) => e.title.contains('Удаление')), isTrue);
    },
  );
  test('malformed bundle returns failure, not an endless spinner', () async {
    expect(
      (await BundledPrivacyRepository(_Bundle('not json')).load()).isLeft(),
      isTrue,
    );
  });
}
