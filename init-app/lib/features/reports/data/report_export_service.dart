import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

@lazySingleton
class ReportExportService {
  const ReportExportService(this.dio, @Named('baseUrl') this.baseUrl);
  final Dio dio;
  final String baseUrl;

  Future<void> export({
    required bool schoolOnly,
    required String format,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await dio.get<List<int>>(
      '$baseUrl/${schoolOnly ? 'school/reports/requests' : 'system/reports/overview'}',
      queryParameters: {
        'format': format,
        if (from != null) 'date_from': from.toUtc().toIso8601String(),
        if (to != null)
          'date_to': DateTime(
            to.year,
            to.month,
            to.day,
            23,
            59,
            59,
          ).toUtc().toIso8601String(),
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await FilePicker.saveFile(
      dialogTitle: 'Сохранить отчёт',
      fileName:
          '${schoolOnly ? 'заявки_школы' : 'сводка_системы'}_$stamp.$format',
      bytes: Uint8List.fromList(response.data!),
    );
  }
}
