import 'package:flutter/material.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_typography.dart';

/// Tab counter that replaces the old downloads shortcut in the omnibox toolbar.
///
/// A compact square outline holding the open-tab count — the affordance every
/// mobile browser uses, so it needs no label. Tapping it opens the tabs sheet.
///
/// The visible chip is deliberately smaller than the omnibox pill (36 dp inside
/// a 44 dp tap target). A full-height outlined square reads heavier than the
/// neighbouring icons and looks misaligned even when the boxes match, so the
/// chip is inset and its outline is kept light.
class BrowserTabsButton extends StatelessWidget {
  /// Visual size of the outlined chip.
  static const double _chipSize = 36;

  /// Minimum touch target, matching the omnibox pill height.
  static const double _tapSize = 44;

  final int tabCount;
  final VoidCallback onPressed;

  const BrowserTabsButton({
    super.key,
    required this.tabCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tabCount == 1 ? '1 tab' : '$tabCount tabs',
      child: SizedBox(
        width: _tapSize,
        height: _tapSize,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.m3Md),
          child: Center(
            child: Container(
              width: _chipSize,
              height: _chipSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.m3Md),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.4,
                ),
              ),
              child: Text(
                '$tabCount',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
