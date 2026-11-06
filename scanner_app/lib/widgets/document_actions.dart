import 'package:flutter/material.dart';

import '../models/scan_document.dart';
import '../models/scan_folder.dart';
import '../services/scan_store.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../theme/tora_widgets.dart';
import '../widgets/name_dialog.dart';

/// Result of the "move to folder" sheet.
///
/// A bare `String?` would be ambiguous — null could mean "dismissed" or "no
/// folder" — so the choice is wrapped.
class FolderChoice {
  const FolderChoice(this.folderId);

  final String? folderId;
}

/// Dialogs and OS integrations shared by the library screens.
class DocumentActions {
  const DocumentActions._();

  static Future<void> share(ScanDocument doc) => ShareService.sharePdf(doc);

  static Future<void> shareJpg(ScanDocument doc) => ShareService.shareJpg(doc);

  static Future<String?> rename(BuildContext context, ScanDocument doc) {
    return showNameDialog(
      context,
      initial: doc.title,
      title: 'Rename',
      confirmLabel: 'Save',
    );
  }

  /// Duplicates a scan and confirms it without leaving the library.
  ///
  /// A snackbar rather than a dialog: copying is reversible (the copy can be
  /// deleted) and interrupting the list with a modal would be heavier than the
  /// action deserves.
  static Future<void> copy(
    BuildContext context,
    ScanStore store,
    ScanDocument doc,
  ) async {
    final ScanDocument duplicate = await store.duplicate(doc);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Copied as "${duplicate.title}"')),
      );
  }

  static Future<bool> confirmDelete(
    BuildContext context,
    ScanDocument doc,
  ) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete scan?'),
        content: Text('"${doc.title}" and its PDF will be removed.'),
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
    return result ?? false;
  }

  static Future<FolderChoice?> pickFolder(
    BuildContext context, {
    required List<ScanFolder> folders,
    required String? currentFolderId,
  }) {
    return showModalBottomSheet<FolderChoice>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final TextTheme text = Theme.of(context).textTheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Move to folder', style: text.headlineSmall),
                const SizedBox(height: 12),
                const ToraRule(),
                _FolderOption(
                  label: 'No folder',
                  index: null,
                  selected: currentFolderId == null,
                  onTap: () => Navigator.pop(context, const FolderChoice(null)),
                ),
                for (int i = 0; i < folders.length; i++)
                  _FolderOption(
                    label: folders[i].name,
                    index: i + 1,
                    selected: folders[i].id == currentFolderId,
                    onTap: () =>
                        Navigator.pop(context, FolderChoice(folders[i].id)),
                  ),
                if (folders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No folders yet — create one from the home screen.',
                      style: text.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FolderOption extends StatelessWidget {
  const _FolderOption({
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: ToraShape.tag,
                border: Border.all(
                  color: selected ? p.accent : p.lineStrong,
                  width: ToraShape.stroke,
                ),
              ),
              child: Text(
                index == null ? '—' : index.toString().padLeft(2, '0'),
                style: toraType(
                  10,
                  FontWeight.w600,
                  tracking: 1,
                  color: selected ? p.accentText : p.inkFaint,
                  tabular: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
            ),
            if (selected) Icon(Icons.check, size: 18, color: p.accent),
          ],
        ),
      ),
    );
  }
}
