import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../../downloads/downloads.dart';

class DetectedMedia {
  final String url;
  final String title;
  final String type; // 'video' | 'audio' | 'stream'

  const DetectedMedia({
    required this.url,
    required this.title,
    required this.type,
  });
}

/// 1DM+-style Media Sniffer bottom sheet.
/// Complies with rules.md §25.1, §25.2, §25.7, and §29.2 (< 200 lines).
class MediaGrabberSheet extends StatelessWidget {
  final List<DetectedMedia> items;

  const MediaGrabberSheet({super.key, required this.items});

  Future<void> _startDownload(BuildContext context, DetectedMedia media) async {
    Navigator.pop(context);
    final uri = Uri.tryParse(media.url);
    final rawName = uri?.pathSegments.lastOrNull ?? media.title;
    final fileName = rawName.isNotEmpty ? rawName : 'media_${DateTime.now().millisecondsSinceEpoch}';

    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/$fileName';
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();

    await DownloadService().startDownload(
      taskId: taskId,
      url: media.url,
      destinationPath: destPath,
      segmentsCount: 8,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $fileName...'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.push('/downloads'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.broadcast, color: colorScheme.primary, size: 24),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'Detected Media (${items.length})',
                style: AppTypography.displaySm.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Tap any media stream to capture with high-speed 8-threaded downloader',
            style: AppTypography.bodySm.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x4),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
              itemBuilder: (context, index) {
                final item = items[index];
                final icon = item.type == 'audio' ? PhosphorIcons.musicNotes : PhosphorIcons.video;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.x3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: colorScheme.primary, size: 24),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              Uri.tryParse(item.url)?.host ?? item.url,
                              style: AppTypography.bodyXs.copyWith(color: colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      FilledButton.tonalIcon(
                        onPressed: () => _startDownload(context, item),
                        icon: Icon(PhosphorIcons.downloadSimple, size: 18),
                        label: const Text('Grab'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

