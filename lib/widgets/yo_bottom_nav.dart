import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class YoNavItem {
  const YoNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
}

/// Floating white tab bar with a brand-gradient pill on the active tab
/// (YO market design). Lives in `Scaffold.bottomNavigationBar` (not
/// `extendBody`), so it never covers page content.
///
/// Labels are never shrunk below the user's text size. When they do not all
/// fit, the bar switches to the Material 3 "label on selected tab" pattern:
/// the active tab gets a wider slot with its label, the others show icons
/// (with tooltips and full semantics labels). The bar grows in height with
/// the text scale.
class YoBottomNav extends StatelessWidget {
  const YoBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<YoNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const labelStyle = TextStyle(fontSize: 11, height: 1.2);
  static const _barPadding = 4.0;
  static const _slotPadding = 4.0;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final labelHeight = scaler.scale(labelStyle.fontSize!) * labelStyle.height!;
    final barHeight = 24 + 4 + labelHeight + 2 * _barPadding + 18;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Container(
          height: barHeight,
          padding: const EdgeInsets.all(_barPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final allFit = _labelsFit(
                context,
                c.maxWidth / items.length - 2 * _slotPadding,
              );
              return Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      flex: !allFit && i == currentIndex ? 2 : 1,
                      child: _NavButton(
                        key: Key('nav-${items[i].label}'),
                        item: items[i],
                        selected: i == currentIndex,
                        showLabel: allFit || i == currentIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _labelsFit(BuildContext context, double slotWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    // Measure with the exact style the label is painted with (theme font).
    final style = DefaultTextStyle.of(context).style
        .merge(labelStyle)
        .copyWith(fontWeight: FontWeight.w800);
    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: style),
        textScaler: scaler,
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final fits = painter.width <= slotWidth;
      painter.dispose();
      if (!fits) return false;
    }
    return true;
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final YoNavItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.surface : AppColors.ink;
    Widget icon = Icon(
      selected ? item.selectedIcon : item.icon,
      color: fg,
      size: 24,
    );
    if (item.badgeCount > 0) {
      icon = Badge(
        label: Text('${item.badgeCount}'),
        backgroundColor: AppColors.brandYellow,
        textColor: AppColors.ink,
        child: icon,
      );
    }
    final semantics = item.badgeCount > 0
        ? '${item.label}, ${item.badgeCount}'
        : item.label;
    Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: YoBottomNav._slotPadding),
      decoration: BoxDecoration(
        gradient: selected ? AppGradients.brand : null,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          if (showLabel) ...[
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: YoBottomNav.labelStyle.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    if (!showLabel) body = Tooltip(message: item.label, child: body);
    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: body,
      ),
    );
  }
}
