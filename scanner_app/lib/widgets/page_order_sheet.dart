import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tora_widgets.dart';

/// A drag-to-reorder list of page thumbnails, in a bottom sheet.
///
/// The result is the new order expressed as *old* indices — `result[i]` is the
/// page that now sits at position `i` — which is exactly what both callers need
/// to permute their parallel page lists.
///
/// The sheet paints in the dark token set even when the app is light: like the
/// crop screen and the editor, it is a room where a page is judged.
class PageOrderSheet extends StatefulWidget {
  const PageOrderSheet({
    super.key,
    required this.thumbnails,
    required this.palette,
  });

  final List<ImageProvider> thumbnails;
  final ToraPalette palette;

  /// Returns null when the sheet was dismissed without pressing DONE.
  static Future<List<int>?> show(
    BuildContext context, {
    required List<ImageProvider> thumbnails,
    required ToraPalette palette,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      builder: (BuildContext context) =>
          PageOrderSheet(thumbnails: thumbnails, palette: palette),
    );
  }

  @override
  State<PageOrderSheet> createState() => _PageOrderSheetState();
}

class _PageOrderSheetState extends State<PageOrderSheet> {
  late final List<int> _order = <int>[
    for (int i = 0; i < widget.thumbnails.length; i++) i,
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
                  ToraLabel('Reorder pages', color: p.ink),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, List<int>.from(_order)),
                    child: const Text('DONE'),
                  ),
                ],
              ),
            ),
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
                  final int pageIndex = _order[index];
                  return ListTile(
                    key: ValueKey<int>(pageIndex),
                    leading: Container(
                      width: 34,
                      height: 44,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: ToraShape.tag,
                        border: Border.all(color: p.lineStrong),
                      ),
                      child: Image(
                        image: widget.thumbnails[pageIndex],
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      'Page ${pageIndex + 1}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: p.ink),
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
