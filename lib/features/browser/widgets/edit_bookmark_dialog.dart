import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/home_content_item.dart';

/// Modal dialog for editing a single bookmark's title and URL.
/// Complies with rules.md §13, §29.2 (< 200 lines).
class EditBookmarkDialog extends StatefulWidget {
  final BookmarkItem item;
  final List<BookmarkFolder> folders;
  final void Function(String title, String url, String folderId) onSave;

  const EditBookmarkDialog({
    super.key,
    required this.item,
    required this.folders,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required BookmarkItem item,
    required List<BookmarkFolder> folders,
    required void Function(String title, String url, String folderId) onSave,
  }) =>
      showDialog(
        context: context,
        builder: (_) => EditBookmarkDialog(item: item, folders: folders, onSave: onSave),
      );

  @override
  State<EditBookmarkDialog> createState() => _EditBookmarkDialogState();
}

class _EditBookmarkDialogState extends State<EditBookmarkDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late String _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title);
    _urlCtrl = TextEditingController(text: widget.item.url);
    _selectedFolderId = widget.item.folderId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Bookmark'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'URL')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: widget.folders.any((f) => f.id == _selectedFolderId) ? _selectedFolderId : (widget.folders.isNotEmpty ? widget.folders.first.id : 'all_bookmarks'),
              decoration: const InputDecoration(labelText: 'Folder'),
              items: [
                for (final f in widget.folders) DropdownMenuItem(value: f.id, child: Text(f.title)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedFolderId = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final t = _titleCtrl.text.trim();
            final u = _urlCtrl.text.trim();
            if (t.isNotEmpty && u.isNotEmpty) widget.onSave(t, u, _selectedFolderId);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Helper methods for bookmark folder management dialogs.
class BookmarkFolderDialogs {
  static void showCreate(BuildContext context, ValueChanged<String> onCreate) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Folder Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) onCreate(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  static void showEdit(BuildContext context, BookmarkFolder folder, ValueChanged<String> onSave) {
    final ctrl = TextEditingController(text: folder.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Folder Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) onSave(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static void confirmDelete(BuildContext context, BookmarkFolder folder, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${folder.title}"?'),
        content: const Text('Bookmarks inside this folder will be moved to All Bookmarks.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              onDelete();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
