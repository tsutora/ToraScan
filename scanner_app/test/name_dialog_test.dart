import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/widgets/name_dialog.dart';

/// Opens the dialog from a host screen and records what it returns.
class _Host extends StatefulWidget {
  const _Host({required this.initial});

  final String initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? result;
  bool closed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final String? value = await showNameDialog(
              context,
              initial: widget.initial,
            );
            setState(() {
              result = value;
              closed = true;
            });
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<_HostState> _open(WidgetTester tester, String initial) async {
  await tester.pumpWidget(MaterialApp(home: _Host(initial: initial)));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

void main() {
  testWidgets('the default name is pre-filled and fully selected', (
    WidgetTester tester,
  ) async {
    await _open(tester, 'Scan 28 Oct 2026 15.04');

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    final TextEditingController controller = field.controller!;

    expect(controller.text, 'Scan 28 Oct 2026 15.04');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 22),
    );
    // Selecting all means typing replaces the suggestion outright.
    expect(controller.selection.isCollapsed, isFalse);
  });

  testWidgets('confirming keeps the default name', (WidgetTester tester) async {
    final _HostState host = await _open(tester, 'Scan 28 Oct 2026 15.04');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(host.result, 'Scan 28 Oct 2026 15.04');
  });

  testWidgets('typing over the selection replaces it', (
    WidgetTester tester,
  ) async {
    final _HostState host = await _open(tester, 'Scan 28 Oct 2026 15.04');

    // One keystroke wipes the pre-selected default.
    await tester.enterText(find.byType(TextField), 'Invoice PLN');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(host.result, 'Invoice PLN');
  });

  testWidgets('a blank name falls back to the default', (
    WidgetTester tester,
  ) async {
    final _HostState host = await _open(tester, 'Scan 28 Oct 2026 15.04');

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(host.result, 'Scan 28 Oct 2026 15.04');
  });

  testWidgets('cancelling saves nothing', (WidgetTester tester) async {
    final _HostState host = await _open(tester, 'Scan 28 Oct 2026 15.04');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(host.closed, isTrue);
    expect(host.result, isNull);
  });
}
