import 'package:flutter/material.dart';

enum TorrentFilePriority { ignore, low, normal, high }

class TorrentInnerFile {
  final int index;
  final String path;
  final int sizeBytes;
  final double progress;
  final TorrentFilePriority priority;

  const TorrentInnerFile({
    required this.index,
    required this.path,
    required this.sizeBytes,
    this.progress = 0.0,
    this.priority = TorrentFilePriority.normal,
  });

  String get formattedSize {
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    if (sizeBytes >= gb) return '${(sizeBytes / gb).toStringAsFixed(2)} GB';
    if (sizeBytes >= mb) return '${(sizeBytes / mb).toStringAsFixed(2)} MB';
    if (sizeBytes >= kb) return '${(sizeBytes / kb).toStringAsFixed(1)} KB';
    return '$sizeBytes B';
  }
}

class TorrentMetadata {
  final String name;
  final String infoHash;
  final int totalSizeBytes;
  final int pieceLength;
  final int pieceCount;
  final int seeders;
  final int leechers;
  final List<String> trackers;
  final List<TorrentInnerFile> files;
  final bool isSequential;

  const TorrentMetadata({
    required this.name,
    required this.infoHash,
    required this.totalSizeBytes,
    required this.pieceLength,
    required this.pieceCount,
    this.seeders = 0,
    this.leechers = 0,
    this.trackers = const [],
    this.files = const [],
    this.isSequential = false,
  });

  String get formattedTotalSize {
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    if (totalSizeBytes >= gb) return '${(totalSizeBytes / gb).toStringAsFixed(2)} GB';
    if (totalSizeBytes >= mb) return '${(totalSizeBytes / mb).toStringAsFixed(2)} MB';
    if (totalSizeBytes >= kb) return '${(totalSizeBytes / kb).toStringAsFixed(1)} KB';
    return '$totalSizeBytes B';
  }
}

/// A comprehensive Torrent Inspection Sheet widget modeled directly after 1DM+'s
/// torrent inspection dialog (`com.aspsine.multithreaddownload.Torrent` & `com.frostwire.jlibtorrent`).
class TorrentInspectorSheet extends StatefulWidget {
  final TorrentMetadata metadata;
  final ValueChanged<bool>? onSequentialToggle;
  final Function(int fileIndex, TorrentFilePriority newPriority)? onPriorityChanged;
  final VoidCallback? onStartDownload;

  const TorrentInspectorSheet({
    super.key,
    required this.metadata,
    this.onSequentialToggle,
    this.onPriorityChanged,
    this.onStartDownload,
  });

  static void show(
    BuildContext context, {
    required TorrentMetadata metadata,
    ValueChanged<bool>? onSequentialToggle,
    Function(int fileIndex, TorrentFilePriority newPriority)? onPriorityChanged,
    VoidCallback? onStartDownload,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TorrentInspectorSheet(
        metadata: metadata,
        onSequentialToggle: onSequentialToggle,
        onPriorityChanged: onPriorityChanged,
        onStartDownload: onStartDownload,
      ),
    );
  }

  @override
  State<TorrentInspectorSheet> createState() => _TorrentInspectorSheetState();
}

class _TorrentInspectorSheetState extends State<TorrentInspectorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _sequential;
  late List<TorrentInnerFile> _files;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _sequential = widget.metadata.isSequential;
    _files = List.from(widget.metadata.files);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF14171C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Torrent Title and Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.share, color: Color(0xFF64B5F6), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.metadata.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.metadata.formattedTotalSize} • ${widget.metadata.files.length} files • ${widget.metadata.seeders} seeds / ${widget.metadata.leechers} peers',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tab bar: Files, Details, Trackers
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF1E88E5),
            labelColor: const Color(0xFF64B5F6),
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Files List'),
              Tab(text: 'Swarm & Info'),
              Tab(text: 'Trackers'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFilesTab(),
                _buildDetailsTab(),
                _buildTrackersTab(),
              ],
            ),
          ),
          // Bottom Bar with Download button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1B2028),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Switch(
                  value: _sequential,
                  activeColor: const Color(0xFF64B5F6),
                  onChanged: (val) {
                    setState(() => _sequential = val);
                    widget.onSequentialToggle?.call(val);
                  },
                ),
                const Text(
                  'Sequential (Stream)',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Add Torrent', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    widget.onStartDownload?.call();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _files.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final f = _files[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E232A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Checkbox(
                value: f.priority != TorrentFilePriority.ignore,
                activeColor: const Color(0xFF1E88E5),
                onChanged: (val) {
                  final newPri = (val ?? false)
                      ? TorrentFilePriority.normal
                      : TorrentFilePriority.ignore;
                  setState(() {
                    _files[idx] = TorrentInnerFile(
                      index: f.index,
                      path: f.path,
                      sizeBytes: f.sizeBytes,
                      progress: f.progress,
                      priority: newPri,
                    );
                  });
                  widget.onPriorityChanged?.call(f.index, newPri);
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f.formattedSize,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              DropdownButton<TorrentFilePriority>(
                value: f.priority,
                dropdownColor: const Color(0xFF262C36),
                underline: const SizedBox(),
                items: TorrentFilePriority.values.map((pri) {
                  return DropdownMenuItem(
                    value: pri,
                    child: Text(
                      pri.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: pri == TorrentFilePriority.ignore
                            ? Colors.redAccent
                            : Colors.white70,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newPri) {
                  if (newPri == null) return;
                  setState(() {
                    _files[idx] = TorrentInnerFile(
                      index: f.index,
                      path: f.path,
                      sizeBytes: f.sizeBytes,
                      progress: f.progress,
                      priority: newPri,
                    );
                  });
                  widget.onPriorityChanged?.call(f.index, newPri);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoRow('Info Hash', widget.metadata.infoHash),
        _infoRow('Total Size', widget.metadata.formattedTotalSize),
        _infoRow('Piece Length', '${(widget.metadata.pieceLength / 1024).toInt()} KB'),
        _infoRow('Total Pieces', widget.metadata.pieceCount.toString()),
        _infoRow('Seeders (Seeds)', widget.metadata.seeders.toString()),
        _infoRow('Leechers (Peers)', widget.metadata.leechers.toString()),
        _infoRow('Engine Backend', 'jlibtorrent 1.2.19 (libtorrent-rasterbar)'),
      ],
    );
  }

  Widget _buildTrackersTab() {
    if (widget.metadata.trackers.isEmpty) {
      return const Center(
        child: Text('No trackers found (DHT & PeX enabled)', style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: widget.metadata.trackers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, idx) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E232A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            widget.metadata.trackers[idx],
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
