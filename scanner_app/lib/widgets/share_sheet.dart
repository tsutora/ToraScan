import 'package:flutter/material.dart';

import '../models/scan_document.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../theme/tora_widgets.dart';

/// What the user chose after a scan was saved.
enum ShareChoice { pdf, jpg, open }

/// The post-save sheet: the file is already on disk, so the next step is
/// sending it somewhere or opening it to edit.
///
/// Returns `true` when the caller should open the document in the editor.
class ShareSheet extends StatelessWidget {
  const ShareSheet({super.key, required this.document});

  final ScanDocument document;

  static Future<bool> show(BuildContext context, ScanDocument doc) async {
    final ShareChoice? choice = await showModalBottomSheet<ShareChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (BuildContext context) => ShareSheet(document: doc),
    );
    if (choice == null) {
      return false;
    }
    if (choice == ShareChoice.open) {
      return true;
    }
    if (choice == ShareChoice.pdf) {
      await ShareService.sharePdf(doc);
    } else {
      await ShareService.shareJpg(doc);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final int pages = document.pageCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              document.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall,
            ),
            const SizedBox(height: 4),
            ToraMicro(
              'Saved · $pages ${pages == 1 ? 'page' : 'pages'}',
              color: p.inkFaint,
            ),
            const SizedBox(height: 14),
            ToraRule(),
            _Row(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Share PDF',
              meta: '.pdf',
              onTap: () => Navigator.pop(context, ShareChoice.pdf),
            ),
            _Row(
              icon: Icons.image_outlined,
              label: 'Share as JPG',
              meta: pages == 1 ? '.jpg' : '$pages .jpg',
              onTap: () => Navigator.pop(context, ShareChoice.jpg),
            ),
            _Row(
              icon: Icons.tune,
              label: 'Open document',
              meta: 'Read · reorder · pages',
              onTap: () => Navigator.pop(context, ShareChoice.open),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.meta,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: p.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ToraMicro(meta, color: p.inkFaint),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}
