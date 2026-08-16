import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginHeroSection extends StatelessWidget {
  const LoginHeroSection({
    required this.title,
    required this.subtitle,
    this.showBackButton = false,
    this.onBackPressed,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = AppLayoutItemBuilder<bool>.values(narrow: false, wide: true)(
      context,
    );

    return Padding(
      padding: isWide
          ? AppDimensions.paddingAllXL
          : EdgeInsets.fromLTRB(
              AppDimensions.paddingL,
              showBackButton ? AppDimensions.paddingS : AppDimensions.paddingXL,
              AppDimensions.paddingL,
              AppDimensions.paddingL,
            ),
      child: Column(
        crossAxisAlignment: isWide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (showBackButton)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBackPressed ?? () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          Container(
            width: isWide ? 88 : 72,
            height: isWide ? 88 : 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: isWide ? AppDimensions.iconXL : AppDimensions.iconL,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceL),
          Text(
            context.l10n.appName,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: isWide ? TextAlign.left : TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceL),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: isWide ? TextAlign.left : TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceS),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
            textAlign: isWide ? TextAlign.left : TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceXL),
          _FeatureLine(
            icon: Icons.hub_rounded,
            text: context.l10n.loginFeatureUnified,
            centered: !isWide,
          ),
          const SizedBox(height: AppDimensions.spaceM),
          _FeatureLine(
            icon: Icons.badge_rounded,
            text: context.l10n.loginFeatureRoles,
            centered: !isWide,
          ),
          const SizedBox(height: AppDimensions.spaceM),
          _FeatureLine(
            icon: Icons.shield_rounded,
            text: context.l10n.loginFeatureProtected,
            centered: !isWide,
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.icon,
    required this.text,
    required this.centered,
  });

  final IconData icon;
  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        child: Icon(icon, color: Colors.white, size: AppDimensions.iconS),
      ),
      const SizedBox(width: AppDimensions.spaceM),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: content,
    );
  }
}
