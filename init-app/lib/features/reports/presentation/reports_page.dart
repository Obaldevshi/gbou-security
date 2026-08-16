import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_template/app/app_router.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/features/reports/data/report_export_service.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.schoolOnly, super.key});
  final bool schoolOnly;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime? from;
  DateTime? to;
  String? loading;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Отчёты и экспорт'),
      leading: IconButton(
        tooltip: 'Назад',
        onPressed: () => context.go(
          widget.schoolOnly ? AppRoutes.schoolClasses : AppRoutes.systemSchools,
        ),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      actions: const [SessionUserMenuButton(showName: true)],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: AppDimensions.paddingAllL,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.schoolOnly
                    ? 'Отчёт по заявкам школы'
                    : 'Сводный отчёт системы',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.schoolOnly
                    ? 'Детализация и сводка по статусам, классам и причинам.'
                    : 'Школы, статусы и основные показатели пользователей.',
              ),
              const SizedBox(height: 24),
              if (widget.schoolOnly)
                GlassSurfaceCard(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pick(true),
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          from == null
                              ? 'Дата начала'
                              : DateFormat('dd.MM.yyyy').format(from!),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pick(false),
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          to == null
                              ? 'Дата окончания'
                              : DateFormat('dd.MM.yyyy').format(to!),
                        ),
                      ),
                      if (from != null || to != null)
                        TextButton(
                          onPressed: () => setState(() {
                            from = null;
                            to = null;
                          }),
                          child: const Text('Сбросить период'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              GlassSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Выберите формат',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Excel содержит отдельную сводную таблицу; PDF удобен для печати и передачи.',
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: loading == null
                              ? () => _export('xlsx')
                              : null,
                          icon: const Icon(Icons.table_view_rounded),
                          label: Text(
                            loading == 'xlsx'
                                ? 'Готовим Excel…'
                                : 'Скачать Excel',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: loading == null
                              ? () => _export('pdf')
                              : null,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(
                            loading == 'pdf' ? 'Готовим PDF…' : 'Скачать PDF',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _pick(bool start) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: (start ? from : to) ?? DateTime.now(),
    );
    if (value != null) {
      setState(() => start ? from = value : to = value);
    }
  }

  Future<void> _export(String format) async {
    setState(() => loading = format);
    try {
      await getIt<ReportExportService>().export(
        schoolOnly: widget.schoolOnly,
        format: format,
        from: from,
        to: to,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Отчёт подготовлен')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось подготовить отчёт')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = null);
    }
  }
}
