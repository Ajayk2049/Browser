import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_motion.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Actions exposed by the browser's menu.
enum BrowserMenuAction {
  findInPage(PhosphorIcons.magnifyingGlassPlus, 'Find in page'),
  history(PhosphorIcons.clockCounterClockwise, 'History'),
  bookmarks(PhosphorIcons.bookmarksSimple, 'Bookmarks'),
  downloadManager(PhosphorIcons.downloadSimple, 'Download Manager'),
  settings(PhosphorIcons.gearSix, 'Settings');

  const BrowserMenuAction(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Material 3 Expressive popup menu trigger anchored to the bottom bar Menu button.
/// Animates floating above the bottom bar without obscuring the menu button.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class BrowserMenuPopup extends StatelessWidget {
  final ValueChanged<BrowserMenuAction> onSelected;
  final Widget child;

  const BrowserMenuPopup({
    super.key,
    required this.onSelected,
    required this.child,
  });

  /// Opens the animated browser menu floating directly above the Menu button.
  static Future<BrowserMenuAction?> show(
    BuildContext context, {
    required ValueChanged<BrowserMenuAction> onSelected,
  }) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = MediaQuery.sizeOf(context);
    final buttonRect = renderBox != null
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : Rect.fromLTWH(size.width * 0.8, size.height - 64, size.width * 0.2, 64);
    final theme = Theme.of(context);

    return Navigator.of(context).push<BrowserMenuAction>(
      _BrowserMenuRoute(
        buttonRect: buttonRect,
        onSelected: onSelected,
        isDark: theme.brightness == Brightness.dark,
        colorScheme: theme.colorScheme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m3Sm),
        onTap: () => show(ctx, onSelected: onSelected),
        child: child,
      ),
    );
  }
}

class _BrowserMenuRoute extends PopupRoute<BrowserMenuAction> {
  final Rect buttonRect;
  final ValueChanged<BrowserMenuAction> onSelected;
  final bool isDark;
  final ColorScheme colorScheme;

  _BrowserMenuRoute({
    required this.buttonRect,
    required this.onSelected,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.15);
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Dismiss menu';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final size = MediaQuery.sizeOf(context);
    const menuWidth = 224.0;
    const rightMargin = 12.0;
    final menuLeft = (size.width - rightMargin - menuWidth).clamp(0.0, size.width);
    final originX = ((buttonRect.center.dx - menuLeft) / menuWidth).clamp(0.0, 1.0);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      ),
      child: ScaleTransition(
        alignment: Alignment(originX * 2 - 1, 1.0),
        scale: Tween<double>(begin: 0.15, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: AppMotion.spring,
            reverseCurve: Curves.easeInCubic,
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        Positioned(
          bottom: size.height - buttonRect.top + 8.0,
          right: 12.0,
          width: 224.0,
          child: _BrowserMenuCard(
            isDark: isDark,
            colorScheme: colorScheme,
            onAction: (a) {
              Navigator.of(context).pop();
              onSelected(a);
            },
          ),
        ),
      ],
    );
  }
}

class _BrowserMenuCard extends StatelessWidget {
  final bool isDark;
  final ColorScheme colorScheme;
  final ValueChanged<BrowserMenuAction> onAction;

  const _BrowserMenuCard({
    required this.isDark,
    required this.colorScheme,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B26) : const Color(0xFFFFFFFF);
    final border = isDark
        ? const Color(0xFF263042)
        : colorScheme.outlineVariant.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.m3Lg),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildItem(BrowserMenuAction.findInPage),
            Divider(height: 1, thickness: 1, color: border),
            for (final a in const [
              BrowserMenuAction.history,
              BrowserMenuAction.bookmarks,
              BrowserMenuAction.downloadManager,
            ])
              _buildItem(a),
            Divider(height: 1, thickness: 1, color: border),
            _buildItem(BrowserMenuAction.settings),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BrowserMenuAction action) {
    return InkWell(
      onTap: () => onAction(action),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          child: Row(
            children: [
              Icon(action.icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  action.label,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backwards-compatibility alias.
typedef BrowserOverflowMenu = BrowserMenuPopup;
