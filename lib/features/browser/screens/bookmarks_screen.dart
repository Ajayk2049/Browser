import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_typography.dart';
import '../../settings/widgets/settings_app_bar.dart';
import '../models/home_content_item.dart';
import '../services/bookmarks_service.dart';
import '../widgets/bookmark_row_item.dart';
import '../widgets/edit_bookmark_dialog.dart';

/// Bookmarks screen matching Instagram saved collections UI:
/// Top section shows folders (with permanent 'All' folder + user folders).
/// Bottom section displays all saved content, or filters when a specific folder is tapped.
/// Complies with rules.md §13, §29.2 (< 300 lines).
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _debouncedQuery = '';
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  String _selectedFolderId = 'all';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
          if (_selectedIds.isEmpty) _isSelectionMode = false;
        } else {
          _selectedIds.add(id);
          _isSelectionMode = true;
        }
      });

  void _selectAll(List<BookmarkItem> items) => setState(() {
        if (_selectedIds.length == items.length) {
          _selectedIds.clear();
          _isSelectionMode = false;
        } else {
          _selectedIds.addAll(items.map((i) => i.id));
          _isSelectionMode = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    const headerColor = Color(0xFF64748B);
    final service = BookmarksService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final query = _debouncedQuery;
        final selectedFolder = service.folders.firstWhere((f) => f.id == _selectedFolderId, orElse: () => BookmarksService.allFolder);
        final filteredItems = service.bookmarks.where((b) {
          final matchesFolder = _selectedFolderId == 'all' || b.folderId == _selectedFolderId;
          final matchesQuery = query.isEmpty || b.title.toLowerCase().contains(query) || b.url.toLowerCase().contains(query);
          return matchesFolder && matchesQuery;
        }).toList();

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: _isSelectionMode
              ? AppBar(
                  backgroundColor: scaffoldBg,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(PhosphorIcons.x, size: 20),
                    onPressed: () => setState(() {
                      _selectedIds.clear();
                      _isSelectionMode = false;
                    }),
                  ),
                  title: Text('${_selectedIds.length} selected', style: AppTypography.displaySm.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
                  actions: [
                    TextButton(
                      onPressed: () => _selectAll(filteredItems),
                      child: Text(_selectedIds.length == filteredItems.length ? 'Deselect all' : 'Select all', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                    ),
                  ],
                )
              : SettingsAppBar(
                  title: 'Bookmarks',
                  showSearch: false,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchPill(isDark),
                      const SizedBox(height: 16.0),
                      if (query.isEmpty) ...[
                        _buildSectionHeader('FOLDERS', headerColor, action: 'New folder', onAction: () => BookmarkFolderDialogs.showCreate(context, service.addFolder), isDark: isDark),
                        const SizedBox(height: 8.0),
                        _buildCardContainer(
                          isDark,
                          children: [
                            for (int i = 0; i < service.folders.length; i++) ...[
                              if (i > 0) _buildDivider(isDark),
                              BookmarkFolderRow(
                                folder: service.folders[i],
                                count: service.getBookmarkCountForFolder(service.folders[i].id),
                                isSelected: _selectedFolderId == service.folders[i].id,
                                isDark: isDark,
                                onTap: () => setState(() => _selectedFolderId = service.folders[i].id),
                                onEdit: () => BookmarkFolderDialogs.showEdit(context, service.folders[i], (t) => service.updateFolder(service.folders[i].id, t)),
                                onDelete: () => BookmarkFolderDialogs.confirmDelete(context, service.folders[i], () {
                                  if (_selectedFolderId == service.folders[i].id) _selectedFolderId = 'all';
                                  service.deleteFolder(service.folders[i].id);
                                }),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20.0),
                      ],
                      _buildSectionHeader(
                        _selectedFolderId == 'all' ? 'ALL SAVED (${filteredItems.length})' : '${selectedFolder.title.toUpperCase()} (${filteredItems.length})',
                        headerColor,
                        action: filteredItems.isNotEmpty && !_isSelectionMode ? 'Edit' : null,
                        onAction: () => setState(() => _isSelectionMode = true),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8.0),
                    ],
                  ),
                ),
              ),
              if (filteredItems.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 80.0),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
                      alignment: Alignment.center,
                      child: const Text('No bookmarks in this folder', style: TextStyle(color: headerColor, fontSize: 13.0)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 80.0),
                  sliver: SliverList.builder(
                    addAutomaticKeepAlives: false,
                    itemCount: filteredItems.length,
                    itemBuilder: (context, i) => _buildBookmarkCardRow(
                      item: filteredItems[i],
                      isFirst: i == 0,
                      isLast: i == filteredItems.length - 1,
                      isDark: isDark,
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _isSelectionMode ? _buildBottomActionBar(service, isDark) : null,
        );
      },
    );
  }

  Widget _buildSearchPill(bool isDark) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide(color: isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0)),
    );
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) {
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 120), () {
          if (mounted && _debouncedQuery != v.trim().toLowerCase()) {
            setState(() => _debouncedQuery = v.trim().toLowerCase());
          }
        });
      },
      style: TextStyle(fontSize: 14.0, color: isDark ? Colors.white : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF),
        hintText: 'Search bookmarks',
        hintStyle: const TextStyle(fontSize: 14.0, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(PhosphorIcons.magnifyingGlass, size: 18.0, color: Color(0xFF64748B)),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? GestureDetector(
                onTap: () => setState(() {
                  _searchCtrl.clear();
                  _debouncedQuery = '';
                }),
                child: const Icon(PhosphorIcons.xCircle, size: 18.0, color: Color(0xFF94A3B8)),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: BorderSide(color: isDark ? Colors.white70 : const Color(0xFF0F172A), width: 1.5)),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, {String? action, VoidCallback? onAction, required bool isDark}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 11.0, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: color)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action, style: TextStyle(fontFamily: 'Inter', fontSize: 12.0, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ),
        ],
      );

  Widget _buildCardContainer(bool isDark, {required List<Widget> children}) => Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(18.0), border: Border.all(color: isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0))),
        child: ClipRRect(borderRadius: BorderRadius.circular(18.0), child: Column(children: children)),
      );

  Widget _buildDivider(bool isDark) => Container(height: 1.0, margin: const EdgeInsets.only(left: 62.0, right: 12.0), color: isDark ? const Color(0xFF1A202E) : const Color(0xFFF1F5F9));

  Widget _buildBookmarkCardRow({
    required BookmarkItem item,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
  }) {
    final bg = isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(18.0) : Radius.zero,
          bottom: isLast ? const Radius.circular(18.0) : Radius.zero,
        ),
        border: Border(
          left: BorderSide(color: border),
          right: BorderSide(color: border),
          top: isFirst ? BorderSide(color: border) : BorderSide.none,
          bottom: isLast ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFirst) _buildDivider(isDark),
          BookmarkItemRow(
            item: item,
            isSelected: _selectedIds.contains(item.id),
            isSelectionMode: _isSelectionMode,
            isDark: isDark,
            onTap: () => _isSelectionMode ? _toggleSelection(item.id) : Navigator.of(context).pop(item.url),
            onLongPress: () => _toggleSelection(item.id),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BookmarksService service, bool isDark) => Container(
        height: 64.0,
        decoration: BoxDecoration(color: isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF), border: Border(top: BorderSide(color: isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0)))),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionBtn(PhosphorIcons.folderPlus, 'Move', () => _moveSelectedDialog(service)),
            if (_selectedIds.length == 1)
              _buildActionBtn(PhosphorIcons.pencilSimple, 'Edit', () {
                final id = _selectedIds.first;
                final item = service.bookmarks.firstWhere((b) => b.id == id);
                EditBookmarkDialog.show(context, item: item, folders: service.folders, onSave: (t, u, f) {
                  service.updateBookmark(id: id, title: t, url: u, folderId: f);
                  setState(() => _isSelectionMode = false);
                });
              }),
            _buildActionBtn(PhosphorIcons.trash, 'Delete', () {
              service.removeBookmarks(_selectedIds.toList());
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });
            }),
          ],
        ),
      );

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 20.0), const SizedBox(height: 2.0), Text(label, style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.w500))],
        ),
      );

  void _moveSelectedDialog(BookmarksService service) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Move to Folder'),
        children: [
          for (final f in service.folders)
            SimpleDialogOption(
              onPressed: () {
                service.moveBookmarks(_selectedIds.toList(), f.id);
                setState(() { _selectedIds.clear(); _isSelectionMode = false; });
                Navigator.pop(ctx);
              },
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text(f.title)),
            ),
        ],
      ),
    );
  }
}
