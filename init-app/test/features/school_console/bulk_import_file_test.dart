import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/school_console/presentation/bulk_import_file.dart';

void main() {
  test('XLSX import skips header and converts rows to semicolon text', () {
    final workbook = Excel.createExcel();
    final sheet = workbook[workbook.getDefaultSheet()!];
    sheet.appendRow([
      TextCellValue('Фамилия'),
      TextCellValue('Имя'),
      TextCellValue('Отчество'),
      TextCellValue('Класс'),
    ]);
    sheet.appendRow([
      TextCellValue('Иванов'),
      TextCellValue('Иван'),
      TextCellValue('Иванович'),
      TextCellValue('5А'),
    ]);
    final bytes = Uint8List.fromList(workbook.encode()!);
    final file = PlatformFile(
      name: 'students.xlsx',
      size: bytes.length,
      bytes: bytes,
    );

    expect(BulkImportFile.decode(file), 'Иванов;Иван;Иванович;5А');
  });
}
