import 'package:flutter/material.dart';

import '../models/scan_folder.dart';
import '../theme/app_theme.dart';
import '../theme/tora_widgets.dart';

/// Every folder in one place, with its scans counted and its position movable.
///
/// The home strip is a preview: it scrolls sideways and only ever shows the
/// first few folders. This sheet is the whole list, and the only place the
/// order can be changed — dragging a row is the edit, DONE is the commit.
///
/// The result is the new order expressed as *old* indices: `result[i]` is the
/// folder that now sits at position `i`. Returns null when the sheet was
/// dismissed without pressing DONE.
class FolderListSheet extends StatefulWidget {
  const FolderListSheet({
    super.key,
    required this.folders,
    required this.counts,
    required this.palette,
  });

  final List<ScanFolder> folders;

  /// Scan count per folder, parallel to [folders].
  final List<int> counts;

  final ToraPalette palette;

  static Future<List<int>?> show(
    BuildContext context, {
    required List<ScanFolder> folders,
    required List<int> counts,
    required ToraPalette palette,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      builder: (BuildContext context) =>
          FolderListSheet(folders: folders, counts: counts, palette: palette),
    );
  }

  @override
  State<FolderListSheet> createState() => _FolderListSheetState();
}

class _FolderListSheetState extends State<FolderListSheet> {
  late final List<int> _order = <int>[
    for (int i = 0; i < widget.folders.length; i++) i,
  ];

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = widget.palette;

    return Theme(
      data: AppTheme.dark(p),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: <Widget>[
                  ToraLabel('All folders', color: p.ink),
                  const Spacer(),
                  if (_order.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, List<int>.from(_order)),
                      child: const Text('DONE'),
                    ),
                ],
              ),
            ),
            if (_order.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ToraMicro(
                    'No folders yet. Create one from the strip.',
                    color: p.inkFaint,
                    upper: false,
                  ),
                ),
              )
            else
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: _order.length,
                  onReorderItem: (int oldIndex, int newIndex) {
                    setState(() {
                      final int moved = _order.removeAt(oldIndex);
                      _order.insert(newIndex, moved);
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final int folderIndex = _order[index];
                    final ScanFolder folder = widget.folders[folderIndex];
                    final int count = widget.counts[folderIndex];

                    return ListTile(
                      key: ValueKey<String>(folder.id),
                      leading: ToraMicro(
                        (index + 1).toString().padLeft(2, '0'),
                        color: p.inkFaint,
                        upper: false,
                      ),
                      title: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: p.ink),
                      ),
                      subtitle: ToraMicro(
                        '$count ${count == 1 ? 'scan' : 'scans'}',
                        color: p.inkFaint,
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_handle,
                          color: p.inkFaint,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
