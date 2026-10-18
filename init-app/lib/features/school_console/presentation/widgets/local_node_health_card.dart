import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/school_connection_service.dart';
import 'package:mobile_template/features/school_console/data/local_node_status_api.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';

class LocalNodeHealthCard extends StatefulWidget {
  const LocalNodeHealthCard({super.key});

  @override
  State<LocalNodeHealthCard> createState() => _LocalNodeHealthCardState();
}

class _LocalNodeHealthCardState extends State<LocalNodeHealthCard> {
  LocalNodeStatus? _status;
  Timer? _timer;
  bool _busy = false;
  bool _error = false;

  bool get _enabled =>
      const bool.fromEnvironment('GBOU_LOCAL_MODE') ||
      (getIt.isRegistered<SchoolConnectionService>() &&
          getIt<SchoolConnectionService>().isLocal) ||
      (kIsWeb &&
          const {
            'gbousecurity.local',
            'gbou-local.local',
          }.contains(Uri.base.host));

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      _load();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || !getIt.isRegistered<Dio>()) {
      return;
    }
    _busy = true;
    try {
      final result = await LocalNodeStatusApi(
        getIt<Dio>(),
        getIt<String>(instanceName: 'baseUrl'),
      ).load();
      if (mounted) {
        setState(() {
          _status = result;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      _busy = false;
    }
  }

  String _date(DateTime? value) => value == null
      ? 'ещё не выполнено'
      : DateFormat('dd.MM.yyyy HH:mm').format(value.toLocal());

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();
    final status = _status;
    final warning = _error || (status?.warnings.isNotEmpty ?? false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  warning ? Icons.warning_amber_rounded : Icons.storage_rounded,
                  color: warning
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Локальный сервер школы',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Проверить состояние',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_error)
              const Text(
                'Не удалось проверить резервные копии. Проверьте доступ к школьному серверу.',
              )
            else if (status == null)
              const Text('Проверяем сервер и резервные копии…')
            else ...[
              Text(
                'USB: ${status.usbConnected ? 'подключена' : 'не подключена'} · Свободно на SD: ${(status.sdFreeMb / 1024).toStringAsFixed(1)} ГБ',
              ),
              Text('Проверенная копия: ${_date(status.lastBackupAt)}'),
              Text('Настройки обновлены: ${_date(status.lastSyncAt)}'),
              for (final message in status.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(message),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
