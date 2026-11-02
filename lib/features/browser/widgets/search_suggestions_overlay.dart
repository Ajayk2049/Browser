import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_typography.dart';
import '../services/search_suggestions_service.dart';

/// Floating autocomplete overlay matching the modern card design.
/// Complies with rules.md §13, §29.2 (< 200 lines).
class SearchSuggestionsOverlay extends StatelessWidget {
  final List<SearchSuggestionItem> suggestions;
  final ValueChanged<String> onSelectSuggestion;

  const SearchSuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.onSelectSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final divider = isDark ? const Color(0xFF1A202E) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 16.0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < suggestions.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: divider),
                _buildRow(suggestions[i], textColor, subColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(SearchSuggestionItem item, Color textColor, Color subColor) {
    return InkWell(
      onTap: () => onSelectSuggestion(item.isUrl && item.subtitle != null ? item.subtitle! : item.text),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(item.isUrl ? PhosphorIcons.globe : PhosphorIcons.magnifyingGlass, size: 18.0, color: subColor),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.text, style: AppTypography.bodySm.copyWith(color: textColor, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2.0),
                    Text(item.subtitle!, style: AppTypography.bodyXs.copyWith(color: subColor, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Icon(PhosphorIcons.arrowUpLeft, size: 16.0, color: subColor.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
