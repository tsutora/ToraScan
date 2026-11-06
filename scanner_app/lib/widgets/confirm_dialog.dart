import 'package:flutter/material.dart';

/// Asks before work that has not been saved is thrown away.
///
/// The safe answer is the filled button and sits on the right, where the
/// primary action normally goes; the destructive answer is a plain text button
/// on the left. That is deliberate — a mis-tap should land on "keep", never on
/// "discard". Returns `true` only when the user really means to discard.
Future<bool> confirmDiscard(
  BuildContext context, {
  required String title,
  required String message,
  String discardLabel = 'Discard',
  String keepLabel = 'Keep editing',
}) async {
  final bool? discard = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(discardLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(keepLabel),
        ),
      ],
    ),
  );
  return discard ?? false;
}

/// Asks before an edit is written over the files in the library.
///
/// The caller only reaches this after the user tapped Save, so the confirm
/// spells out what changes on disk instead of asking "are you sure".
Future<bool> confirmSave(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String saveLabel = 'Save changes',
}) async {
  final bool? save = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(saveLabel),
        ),
      ],
    ),
  );
  return save ?? false;
}
