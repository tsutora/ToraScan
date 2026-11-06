import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/scan_document.dart';
import '../models/scan_folder.dart';
import '../services/library_search.dart';
import '../services/scan_flow.dart';
import '../services/scan_store.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/tora_widgets.dart';
import '../widgets/document_actions.dart';
import '../widgets/document_tile.dart';
import '../widgets/folder_list_sheet.dart';
import '../widgets/folder_plate.dart';
import '../widgets/name_dialog.dart';
import '../widgets/no_matches.dart';
import '../widgets/search_field.dart';
import '../widgets/theme_drawer.dart';
import 'editor_screen.dart';
import 'folder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.storageMode = StorageMode.private});

  final StorageMode storageMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScanStore _store = ScanStore();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DateFormat _stamp = DateFormat('d MMM yyyy · HH:mm');
  final TextEditingController _searchController = TextEditingController();

  List<ScanDocument> _documents = <ScanDocument>[];
  List<ScanFolder> _folders = <ScanFolder>[];
  LibraryLocation? _storage;
  bool _loading = true;
  bool _busy = false;

  /// Whether the search field is open. The folder strip steps aside while it
  /// is, so results sit right under the field instead of below a section the
  /// user is not looking at.
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final List<ScanDocument> docs = await _store.load();
      final List<ScanFolder> folders = await _store.loadFolders();
      final LibraryLocation location = await _store.location();
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = docs;
        _folders = folders;
        _storage = location;
        _loading = false;
      });
    } catch (_) {
      // A missing or unreadable library shows an empty one rather than leaving
      // the screen on a spinner forever.
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  ScanFolder? _folderOf(ScanDocument doc) {
    for (final ScanFolder folder in _folders) {
      if (folder.id == doc.folderId) {
        return folder;
      }
    }
    return null;
  }

  int get _totalPages =>
      _documents.fold<int>(0, (int sum, ScanDocument d) => sum + d.pageCount);

  // --------------------------------------------------------------- searching

  /// What the list below the field should show. With the field closed there is
  /// no query, so this is the library itself.
  List<ScanDocument> get _visible =>
      _searching ? searchByName(_documents, _searchController.text) : _documents;

  void _openSearch() {
    setState(() => _searching = true);
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() => _searching = false);
    FocusScope.of(context).unfocus();
  }

  /// Empties the query but leaves the field open, so the user can type again.
  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }


  Future<void> _scan() async {
    setState(() => _busy = true);
    try {
      final ScanDocument? doc = await ScanFlow.run(context, store: _store);
      await _reload();
      if (doc != null && mounted) {
        await _open(doc);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _open(ScanDocument doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(document: doc, store: _store),
      ),
    );
    await _reload();
  }

  Future<void> _openFolder(ScanFolder folder) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FolderScreen(folder: folder, store: _store),
      ),
    );
    await _reload();
  }

  Future<void> _createFolder() async {
    final String? name = await showNameDialog(
      context,
      initial: 'New folder',
      title: 'New folder',
      confirmLabel: 'Create',
    );
    if (name == null) {
      return;
    }

    await _store.addFolder(
      ScanFolder(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        createdAt: DateTime.now(),
        colorIndex: _folders.length,
      ),
    );
    await _reload();
  }

  /// Opens the full folder list, where the order can be changed.
  Future<void> _openAllFolders() async {
    final List<int> counts = <int>[
      for (final ScanFolder folder in _folders)
        _documents.where((ScanDocument d) => d.folderId == folder.id).length,
    ];

    final List<int>? order = await FolderListSheet.show(
      context,
      folders: _folders,
      counts: counts,
      palette: ToraPalette.of(context),
    );
    if (order == null || !mounted) {
      return;
    }

    bool moved = false;
    for (int i = 0; i < order.length; i++) {
      if (order[i] != i) {
        moved = true;
        break;
      }
    }
    if (!moved) {
      return;
    }

    final List<ScanFolder> ordered = <ScanFolder>[
      for (final int i in order) _folders[i],
    ];
    await _store.reorderFolders(ordered);
    if (mounted) {
      setState(() => _folders = ordered);
    }
  }

  Future<void> _rename(ScanDocument doc) async {
    final String? name = await DocumentActions.rename(context, doc);
    if (name == null) {
      return;
    }
    await _store.rename(doc, name);
    await _reload();
  }

  Future<void> _copy(ScanDocument doc) async {
    await DocumentActions.copy(context, _store, doc);
    await _reload();
  }

  Future<void> _move(ScanDocument doc) async {
    final FolderChoice? choice = await DocumentActions.pickFolder(
      context,
      folders: _folders,
      currentFolderId: doc.folderId,
    );
    if (choice == null) {
      return;
    }
    await _store.moveToFolder(doc, choice.folderId);
    await _reload();
  }

  Future<void> _delete(ScanDocument doc) async {
    if (!await DocumentActions.confirmDelete(context, doc)) {
      return;
    }
    await _store.remove(doc);
    await _reload();
  }

  Future<void> _requestSharedStorage() async {
    await StorageService.openAccessSettings();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Grant “All files access”, then come back — ToraScan moves your '
          'library into ToraScan/ automatically.',
        ),
      ),
    );
  }

  /// Asks before the app leaves the screen, so a stray back gesture does not
  /// close a library the user is in the middle of using.
  Future<void> _confirmExit() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Exit ToraScan?'),
        content: const Text('Your scans stay saved in the library.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (leave ?? false) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return PopScope(
      // The library is the root route, so a system back here would close the
      // app outright. Intercept it and ask first.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        // Back closes a search before it offers to close the app: while the
        // field is open, leaving the library is almost never what was meant.
        if (_searching) {
          _closeSearch();
          return;
        }
        _confirmExit();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const ThemeDrawer(),
        body: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _reload,
                  color: p.accent,
                  backgroundColor: p.surface,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: <Widget>[
                      SliverToBoxAdapter(child: _masthead(context)),
                      if (_searching)
                        SliverToBoxAdapter(
                          child: ToraSearchField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            onCancel: _closeSearch,
                          ),
                        )
                      else
                        SliverToBoxAdapter(child: _folderStrip(context)),
                      SliverToBoxAdapter(
                        child: ToraSectionHeader(
                          label: _searching ? 'Results' : 'All scans',
                          trailing: _searching
                              ? '${_visible.length} of ${_documents.length}'
                              : '${_documents.length} · $_totalPages pages',
                        ),
                      ),
                      if (_documents.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyLibrary(onScan: _busy ? null : _scan),
                        )
                      else if (_visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: NoMatches(
                            query: _searchController.text.trim(),
                            onClear: _clearSearch,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList.builder(
                            itemCount: _visible.length,
                            itemBuilder: (BuildContext context, int index) {
                              final ScanDocument doc = _visible[index];
                              return DocumentTile(
                                document: doc,
                                isFirst: index == 0,
                                subtitle:
                                    '${doc.pageCount} '
                                    '${doc.pageCount == 1 ? 'page' : 'pages'}'
                                    ' · ${_stamp.format(doc.createdAt)}',
                                folderLabel: _folderOf(doc)?.name,
                                onTap: () => _open(doc),
                                onShare: () => DocumentActions.share(doc),
                                onShareJpg: () => DocumentActions.shareJpg(doc),
                                onRename: () => _rename(doc),
                                onCopy: () => _copy(doc),
                                onMove: () => _move(doc),
                                onDelete: () => _delete(doc),
                              );
                            },
                          ),
                        ),
                      SliverToBoxAdapter(child: _footer(context)),
                    ],
                  ),
                ),
        ),
        floatingActionButton: _scanButton(),
      ),
    );
  }

  // ------------------------------------------------------------- masthead

  Widget _masthead(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: <Widget>[
          InkWell(
            borderRadius: ToraShape.tag,
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: ToraMonogram(size: 40),
            ),
          ),
          const SizedBox(width: 12),
          // The title takes the slack rather than a Spacer: beside fixed
          // chrome (the storage mode and the search button) a long label must
          // give way, or the row runs past the screen edge on a narrow phone.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ToraLabel('ToraScan', color: p.ink),
                const ToraMicro('Document scanner', maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ToraMicro(
            widget.storageMode == StorageMode.shared ? 'On device' : 'Private',
            maxLines: 1,
          ),
          if (_documents.isNotEmpty && !_searching)
            IconButton(
              tooltip: 'Search scans',
              onPressed: _openSearch,
              icon: const Icon(Icons.search, size: 20),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- folders

  Widget _folderStrip(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 26),
        ToraSectionHeader(
          label: 'Folders',
          secondaryAction: _folders.isEmpty ? null : 'All',
          onSecondaryAction: _openAllFolders,
          action: 'New',
          onAction: _createFolder,
        ),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _folders.length + 1,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              if (index == _folders.length) {
                return _NewFolderCard(onTap: _createFolder);
              }
              final ScanFolder folder = _folders[index];
              final int count = _documents
                  .where((ScanDocument d) => d.folderId == folder.id)
                  .length;
              return _FolderCard(
                folder: folder,
                index: index + 1,
                count: count,
                onTap: () => _openFolder(folder),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // --------------------------------------------------------------- footer

  Widget _footer(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);
    final LibraryLocation? storage = _storage;
    final bool shared = storage?.isShared ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: ToraMicro(
                  shared ? storage!.root.path : 'Private app storage',
                  color: p.inkFaint,
                  upper: false,
                ),
              ),
              if (!shared)
                GestureDetector(
                  onTap: _requestSharedStorage,
                  child: Text(
                    'Make visible',
                    style: toraType(
                      10,
                      FontWeight.w700,
                      tracking: 1.2,
                      color: p.accentText,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanButton() {
    return FloatingActionButton.extended(
      onPressed: _busy ? null : _scan,
      icon: const Icon(Icons.document_scanner_outlined, size: 20),
      label: const Text('SCAN'),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.index,
    required this.count,
    required this.onTap,
  });

  final ScanFolder folder;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return SizedBox(
      width: 158,
      child: FolderPlate(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              index.toString().padLeft(2, '0'),
              style: toraType(
                10,
                FontWeight.w600,
                tracking: 1.2,
                color: p.inkFaint,
                tabular: true,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 4),
                ToraMicro('$count ${count == 1 ? 'scan' : 'scans'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewFolderCard extends StatelessWidget {
  const _NewFolderCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return SizedBox(
      width: 120,
      child: FolderPlate(
        onTap: onTap,
        filled: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.add, size: 20, color: p.inkSoft),
            const SizedBox(height: 6),
            ToraMicro('New folder', color: p.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({this.onScan});

  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const ToraMonogram(size: 64, outline: true),
          const SizedBox(height: 20),
          Text('Nothing scanned yet', style: text.headlineMedium),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Start scanning'),
          ),
        ],
      ),
    );
  }
}
