import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/browser_page_error.dart';

/// Full-page error view matching the app's monochrome/slate aesthetic.
class BrowserErrorView extends StatefulWidget {
  final BrowserPageError error;
  final VoidCallback onReload;
  final VoidCallback onGoHome;
  final VoidCallback? onProceedAnyway;

  const BrowserErrorView({
    super.key,
    required this.error,
    required this.onReload,
    required this.onGoHome,
    this.onProceedAnyway,
  });

  @override
  State<BrowserErrorView> createState() => _BrowserErrorViewState();
}

class _BrowserErrorViewState extends State<BrowserErrorView> {
  bool _showAdvanced = false;

  IconData _pickIcon() {
    switch (widget.error.errorKey) {
      case 'OFFLINE':
        return PhosphorIcons.wifiSlash;
      case 'NET_TIMEOUT':
        return PhosphorIcons.clockCountdown;
      case 'SECURITY_SSL':
      case 'SECURITY_BAD_CERT':
      case 'HTTPS_ONLY':
      case 'BAD_HSTS_CERT':
      case 'SAFEBROWSING':
        return PhosphorIcons.shieldWarning;
      case 'MALFORMED_URI':
      case 'UNSUPPORTED_PROTOCOL':
        return PhosphorIcons.linkBreak;
      default:
        return PhosphorIcons.warningCircle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF131722) : Colors.white;
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final badgeBg = isDark ? const Color(0xFF1A2130) : const Color(0xFFEEF2F6);
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final canProceedAnyway = widget.error.isSecurityError && widget.onProceedAnyway != null;

    return Container(
      color: bg,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_pickIcon(), size: 38, color: fg),
                ),
                const SizedBox(height: 22),
                Text(
                  widget.error.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.error.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, height: 1.5, color: muted),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DETAILS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.error.uri.isNotEmpty) ...[
                        Text(
                          widget.error.uri,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: fg),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        widget.error.errorCodeLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: widget.onReload,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                      foregroundColor: isDark ? const Color(0xFF0C0E14) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(PhosphorIcons.arrowClockwise, size: 18),
                    label: const Text('Reload', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: widget.onGoHome,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fg,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Back to Home', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (canProceedAnyway) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                    icon: Icon(
                      _showAdvanced ? PhosphorIcons.caretUp : PhosphorIcons.caretDown,
                      size: 14,
                      color: muted,
                    ),
                    label: Text(
                      _showAdvanced ? 'Hide advanced' : 'Advanced',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                    ),
                  ),
                  if (_showAdvanced) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your connection to ${widget.error.host} is not private. Attackers or network intermediaries may be able to see or modify data sent on this connection.',
                            style: TextStyle(fontSize: 12.5, height: 1.45, color: muted),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: widget.onProceedAnyway,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Proceed anyway (unsafe)',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
