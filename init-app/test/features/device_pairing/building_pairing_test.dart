import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mobile_template/features/device_pairing/data/pairing_repository.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing.dart';

void main() {
  test(
    'real transport uses campus overview instead of legacy school primary',
    () async {
      final api = PairingApi('https://central.example/api/v1');
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'networking_scope': 'building',
                  'overview': {
                    'hostname': 'legacy.gbousecurity.ru',
                    'generation': 99,
                    'devices': [],
                  },
                  'buildings': [
                    {'id': 1, 'name': 'Building1'},
                    {'id': 2, 'name': 'Building2'},
                  ],
                  'building_overviews': [
                    for (final id in [1, 2])
                      {
                        'building_id': id,
                        'hostname': '236-$id.gbousecurity.ru',
                        'generation': id,
                        'devices': [
                          {
                            'building_id': id,
                            'device_id': 'p$id',
                            'label': 'Pi$id',
                            'role': 'primary',
                            'state': 'active',
                          },
                        ],
                      },
                  ],
                },
              ),
            );
          },
        ),
      );
      final result = await PairingRepositoryImpl(api).school('synthetic', 1);
      final view = result.getOrElse((_) => throw StateError('mapping'));
      expect(view.generationFor('p2'), 2);
      expect(view.hostnameFor(2), '236-2.gbousecurity.ru');
      expect(view.hasPrimaryFor(1), isTrue);
      expect(view.hasPrimaryFor(999), isFalse);
      expect(view.generationFor('unregistered'), isNull);
      api.dio.close(force: true);
    },
  );
  test(
    'mock QR has an independent primary and generation for each building',
    () async {
      final repo = MockPairingRepository();
      Future<PairingSchool> school() async => (await repo.school(
        'mock',
        1,
      )).getOrElse((_) => throw StateError('mock'));
      await repo.approve('mock', 'p1', 1, 1, 'primary', '123456');
      await repo.activate('mock', 1, 'p1', 0);
      expect(
        (await repo.approve(
          'mock',
          'wrong-terminal',
          1,
          2,
          'terminal',
          '123456',
        )).isLeft(),
        isTrue,
      );
      await repo.approve('mock', 'p2', 1, 2, 'primary', '123456');
      await repo.activate('mock', 1, 'p2', 0);
      var view = await school();
      expect(view.hasPrimaryFor(1), isTrue);
      expect(view.hasPrimaryFor(2), isTrue);
      expect(view.hostnameFor(2), '236-2.gbousecurity.ru');
      await repo.approve('mock', 'replacement', 1, 1, 'primary', '123456');
      expect((await school()).generationFor('replacement'), 1);
      await repo.activate('mock', 1, 'replacement', 1);
      view = await school();
      expect(view.generationFor('replacement'), 2);
      expect(view.generationFor('p2'), 1);
      expect(view.devices.singleWhere((d) => d.id == 'p2').state, 'active');
      expect(view.devices.singleWhere((d) => d.id == 'p1').state, 'revoked');
    },
  );
}
