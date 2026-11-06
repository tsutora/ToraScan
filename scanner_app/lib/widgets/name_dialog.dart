import 'package:flutter/material.dart';

/// Asks for a document name.
///
/// The field is pre-filled with [initial] and fully selected, so typing
/// replaces the suggestion in one keystroke while the default stays available
/// if the user just confirms.
Future<String?> showNameDialog(
  BuildContext context, {
  required String initial,
  String title = 'Name this scan',
  String confirmLabel = 'Save',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) =>
        _NameDialog(initial: initial, title: title, confirmLabel: confirmLabel),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.initial,
    required this.title,
    required this.confirmLabel,
  });

  final String initial;
  final String title;
  final String confirmLabel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _selectAll();
    // The field attaches after the first frame and resets the selection, so it
    // has to be applied again once it is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectAll();
      }
    });
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? widget.initial : value);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'File name'),
          ),
          const SizedBox(height: 12),
          Text(
            'The PDF is saved under this name, in the folder you are in.',
            style: text.bodySmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
