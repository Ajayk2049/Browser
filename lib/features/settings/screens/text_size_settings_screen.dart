import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/appearance_settings_service.dart';

/// Screen for adjusting web and reader font size factor (Figma 2581 Dark / 2620 Light).
/// Complies with rules.md §13, §29.2 (< 300 lines).
class TextSizeSettingsScreen extends StatefulWidget {
  const TextSizeSettingsScreen({super.key});

  @override
  State<TextSizeSettingsScreen> createState() => _TextSizeSettingsScreenState();
}

class _TextSizeSettingsScreenState extends State<TextSizeSettingsScreen> {
  late double _currentPercent;

  @override
  void initState() {
    super.initState();
    _currentPercent = AppearanceSettingsService.instance.textZoomPercent.toDouble();
  }

  void _onSave() async {
    final percent = _currentPercent.round();
    await AppearanceSettingsService.instance.setTextZoomPercent(percent);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Font size updated to $percent%'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final headerColor = const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeTrackColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inactiveTrackColor = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);

    final scaleFactor = _currentPercent / 100.0;
    final roundedPercent = _currentPercent.round();
    final percentLabel = '$roundedPercent%${roundedPercent == 100 ? ' (Default)' : ''}';

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: SafeArea(
          child: Container(
            height: 60.0,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildBackButton(context, isDark),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Text Size',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                _buildSaveButton(primaryTextColor),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
        children: [
          // 1. PREVIEW
          _buildSectionHeader('PREVIEW', headerColor),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make text easier to read',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18.0 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Drag the slider below to customize the font size across web pages and reader mode. Text preview scales in real-time.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.0 * scaleFactor,
                    fontWeight: FontWeight.normal,
                    height: 1.4,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24.0),

          // 2. FONT SIZE SLIDER
          _buildSectionHeader('FONT SIZE', headerColor),
          Container(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'A',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      percentLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                    Text(
                      'A',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6.0,
                    activeTrackColor: activeTrackColor,
                    inactiveTrackColor: inactiveTrackColor,
                    thumbColor: activeTrackColor,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12.0,
                      elevation: 3.0,
                    ),
                    overlayColor: activeTrackColor.withAlpha(30),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                  ),
                  child: Slider(
                    value: _currentPercent,
                    min: 50.0,
                    max: 200.0,
                    divisions: 30, // 5% steps
                    onChanged: (val) {
                      setState(() {
                        _currentPercent = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 36.0,
        height: 36.0,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B26) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          PhosphorIcons.caretLeft,
          size: 18.0,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildSaveButton(Color textColor) {
    return GestureDetector(
      onTap: _onSave,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        child: Text(
          'Save',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

