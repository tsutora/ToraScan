import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown when a search matches none of the library's names.
///
/// It names the query back so a typo is obvious, and says plainly that only
/// names are searched — otherwise a missing document reads as "the app lost
/// my scan" rather than "that word is not in its title".
class NoMatches extends StatelessWidget {
  const NoMatches({super.key, required this.query, this.onClear});

  final String query;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_off_rounded, size: 26, color: p.inkFaint),
          const SizedBox(height: 14),
          Text(
            'No scan is named “$query”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Search looks at the name of each scan, not at what is written on '
            'the page. Try a shorter word, or rename a scan from its menu.',
            style: text.bodyMedium,
          ),
          if (onClear != null) ...<Widget>[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('CLEAR SEARCH'),
            ),
          ],
        ],
      ),
    );
  }
}
