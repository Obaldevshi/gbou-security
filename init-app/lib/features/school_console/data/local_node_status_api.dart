import 'package:dio/dio.dart';

class LocalNodeStatus {
  const LocalNodeStatus({
    required this.warnings,
    required this.usbConnected,
    required this.sdFreeMb,
    this.lastBackupAt,
    this.lastSyncAt,
  });

  final List<String> warnings;
  final bool usbConnected;
  final int sdFreeMb;
  final DateTime? lastBackupAt;
  final DateTime? lastSyncAt;

  factory LocalNodeStatus.fromJson(
    Map<String, dynamic> data,
  ) => LocalNodeStatus(
    warnings: List<String>.from(data['warnings'] as List),
    usbConnected: data['usb_connected'] as bool,
    sdFreeMb: data['sd_free_mb'] as int,
    lastBackupAt: DateTime.tryParse(data['last_backup_at'] as String? ?? ''),
    lastSyncAt: DateTime.tryParse(data['last_config_sync_at'] as String? ?? ''),
  );
}

class LocalNodeStatusApi {
  const LocalNodeStatusApi(this.dio, this.baseUrl);
  final Dio dio;
  final String baseUrl;

  Future<LocalNodeStatus> load() async {
    final response = await dio.get<Map<String, dynamic>>(
      '$baseUrl/school/node-status',
    );
    return LocalNodeStatus.fromJson(
      Map<String, dynamic>.from(response.data!['data'] as Map),
    );
  }
}
