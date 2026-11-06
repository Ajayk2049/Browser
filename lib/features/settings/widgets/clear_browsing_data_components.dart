import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

enum ClearTimeRange {
  lastHour('Last hour', Duration(hours: 1)),
  last24Hours('Last 24 hours', Duration(hours: 24)),
  last7Days('Last 7 days', Duration(days: 7)),
  last4Weeks('Last 4 weeks', Duration(days: 28)),
  allTime('All time', null);

  final String label;
  final Duration? duration;
  const ClearTimeRange(this.label, this.duration);
}

/// Modal bottom sheet allowing selection of clear data time range.
class TimeRangePickerSheet {
  static Future<ClearTimeRange?> show(BuildContext context, ClearTimeRange selected, bool isDark) {
    return showModalBottomSheet<ClearTimeRange>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131722) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ClearTimeRange.values.map((range) {
                final isSelected = range == selected;
                return ListTile(
                  title: Text(
                    range.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          PhosphorIcons.check,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(range),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Row item in the clear data group card.
class ClearDataRowItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final bool showDivider;

  const ClearDataRowItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconBoxBg = isDark ? const Color(0xFF1A2130) : const Color(0xFFF1F5F9);
    final dividerColor = isDark ? const Color(0xFF1A202E) : const Color(0xFFF1F5F9);

    return Column(
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(18.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                Container(
                  width: 38.0,
                  height: 38.0,
                  decoration: BoxDecoration(
                    color: iconBoxBg,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20.0, color: primaryTextColor),
                ),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.0,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCheckbox(value, isDark),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1.0, thickness: 1.0, color: dividerColor, indent: 68.0),
      ],
    );
  }

  Widget _buildCheckbox(bool isChecked, bool isDark) {
    final borderColor = isDark ? const Color(0xFF272E3F) : const Color(0xFFCBD5E1);
    final checkedBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final checkmarkColor = isDark ? const Color(0xFF0C0E14) : Colors.white;

    return Container(
      width: 22.0,
      height: 22.0,
      decoration: BoxDecoration(
        color: isChecked ? checkedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isChecked ? checkedBg : borderColor,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: isChecked
          ? Icon(PhosphorIcons.check, size: 14.0, color: checkmarkColor)
          : null,
    );
  }
}

