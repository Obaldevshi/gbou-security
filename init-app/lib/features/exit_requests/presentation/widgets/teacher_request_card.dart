import 'package:flutter/material.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';

class TeacherRequestCard extends StatelessWidget {
  const TeacherRequestCard({required this.request, this.onCancel, super.key});

  final ExitRequest request;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final scheduled =
        '${material.formatShortDate(request.scheduledAt)} · '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(request.scheduledAt))}';
    final reason = switch (request.reasonType) {
      ExitReasonType.parentNote => context.l10n.requestReasonParentNote,
      ExitReasonType.health => context.l10n.requestReasonHealth,
      ExitReasonType.other =>
        request.customReason ?? context.l10n.requestReasonOther,
    };
    final released = request.status == ExitRequestStatus.released;

    return GlassSurfaceCard(
      padding: AppDimensions.paddingAllL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.studentFullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceM),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceS),
          Wrap(
            spacing: AppDimensions.spaceM,
            runSpacing: AppDimensions.spaceS,
            children: [
              _Detail(icon: Icons.school_outlined, text: request.className),
              _Detail(icon: Icons.schedule_rounded, text: scheduled),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceM),
          Text(
            '${context.l10n.requestReason}: $reason',
            style: theme.textTheme.bodyLarge,
          ),
          if (released && request.releasedAt != null) ...[
            const SizedBox(height: AppDimensions.spaceS),
            Text(
              '${context.l10n.teacherReleasedAt}: '
              '${material.formatShortDate(request.releasedAt!)} · '
              '${material.formatTimeOfDay(TimeOfDay.fromDateTime(request.releasedAt!))}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (onCancel != null &&
              request.status == ExitRequestStatus.pending) ...[
            const SizedBox(height: AppDimensions.spaceM),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Отменить заявку'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: AppDimensions.spaceXS),
      Text(text, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ExitRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ExitRequestStatus.pending => Theme.of(context).colorScheme.primary,
      ExitRequestStatus.released => Theme.of(context).colorScheme.tertiary,
      ExitRequestStatus.cancelled => Theme.of(context).colorScheme.error,
      ExitRequestStatus.expired => Theme.of(context).colorScheme.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppDimensions.borderRadiusM,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(switch (status) {
        ExitRequestStatus.pending => context.l10n.requestPendingStatusShort,
        ExitRequestStatus.released => context.l10n.requestReleasedStatus,
        ExitRequestStatus.cancelled => 'Отменена',
        ExitRequestStatus.expired => 'Истекла',
      }, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
