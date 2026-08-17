import 'package:mobile_template/core/bootstrap.dart';
import 'package:mobile_template/core/mock_di.dart';

Future<void> main() async {
  await bootstrap(
    envFileName: 'assets/env/.env.example',
    configureOverrides: configureMockRepositories,
  );
}
