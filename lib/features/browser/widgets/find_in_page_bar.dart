import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';

/// Safari-style solid find-in-page toolbar matching Dab Browser design tokens.
/// Complies with rules.md §13, §29.2 (< 250 lines).
class FindInPageBar extends StatefulWidget {
  final int currentMatch;
  final int totalMatches;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  const FindInPageBar({
    super.key,
    required this.currentMatch,
    required this.totalMatches,
    required this.onQueryChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });

  @override
  State<FindInPageBar> createState() => _FindInPageBarState();
}

class _FindInPageBarState extends State<FindInPageBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      widget.onQueryChanged(text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = const Color(0xFF64748B);
    final hasMatches = widget.totalMatches > 0;
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      height: 50.0,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.m3Lg),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 25),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.magnifyingGlass, size: 18.0, color: secondaryTextColor),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _handleChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => widget.onNext(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                color: primaryTextColor,
              ),
              decoration: const InputDecoration(
                hintText: 'Find in page',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (hasQuery) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                hasMatches ? '${widget.currentMatch} of ${widget.totalMatches}' : 'No matches',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: hasMatches ? secondaryTextColor : const Color(0xFFEF4444),
                ),
              ),
            ),
            const SizedBox(width: 4.0),
            _buildNavButton(
              icon: PhosphorIcons.caretUp,
              enabled: hasMatches,
              onTap: widget.onPrevious,
              color: primaryTextColor,
              disabledColor: borderColor,
            ),
            _buildNavButton(
              icon: PhosphorIcons.caretDown,
              enabled: hasMatches,
              onTap: widget.onNext,
              color: primaryTextColor,
              disabledColor: borderColor,
            ),
            const SizedBox(width: 6.0),
          ],
          Container(
            width: 1.0,
            height: 24.0,
            color: borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
          ),
          InkWell(
            onTap: widget.onClose,
            borderRadius: BorderRadius.circular(8.0),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Text(
                'Done',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required Color color,
    required Color disabledColor,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6.0),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(
          icon,
          size: 18.0,
          color: enabled ? color : disabledColor,
        ),
      ),
    );
  }
}

