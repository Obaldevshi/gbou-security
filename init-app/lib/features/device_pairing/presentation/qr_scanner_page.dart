import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing_qr.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});
  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  late final _camera = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false, _starting = false, _cameraFailed = false;
  bool _cameraEnabled = false;
  bool _invalid = false;
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _start() async {
    if (!mounted || _starting || _handled || !_cameraEnabled) return;
    _starting = true;
    try {
      await _camera.start();
      if (mounted) setState(() => _cameraFailed = false);
    } catch (_) {
      if (mounted) setState(() => _cameraFailed = true);
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    if (!_supported || !_cameraEnabled) return;
    try {
      await _camera.stop().timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Camera may already be released by OS. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_supported || !_cameraEnabled) return;
    if (state == AppLifecycleState.resumed) {
      if (_camera.value.hasCameraPermission) unawaited(_start());
    } else {
      unawaited(_stop());
    }
  }

  Future<void> _accept(String raw) async {
    if (_handled) return;
    final id = PairingQr.requestId(raw);
    if (id == null) {
      if (mounted) setState(() => _invalid = true);
      return;
    }
    setState(() {
      _handled = true;
      _invalid = false;
    });
    await _stop();
    if (mounted) context.pushReplacement('${AppRoutes.connectDevices}/$id');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    if (_supported && _cameraEnabled) unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.qrScannerTitle)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(context.l10n.qrScannerHint),
              const SizedBox(height: 16),
              if (_supported) ...[
                Text(context.l10n.qrCameraPrivacy),
                const SizedBox(height: 12),
                if (!_cameraEnabled)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _cameraEnabled = true);
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _start(),
                      );
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(context.l10n.qrCameraStart),
                  ),
                if (_cameraEnabled)
                  SizedBox(
                    height: 240,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MobileScanner(
                        controller: _camera,
                        onDetect: (capture) {
                          for (final code in capture.barcodes) {
                            if (code.rawValue != null) {
                              unawaited(_accept(code.rawValue!));
                              break;
                            }
                          }
                        },
                        onDetectError: (_, _) {
                          if (mounted) setState(() => _cameraFailed = true);
                        },
                        errorBuilder: (context, error) => ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(context.l10n.qrCameraUnavailable),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_cameraFailed)
                  TextButton(
                    onPressed: _start,
                    child: Text(context.l10n.retry),
                  ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: _input,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 512,
                decoration: InputDecoration(
                  labelText: context.l10n.qrScannerLink,
                  errorText: _invalid ? context.l10n.qrScannerInvalid : null,
                  errorMaxLines: 3,
                ),
                onChanged: (_) {
                  if (_invalid) setState(() => _invalid = false);
                },
                onSubmitted: _accept,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _handled ? null : () => _accept(_input.text),
                icon: const Icon(Icons.arrow_forward),
                label: Text(context.l10n.qrScannerOpen),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
