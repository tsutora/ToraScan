import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_document.dart';
import '../theme/app_theme.dart';
import '../theme/tora_widgets.dart';

/// One scan in a library list.
///
/// Drawn as a table row — hairline underneath, framed thumbnail, tabular meta —
/// rather than a floating card, so the list reads like the rest of the system.
class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.document,
    required this.subtitle,
    required this.onTap,
    required this.onShare,
    required this.onShareJpg,
    required this.onRename,
    required this.onCopy,
    required this.onMove,
    required this.onDelete,
    this.folderLabel,
    this.isFirst = false,
  });

  final ScanDocument document;
  final String subtitle;
  final String? folderLabel;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onShareJpg;
  final VoidCallback onRename;
  final VoidCallback onCopy;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              top: isFirst ? BorderSide(color: p.line) : BorderSide.none,
              bottom: BorderSide(color: p.line),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: ToraShape.tag,
                  border: Border.all(
                    color: p.lineStrong,
                    width: ToraShape.stroke,
                  ),
                ),
                child: Image.file(
                  File(document.pagePaths.first),
                  key: ValueKey<String>(
                    '${document.id}-${document.updatedAt.microsecondsSinceEpoch}',
                  ),
                  fit: BoxFit.cover,
                  cacheWidth: 132,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) => ColoredBox(
                        color: p.surface2,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 16,
                          color: p.inkFaint,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (folderLabel != null) ToraTag(folderLabel!),
                        ToraMicro(subtitle),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(Icons.more_vert, size: 20, color: p.inkFaint),
                padding: EdgeInsets.zero,
                splashRadius: 20,
                onSelected: (String value) {
                  switch (value) {
                    case 'share':
                      onShare();
                    case 'shareJpg':
                      onShareJpg();
                    case 'rename':
                      onRename();
                    case 'copy':
                      onCopy();
                    case 'move':
                      onMove();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'share',
                        child: Text('Share PDF'),
                      ),
                      PopupMenuItem<String>(
                        value: 'shareJpg',
                        child: Text('Share as JPG'),
                      ),
                      PopupMenuItem<String>(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      PopupMenuItem<String>(
                        value: 'copy',
                        child: Text('Copy'),
                      ),
                      PopupMenuItem<String>(
                        value: 'move',
                        child: Text('Move to folder'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
