import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/network/school_tls.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';

class SchoolConnectionDialog extends StatefulWidget {
  const SchoolConnectionDialog({super.key});

  @override
  State<SchoolConnectionDialog> createState() => _SchoolConnectionDialogState();
}

class _SchoolConnectionDialogState extends State<SchoolConnectionDialog> {
  final _service = getIt<SchoolConnectionService>();
  late final _address = TextEditingController(
    text: _service.connection.apiBaseUrl.replaceFirst('/api/v1', ''),
  );
  late String? _certificate = _service.connection.caPem;
  bool _verified = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _importCertificate() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pem', 'crt'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 32768 || file.bytes == null) {
        throw const FormatException(
          'Сертификат не читается или слишком большой.',
        );
      }
      final pem = utf8.decode(file.bytes!);
      SchoolConnection.certificateFingerprint(pem);
      validateSchoolCertificate(
        SchoolConnection.parse(_address.text, caPem: pem),
      );
      setState(() {
        _certificate = pem;
        _verified = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Не удалось добавить сертификат: $error');
      }
    }
  }

  Future<void> _save() async {
    if (_certificate != null && !_verified) {
      setState(
        () => _error = 'Сверьте отпечаток сертификата с администратором школы.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final connection = SchoolConnection.parse(
        _address.text,
        caPem: _certificate,
      );
      validateSchoolCertificate(connection);
      await _service.select(connection);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = 'Подключение не сохранено: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Подключение к школе'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'В школьной сети укажите адрес, выданный администратором. Данные школы не отправляются в облако. При смене подключения потребуется новый вход и настройка PIN.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              enabled: !_saving,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Адрес школы',
                hintText: 'https://gbousecurity.local',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _importCertificate,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Добавить сертификат школы'),
            ),
            if (_certificate != null) ...[
              const SizedBox(height: 8),
              const Text('Отпечаток SHA-256 (сверьте лично):'),
              SelectableText(
                SchoolConnection.certificateFingerprint(_certificate!),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _verified,
                title: const Text('Отпечаток совпадает с выданным школой'),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _verified = value ?? false),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _certificate = null;
                        _verified = false;
                      }),
                child: const Text('Использовать обычный HTTPS-сертификат'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _address.text = _service.defaultBaseUrl.replaceFirst(
                        '/api/v1',
                        '',
                      );
                      _certificate = null;
                      _verified = false;
                    }),
              child: const Text('Центральный сервер · главный администратор'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
      ),
    ],
  );
}
