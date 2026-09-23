import 'dart:io';

Future<void> main(List<String> arguments) async {
  final output = Directory(arguments.isEmpty ? 'build/web' : arguments.first);
  if (!output.existsSync()) {
    stderr.writeln('Web output does not exist: ${output.path}');
    exitCode = 2;
    return;
  }

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml was not found in ${Directory.current.path}');
    exitCode = 2;
    return;
  }
  final versionMatch = RegExp(
    r'^version:\s*([^\s]+)',
    multiLine: true,
  ).firstMatch(await pubspec.readAsString());
  if (versionMatch == null) {
    stderr.writeln('Application version was not found in pubspec.yaml');
    exitCode = 2;
    return;
  }
  final assetVersion = versionMatch.group(1)!.replaceAll('+', '-');

  final files = output.listSync(recursive: true).whereType<File>().where((
    file,
  ) {
    final normalized = file.path.replaceAll('\\', '/');
    if (normalized.endsWith('/main.dart.js') ||
        (normalized.contains('/main.dart.js_') &&
            normalized.endsWith('.part.js'))) {
      return true;
    }
    if (!normalized.contains('/canvaskit/')) return false;
    final relative = normalized.split('/canvaskit/').last;
    final isRuntimeVariant =
        !relative.contains('/') || relative.startsWith('chromium/');
    return isRuntimeVariant &&
        (relative.endsWith('.wasm') ||
            relative.endsWith('.js') ||
            relative.endsWith('.mjs'));
  }).toList();

  for (final file in files) {
    final legacy = File('${file.path}.gz');
    if (legacy.existsSync()) await legacy.delete();
    for (final candidate in file.parent.listSync().whereType<File>()) {
      if (candidate.path.startsWith('${file.path}.') &&
          candidate.path.endsWith('.gz')) {
        await candidate.delete();
      }
    }
    final compressed = gzip.encode(await file.readAsBytes());
    await File(
      '${file.path}.$assetVersion.gz',
    ).writeAsBytes(compressed, flush: true);
    stdout.writeln(
      '${file.path}: ${await file.length()} -> ${compressed.length} bytes',
    );
  }
}
