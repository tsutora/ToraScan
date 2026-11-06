import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scan_document.dart';
import '../models/scan_folder.dart';
import '../services/library_search.dart';
import '../services/scan_flow.dart';
import '../services/scan_store.dart';
import '../theme/tora_widgets.dart';
import '../widgets/document_actions.dart';
import '../widgets/document_tile.dart';
import '../widgets/name_dialog.dart';
import '../widgets/no_matches.dart';
import '../widgets/search_field.dart';
import 'editor_screen.dart';

/// The scans inside one folder.
class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.folder, required this.store});

  final ScanFolder folder;
  final ScanStore store;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final DateFormat _stamp = DateFormat('d MMM yyyy · HH:mm');
  final TextEditingController _searchController = TextEditingController();

  List<ScanDocument> _documents = <ScanDocument>[];
  List<ScanFolder> _folders = <ScanFolder>[];
  String _path = '';
  bool _loading = true;
  bool _busy = false;
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

  /// The folder's scans after the name filter, in the library's order.
  List<ScanDocument> get _visible => _searching
      ? searchByName(_documents, _searchController.text)
      : _documents;

  void _openSearch() {
    setState(() => _searching = true);
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() => _searching = false);
    FocusScope.of(context).unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  Future<void> _reload() async {
    try {
      final List<ScanDocument> docs = await widget.store.load();
      final List<ScanFolder> folders = await widget.store.loadFolders();
      final String path = (await widget.store.folderDirPath(widget.folder.name))
          .path;
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = docs
            .where((ScanDocument d) => d.folderId == widget.folder.id)
            .toList();
        _folders = folders;
        _path = path;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _scan() async {
    setState(() => _busy = true);
    try {
      final ScanDocument? doc = await ScanFlow.run(
        context,
        store: widget.store,
        folderId: widget.folder.id,
      );
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
        builder: (_) => EditorScreen(document: doc, store: widget.store),
      ),
    );
    await _reload();
  }

  Future<void> _renameFolder() async {
    final String? name = await showNameDialog(
      context,
      initial: widget.folder.name,
      title: 'Rename folder',
      confirmLabel: 'Save',
    );
    if (name == null) {
      return;
    }
    await widget.store.renameFolder(widget.folder, name);
    await _reload();
  }

  Future<void> _deleteFolder() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          '"${widget.folder.name}" will be removed. The '
          '${_documents.length} '
          '${_documents.length == 1 ? 'scan' : 'scans'} inside move to '
          'Unsorted — nothing is deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.removeFolder(widget.folder);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _rename(ScanDocument doc) async {
    final String? name = await DocumentActions.rename(context, doc);
    if (name == null) {
      return;
    }
    await widget.store.rename(doc, name);
    await _reload();
  }

  Future<void> _copy(ScanDocument doc) async {
    await DocumentActions.copy(context, widget.store, doc);
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
    await widget.store.moveToFolder(doc, choice.folderId);
    await _reload();
  }

  Future<void> _delete(ScanDocument doc) async {
    if (!await DocumentActions.confirmDelete(context, doc)) {
      return;
    }
    await widget.store.remove(doc);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return PopScope(
      // Back closes the in-folder search before it leaves the folder.
      canPop: !_searching,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _searching) {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.headlineSmall,
              ),
              ToraMicro(
                _searching
                    ? '${_visible.length} of ${_documents.length}'
                    : '${_documents.length} '
                          '${_documents.length == 1 ? 'scan' : 'scans'}',
              ),
            ],
          ),
          actions: <Widget>[
            if (_documents.isNotEmpty && !_searching)
              IconButton(
                tooltip: 'Search this folder',
                onPressed: _openSearch,
                icon: const Icon(Icons.search, size: 20),
              ),
            IconButton(
              tooltip: 'Rename folder',
              onPressed: _renameFolder,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Delete folder',
              onPressed: _deleteFolder,
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _documents.isEmpty
            ? _EmptyFolder(path: _path, onScan: _busy ? null : _scan)
            : Column(
                children: <Widget>[
                  if (_searching)
                    ToraSearchField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      onCancel: _closeSearch,
                    )
                  else if (_path.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ToraMicro(_path, upper: false),
                      ),
                    ),
                  Expanded(
                    child: _visible.isEmpty
                        ? SingleChildScrollView(
                            child: NoMatches(
                              query: _searchController.text.trim(),
                              onClear: _clearSearch,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
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
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : _scan,
          icon: const Icon(Icons.document_scanner_outlined, size: 20),
          label: const Text('SCAN HERE'),
        ),
      ),
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({required this.path, this.onScan});

  final String path;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const ToraMonogram(size: 64, outline: true),
          const SizedBox(height: 20),
          Text('This folder is empty', style: text.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Scan into it, or move a scan here from its menu.',
            style: text.bodyMedium,
          ),
          if (path.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            ToraMicro(path, upper: false),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Scan into folder'),
          ),
        ],
      ),
    );
  }
}
