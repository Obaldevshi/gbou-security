import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/audit/domain/audit_log_entry.dart';
import 'package:mobile_template/features/audit/domain/audit_log_repository.dart';
import 'package:mobile_template/features/reports/data/report_export_service.dart';
import 'package:mobile_template/features/exit_requests/domain/repositories/exit_request_repository.dart';

class DemoAuditRepository implements AuditLogRepository {
  @override
  Future<Either<Failure, AuditLogPageData>> getLogs({
    required bool schoolOnly,
    required int page,
    String? search,
    String? method,
  }) async {
    final rows =
        [
              AuditLogEntry(
                id: 1,
                actorName: 'Демо Учитель',
                schoolName: 'Демо школа',
                method: 'POST',
                path: '/demo/requests',
                statusCode: 201,
                createdAt: DateTime(2026, 1, 1),
              ),
            ]
            .where(
              (e) =>
                  (method == null || method.isEmpty || e.method == method) &&
                  (search == null ||
                      search.isEmpty ||
                      '${e.actorName} ${e.path}'.toLowerCase().contains(
                        search.toLowerCase(),
                      )),
            )
            .toList();
    return Right(
      AuditLogPageData(
        items: page == 1 ? rows : [],
        total: rows.length,
        page: page,
        pageSize: 25,
      ),
    );
  }
}

/// Downloads contain synthetic aggregate counts only. Never calls an HTTP adapter.
class DemoReportExportService extends ReportExportService {
  DemoReportExportService(this.requests, Dio transport)
    : super(transport, 'https://demo.invalid/api/v1');
  final ExitRequestRepository requests;

  Future<Uint8List> buildBytes(
    String format, {
    DateTime? from,
    DateTime? to,
  }) async {
    final snapshot = (await requests.getSchoolExitRequests()).getOrElse(
      (_) => throw StateError('Demo report unavailable'),
    );
    final rows = [...snapshot.active, ...snapshot.history]
        .where(
          (e) =>
              (from == null ||
                  !e.scheduledAt.isBefore(
                    DateTime(from.year, from.month, from.day),
                  )) &&
              (to == null ||
                  e.scheduledAt.isBefore(
                    DateTime(to.year, to.month, to.day + 1),
                  )),
        )
        .toList();
    if (format == 'xlsx') {
      final book = Excel.createExcel();
      final sheet = book['DEMO'];
      sheet.appendRow([TextCellValue('DEMO - synthetic data only')]);
      sheet.appendRow([TextCellValue('Requests'), IntCellValue(rows.length)]);
      for (final row in rows) {
        sheet.appendRow([
          IntCellValue(row.id),
          TextCellValue(row.status.name),
          TextCellValue(row.scheduledAt.toIso8601String()),
        ]);
      }
      book.delete('Sheet1');
      return Uint8List.fromList(book.encode()!);
    }
    if (format != 'pdf') throw ArgumentError('Unsupported report format');
    // Small, valid PDF using the standard built-in Helvetica font: no font asset.
    final content =
        'BT /F1 18 Tf 50 780 Td (GBOU Security - DEMO) Tj '
        '0 -32 Td /F1 12 Tf (Synthetic data only. No production records.) Tj '
        '0 -24 Td (Requests in selected period: ${rows.length}) Tj ET';
    final objects = [
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
      '<< /Length ${ascii.encode(content).length} >>\nstream\n$content\nendstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];
    var pdf = '%PDF-1.4\n';
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(pdf.length);
      pdf += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
    }
    final start = pdf.length;
    pdf += 'xref\n0 6\n0000000000 65535 f \n';
    for (final offset in offsets) {
      pdf += '${offset.toString().padLeft(10, '0')} 00000 n \n';
    }
    pdf += 'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$start\n%%EOF\n';
    return Uint8List.fromList(ascii.encode(pdf));
  }

  @override
  Future<void> export({
    required bool schoolOnly,
    required String format,
    DateTime? from,
    DateTime? to,
  }) async {
    final bytes = await buildBytes(format, from: from, to: to);
    await FilePicker.saveFile(
      dialogTitle: 'ДЕМО — сохранить вымышленный отчёт',
      fileName: 'gbou-DEMO.$format',
      bytes: bytes,
    );
  }
}
