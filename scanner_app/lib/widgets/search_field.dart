import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The library's one search input.
///
/// Kept as a plain field rather than a full search screen: a search here only
/// filters a list the user is already looking at, so leaving the library — and
/// losing the folder strip and the scan button — would cost more than it gains.
class ToraSearchField extends StatelessWidget {
  const ToraSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onCancel,
    this.hint = 'Search by name',
    this.autofocus = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Shows a CANCEL action beside the field. Null hides it and leaves the
  /// field on screen, which is what a search that cannot be closed wants.
  final VoidCallback? onCancel;

  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              // The decoration carries a clear button that only exists while
              // something is typed, so the field has to be rebuilt as the text
              // changes. A controller is a stable identity, so the field keeps
              // its state and its cursor across those rebuilds.
              builder:
                  (BuildContext context, TextEditingValue value, Widget? _) {
                    return TextField(
                      controller: controller,
                      onChanged: onChanged,
                      autofocus: autofocus,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      style: toraType(
                        14,
                        FontWeight.w500,
                        height: 1.3,
                        color: p.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: p.inkFaint,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                        ),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  controller.clear();
                                  onChanged('');
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: p.inkFaint,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                splashRadius: 16,
                              ),
                      ),
                    );
                  },
            ),
          ),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('CANCEL'),
            ),
        ],
      ),
    );
  }
}
