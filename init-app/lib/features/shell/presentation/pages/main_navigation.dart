import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/layout/app_layout_item_builder.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/core/utils/keyboard_inset.dart';
import 'package:mobile_template/features/shell/presentation/widgets/session_user_menu_button.dart';
import 'package:mobile_template/generated/assets.gen.dart';
import 'package:mobile_template/presentation/widgets/common/app_svg_icon.dart';
import 'package:mobile_template/presentation/widgets/common/glass_bottom_nav_bar.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  void _onTabSelected(int index) {
    KeyboardInset.dismiss();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final items = [
      _AdaptiveNavigationItem(
        label: context.l10n.newRequest,
        icon: Assets.icons.home,
      ),
      _AdaptiveNavigationItem(
        label: context.l10n.activeRequests,
        icon: Assets.icons.category,
      ),
      _AdaptiveNavigationItem(
        label: context.l10n.requestHistory,
        icon: Assets.icons.user,
      ),
      _AdaptiveNavigationItem(label: 'Мои ученики', icon: Assets.icons.user),
    ];

    return AppLayoutItemBuilder<Widget>(
      narrow: () => _buildNarrowNavigation(context, items, inactiveColor),
      wide: () => _buildWideNavigation(context, items, inactiveColor),
    )(context);
  }

  Widget _buildNarrowNavigation(
    BuildContext context,
    List<_AdaptiveNavigationItem> items,
    Color inactiveColor,
  ) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.navigationShell,
          KeyboardInsetBuilder(
            builder: (context, keyboardInset) {
              if (keyboardInset > 0) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomNavBar(
                  currentIndex: widget.navigationShell.currentIndex,
                  onTabSelected: _onTabSelected,
                  items: items
                      .map(
                        (item) => GlassNavBarItem(
                          label: item.label,
                          icon: AppSvgIcon(
                            icon: item.icon,
                            color: inactiveColor,
                          ),
                          activeIcon: AppSvgIcon(
                            icon: item.icon,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWideNavigation(
    BuildContext context,
    List<_AdaptiveNavigationItem> items,
    Color inactiveColor,
  ) {
    final theme = Theme.of(context);
    final showLabels = AppLayoutItemBuilder<bool>.values(
      narrow: false,
      wide: true,
    )(context, width: 760);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingL,
                AppDimensions.paddingM,
                AppDimensions.paddingL,
                AppDimensions.paddingS,
              ),
              child: Material(
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppDimensions.borderRadius,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 68,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingL,
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.appName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        for (var index = 0; index < items.length; index++) ...[
                          _WebNavigationButton(
                            item: items[index],
                            selected:
                                widget.navigationShell.currentIndex == index,
                            showLabel: showLabels,
                            inactiveColor: inactiveColor,
                            onPressed: () => _onTabSelected(index),
                          ),
                          if (index != items.length - 1)
                            const SizedBox(width: AppDimensions.spaceS),
                        ],
                        const SizedBox(width: AppDimensions.spaceM),
                        const SessionUserMenuButton(showName: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}

class _WebNavigationButton extends StatelessWidget {
  const _WebNavigationButton({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.inactiveColor,
    required this.onPressed,
  });

  final _AdaptiveNavigationItem item;
  final bool selected;
  final bool showLabel;
  final Color inactiveColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected ? theme.colorScheme.onPrimary : inactiveColor;
    return Tooltip(
      message: item.label,
      child: Material(
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: AppDimensions.borderRadius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppDimensions.borderRadius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: showLabel
                  ? AppDimensions.paddingM
                  : AppDimensions.paddingS,
              vertical: AppDimensions.paddingS,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(icon: item.icon, color: foreground, size: 20),
                if (showLabel) ...[
                  const SizedBox(width: AppDimensions.spaceS),
                  Text(
                    item.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveNavigationItem {
  const _AdaptiveNavigationItem({required this.label, required this.icon});

  final String label;
  final SvgGenImage icon;
}
