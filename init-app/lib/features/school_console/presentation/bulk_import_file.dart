import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

abstract final class BulkImportFile {
  static String decode(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null) throw const FormatException('Файл не прочитан');
    if (file.extension?.toLowerCase() != 'xlsx') {
      return utf8.decode(bytes, allowMalformed: true);
    }
    final workbook = Excel.decodeBytes(bytes);
    final table = workbook.tables.values.firstWhere(
      (item) => item.rows.any((row) => row.any((cell) => cell?.value != null)),
      orElse: () => throw const FormatException('В файле нет строк'),
    );
    final rows = table.rows
        .map(
          (row) =>
              row.map((cell) => cell?.value?.toString().trim() ?? '').toList(),
        )
        .where((row) => row.any((value) => value.isNotEmpty))
        .toList();
    if (rows.isNotEmpty && _looksLikeHeader(rows.first)) rows.removeAt(0);
    return rows.map((row) => row.join(';')).join('\n');
  }

  static Future<void> saveTemplate({required bool teachers}) async {
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    final name = teachers ? 'Учителя' : 'Ученики';
    if (defaultSheet != null && defaultSheet != name) {
      workbook.rename(defaultSheet, name);
    }
    final sheet = workbook[name];
    if (teachers) {
      sheet.appendRow([
        TextCellValue('ФИО'),
        TextCellValue('Логин'),
        TextCellValue('Телефон'),
        TextCellValue('Временный пароль'),
        TextCellValue('Классы'),
      ]);
      sheet.appendRow([
        TextCellValue('Иванова Мария Петровна'),
        TextCellValue('teacher.ivanova'),
        TextCellValue('+79000000000'),
        TextCellValue('SchoolPass123!'),
        TextCellValue('5А,7Б'),
      ]);
    } else {
      sheet.appendRow([
        TextCellValue('ФИО'),
      ]);
      sheet.appendRow([
        TextCellValue('Иванов Иван Иванович'),
      ]);
    }
    final encoded = workbook.encode();
    if (encoded == null) throw const FormatException('Шаблон не создан');
    await FilePicker.saveFile(
      dialogTitle: 'Сохранить шаблон',
      fileName: teachers ? 'шаблон_учителя.xlsx' : 'шаблон_ученики.xlsx',
      bytes: Uint8List.fromList(encoded),
    );
  }

  static bool _looksLikeHeader(List<String> row) {
    final first = row.join(' ').toLowerCase();
    return first.contains('фио') ||
        (first.contains('фамил') && first.contains('класс'));
  }
}
