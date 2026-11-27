import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/browser_context_element.dart';

/// Actions available when long-pressing links, images, or media in a webpage.
enum BrowserContextAction {
  openInNewTab,
  openInPrivateTab,
  copyLinkAddress,
  copyLinkText,
  downloadLink,
  shareLink,
  openMediaInNewTab,
  saveMedia,
  copyMediaAddress,
  shareMedia,
}

/// Monochrome modal bottom sheet for long-press context menus on links & media.
class BrowserContextMenuSheet extends StatelessWidget {
  final BrowserContextElement element;
  final bool isPrivateMode;

  const BrowserContextMenuSheet({
    super.key,
    required this.element,
    this.isPrivateMode = false,
  });

  static Future<BrowserContextAction?> show(
    BuildContext context, {
    required BrowserContextElement element,
    bool isPrivateMode = false,
  }) {
    return showModalBottomSheet<BrowserContextAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BrowserContextMenuSheet(
        element: element,
        isPrivateMode: isPrivateMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0C0E14) : cs.surface;
    final cardBg = isDark ? const Color(0xFF131722) : cs.surfaceContainerLowest;
    final borderColor = isDark ? const Color(0xFF1E2433) : cs.outlineVariant.withValues(alpha: 0.45);
    final mediaLabel = switch (element.mediaType) {
      BrowserContextMediaType.image => 'image',
      BrowserContextMediaType.video => 'video',
      BrowserContextMediaType.audio => 'audio',
      BrowserContextMediaType.none => 'media',
    };

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.m3Xl)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x3, AppSpacing.x4, AppSpacing.x4),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              _HeaderCard(element: element, cardBg: cardBg, borderColor: borderColor),
              const SizedBox(height: AppSpacing.x3),
              if (element.hasLink) ...[
                _ActionGroup(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    _ActionTile(
                      icon: PhosphorIcons.plusSquare,
                      label: isPrivateMode ? 'Open in new private tab' : 'Open in new tab',
                      onTap: () => Navigator.pop(context, BrowserContextAction.openInNewTab),
                    ),
                    if (!isPrivateMode)
                      _ActionTile(
                        icon: PhosphorIcons.eyeglasses,
                        label: 'Open in private tab',
                        onTap: () => Navigator.pop(context, BrowserContextAction.openInPrivateTab),
                      ),
                    _ActionTile(
                      icon: PhosphorIcons.copy,
                      label: 'Copy link address',
                      onTap: () => Navigator.pop(context, BrowserContextAction.copyLinkAddress),
                    ),
                    if (element.textContent.trim().isNotEmpty)
                      _ActionTile(
                        icon: PhosphorIcons.textT,
                        label: 'Copy link text',
                        onTap: () => Navigator.pop(context, BrowserContextAction.copyLinkText),
                      ),
                    _ActionTile(
                      icon: PhosphorIcons.downloadSimple,
                      label: 'Download link',
                      onTap: () => Navigator.pop(context, BrowserContextAction.downloadLink),
                    ),
                    _ActionTile(
                      icon: PhosphorIcons.shareNetwork,
                      label: 'Share link',
                      onTap: () => Navigator.pop(context, BrowserContextAction.shareLink),
                    ),
                  ],
                ),
                if (element.hasMedia) const SizedBox(height: AppSpacing.x3),
              ],
              if (element.hasMedia)
                _ActionGroup(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    _ActionTile(
                      icon: PhosphorIcons.arrowSquareOut,
                      label: 'Open $mediaLabel in new tab',
                      onTap: () => Navigator.pop(context, BrowserContextAction.openMediaInNewTab),
                    ),
                    _ActionTile(
                      icon: PhosphorIcons.floppyDisk,
                      label: 'Save $mediaLabel',
                      onTap: () => Navigator.pop(context, BrowserContextAction.saveMedia),
                    ),
                    _ActionTile(
                      icon: PhosphorIcons.linkSimple,
                      label: 'Copy $mediaLabel address',
                      onTap: () => Navigator.pop(context, BrowserContextAction.copyMediaAddress),
                    ),
                    _ActionTile(
                      icon: PhosphorIcons.shareNetwork,
                      label: 'Share $mediaLabel',
                      onTap: () => Navigator.pop(context, BrowserContextAction.shareMedia),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final BrowserContextElement element;
  final Color cardBg;
  final Color borderColor;

  const _HeaderCard({required this.element, required this.cardBg, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showNetworkThumb = element.isImage &&
        (element.srcUri.startsWith('http://') || element.srcUri.startsWith('https://'));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.m3Sm),
            child: Container(
              width: 44,
              height: 44,
              color: cs.surfaceContainerHighest,
              child: showNetworkThumb
                  ? Image.network(
                      element.srcUri,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(_fallbackIcon(), size: 22, color: cs.onSurfaceVariant),
                    )
                  : Icon(_fallbackIcon(), size: 22, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  element.displayTitle,
                  style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  element.primaryUrl,
                  style: AppTypography.bodyXs.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _fallbackIcon() {
    return switch (element.mediaType) {
      BrowserContextMediaType.image => PhosphorIcons.image,
      BrowserContextMediaType.video => PhosphorIcons.filmStrip,
      BrowserContextMediaType.audio => PhosphorIcons.musicNote,
      BrowserContextMediaType.none => PhosphorIcons.link,
    };
  }
}

class _ActionGroup extends StatelessWidget {
  final Color cardBg;
  final Color borderColor;
  final List<Widget> children;

  const _ActionGroup({required this.cardBg, required this.borderColor, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(height: 1, thickness: 1, color: borderColor.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
