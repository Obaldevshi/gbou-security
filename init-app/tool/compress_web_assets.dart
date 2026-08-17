import 'dart:io';

Future<void> main(List<String> arguments) async {
  final output = Directory(arguments.isEmpty ? 'build/web' : arguments.first);
  if (!output.existsSync()) {
    stderr.writeln('Web output does not exist: ${output.path}');
    exitCode = 2;
    return;
  }

  final files = output.listSync(recursive: true).whereType<File>().where((
    file,
  ) {
    final normalized = file.path.replaceAll('\\', '/');
    if (normalized.endsWith('/main.dart.js')) return true;
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
    final compressed = gzip.encode(await file.readAsBytes());
    await File('${file.path}.gz').writeAsBytes(compressed, flush: true);
    stdout.writeln(
      '${file.path}: ${await file.length()} -> ${compressed.length} bytes',
    );
  }
}
