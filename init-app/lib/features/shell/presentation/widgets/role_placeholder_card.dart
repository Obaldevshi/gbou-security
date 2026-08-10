import 'package:flutter/material.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';

class RolePlaceholderCard extends StatelessWidget {
  const RolePlaceholderCard({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimensions.feedMaxWidth),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: AppDimensions.paddingAllL,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: AppDimensions.iconXL,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppDimensions.spaceM),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spaceS),
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
