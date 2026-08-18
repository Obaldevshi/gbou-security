import 'package:flutter/material.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/presentation/widgets/common/glass_surface_card.dart';
import 'package:mobile_template/presentation/widgets/common/global_button.dart';

class GuardRequestCard extends StatelessWidget {
  const GuardRequestCard({
    required this.request,
    required this.isReleasing,
    required this.onRelease,
    this.readOnly = false,
    super.key,
  });

  final ExitRequest request;
  final bool isReleasing;
  final VoidCallback onRelease;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final isWide = AppLayoutItemBuilder<bool>.values(narrow: false, wide: true)(
      context,
    );
    final details = _RequestDetails(request: request);
    final action = readOnly
        ? _PendingChip(label: 'Выпущен')
        : Semantics(
            button: true,
            label: context.l10n.guardReleaseStudent(request.studentFullName),
            child: SizedBox(
              width: isWide ? 190 : double.infinity,
              child: GlobalButton(
                text: context.l10n.guardRelease,
                onPressed: onRelease,
                isLoading: isReleasing,
                isEnabled: !isReleasing,
              ),
            ),
          );

    return GlassSurfaceCard(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: details),
                const SizedBox(width: AppDimensions.spaceL),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!readOnly) ...[
                      _PendingChip(
                        label: context.l10n.requestPendingStatusShort,
                      ),
                      const SizedBox(height: AppDimensions.spaceM),
                    ],
                    action,
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: AppDimensions.spaceM),
                if (!readOnly) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _PendingChip(
                      label: context.l10n.requestPendingStatusShort,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceM),
                ],
                action,
              ],
            ),
    );
  }
}

class _RequestDetails extends StatelessWidget {
  const _RequestDetails({required this.request});

  final ExitRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final scheduled =
        '${material.formatShortDate(request.scheduledAt)} · '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(request.scheduledAt))}';
    final reason = request.reasonType == ExitReasonType.other
        ? request.customReason ?? context.l10n.requestReasonOther
        : switch (request.reasonType) {
            ExitReasonType.parentNote => context.l10n.requestReasonParentNote,
            ExitReasonType.health => context.l10n.requestReasonHealth,
            ExitReasonType.other => context.l10n.requestReasonOther,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request.studentFullName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Wrap(
          spacing: AppDimensions.spaceM,
          runSpacing: AppDimensions.spaceS,
          children: [
            _Detail(icon: Icons.school_outlined, text: request.className),
            _Detail(icon: Icons.schedule_rounded, text: scheduled),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceM),
        _LabeledText(label: context.l10n.requestReason, value: reason),
        const SizedBox(height: AppDimensions.spaceS),
        _LabeledText(
          label: context.l10n.guardTeacher,
          value: request.teacherFullName,
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppDimensions.spaceXS),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
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
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
