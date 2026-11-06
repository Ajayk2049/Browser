import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../browser/services/history_service.dart';
import '../widgets/clear_browsing_data_components.dart';
import '../widgets/settings_app_bar.dart';

/// Screen allowing users to purge history, cookies, and cache (Figma 2659 Dark / 2726 Light).
/// Complies with rules.md §13, §29.2 (< 300 lines).
class ClearBrowsingDataScreen extends StatefulWidget {
  const ClearBrowsingDataScreen({super.key});

  @override
  State<ClearBrowsingDataScreen> createState() => _ClearBrowsingDataScreenState();
}

class _ClearBrowsingDataScreenState extends State<ClearBrowsingDataScreen> {
  static const _channel = MethodChannel('com.dab/downloader');

  ClearTimeRange _selectedTimeRange = ClearTimeRange.allTime;
  bool _clearHistory = true;
  bool _clearCookies = true;
  bool _clearCache = true;
  bool _clearPasswords = false;

  int _cacheSizeBytes = 0;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _fetchCacheSize();
  }

  Future<void> _fetchCacheSize() async {
    try {
      final size = await _channel.invokeMethod<num>('getCacheSize');
      if (mounted) {
        setState(() {
          _cacheSizeBytes = size?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _executeClearData() async {
    if (!_clearHistory && !_clearCookies && !_clearCache && !_clearPasswords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item to clear')),
      );
      return;
    }

    setState(() => _isClearing = true);

    try {
      if (_clearHistory) {
        await HistoryService.instance.clearHistory(
          timeRangeDuration: _selectedTimeRange.duration,
        );
      }

      await _channel.invokeMethod('clearBrowsingData', {
        'clearCookies': _clearCookies,
        'clearCache': _clearCache,
        'clearPasswords': _clearPasswords,
      });

      await _fetchCacheSize();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Browsing data cleared'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _pickTimeRange(bool isDark) async {
    final range = await TimeRangePickerSheet.show(context, _selectedTimeRange, isDark);
    if (range != null && mounted) {
      setState(() => _selectedTimeRange = range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final headerColor = const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: SettingsAppBar(
        title: 'Clear Browsing Data',
        showSearch: false,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
        children: [
          // 1. TIME RANGE
          _buildSectionHeader('TIME RANGE', headerColor),
          GestureDetector(
            onTap: () => _pickTimeRange(isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18.0),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time range',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _selectedTimeRange.label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.0,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      const Icon(PhosphorIcons.caretDown, size: 14.0, color: Color(0xFF64748B)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24.0),

          // 2. DATA TO CLEAR
          _buildSectionHeader('DATA TO CLEAR', headerColor),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Column(
              children: [
                ClearDataRowItem(
                  icon: PhosphorIcons.clockCounterClockwise,
                  title: 'Browsing history',
                  subtitle: 'Clears history and autocompletions',
                  value: _clearHistory,
                  onChanged: (v) => setState(() => _clearHistory = v),
                  isDark: isDark,
                  showDivider: true,
                ),
                ClearDataRowItem(
                  icon: PhosphorIcons.cookie,
                  title: 'Cookies & site data',
                  subtitle: 'Signs you out of most websites',
                  value: _clearCookies,
                  onChanged: (v) => setState(() => _clearCookies = v),
                  isDark: isDark,
                  showDivider: true,
                ),
                ClearDataRowItem(
                  icon: PhosphorIcons.lightning,
                  title: 'Cached images & files',
                  subtitle: 'Frees up ${_formatBytes(_cacheSizeBytes)} of storage',
                  value: _clearCache,
                  onChanged: (v) => setState(() => _clearCache = v),
                  isDark: isDark,
                  showDivider: true,
                ),
                ClearDataRowItem(
                  icon: PhosphorIcons.key,
                  title: 'Saved passwords',
                  subtitle: 'None saved',
                  value: _clearPasswords,
                  onChanged: (v) => setState(() => _clearPasswords = v),
                  isDark: isDark,
                  showDivider: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32.0),

          // 3. CLEAR DATA BUTTON
          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton(
              onPressed: _isClearing ? null : _executeClearData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: _isClearing
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                    )
                  : const Text(
                      'Clear Data',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
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
