import 'package:flutter/material.dart';

/// Segment state for multi-part downloads
enum ChunkState { pending, downloading, completed, failed }

class ChunkInfo {
  final int index;
  final int startByte;
  final int endByte;
  final int downloadedBytes;
  final ChunkState state;

  const ChunkInfo({
    required this.index,
    required this.startByte,
    required this.endByte,
    required this.downloadedBytes,
    this.state = ChunkState.pending,
  });

  double get progress {
    final total = endByte - startByte + 1;
    if (total <= 0) return 0.0;
    return (downloadedBytes / total).clamp(0.0, 1.0);
  }
}

/// Visualizer widget showing individual partition bars and byte range distribution
/// modeled directly after 1DM+'s multi-part chunk view.
class MultiPartChunkVisualizer extends StatelessWidget {
  final List<ChunkInfo> chunks;
  final int totalBytes;
  final double currentSpeedKbps;

  const MultiPartChunkVisualizer({
    super.key,
    required this.chunks,
    required this.totalBytes,
    this.currentSpeedKbps = 0.0,
  });

  Color _stateColor(ChunkState state) {
    switch (state) {
      case ChunkState.pending:
        return Colors.white24;
      case ChunkState.downloading:
        return const Color(0xFF64B5F6);
      case ChunkState.completed:
        return const Color(0xFF81C784);
      case ChunkState.failed:
        return const Color(0xFFE57373);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E232A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Partition Threads (${chunks.length} parts)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '${currentSpeedKbps.toStringAsFixed(1)} KB/s',
                style: const TextStyle(
                  color: Color(0xFF64B5F6),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stacked horizontal segments representing byte boundaries
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 12,
              child: Row(
                children: chunks.map((chunk) {
                  final partWeight = (chunk.endByte - chunk.startByte + 1).toDouble();
                  return Expanded(
                    flex: partWeight > 0 ? partWeight.toInt() : 1,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      color: _stateColor(chunk.state),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Detailed list of thread segments
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: chunks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final c = chunks[index];
              return Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Text(
                      'Part #${c.index + 1}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: c.progress,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(_stateColor(c.state)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 45,
                    child: Text(
                      '${(c.progress * 100).toInt()}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
