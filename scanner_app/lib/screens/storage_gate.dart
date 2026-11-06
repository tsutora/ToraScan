import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/tora_widgets.dart';

/// Decides where the library lives before the app is shown.
///
/// On Android 11+ writing a visible folder on shared storage needs "All files
/// access". The user grants it once here; if they decline, the app still works
/// but keeps everything in private storage.
///
/// The child is rebuilt with a new key when the mode changes, so the library
/// screen re-resolves the storage root and adopts whatever was already there.
class StorageGate extends StatefulWidget {
  const StorageGate({super.key, required this.builder});

  final Widget Function(BuildContext context, StorageMode mode) builder;

  @override
  State<StorageGate> createState() => _StorageGateState();
}

class _StorageGateState extends State<StorageGate> with WidgetsBindingObserver {
  StorageMode? _mode;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have granted access in Settings; re-check on return.
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking) {
      return;
    }
    _checking = true;
    try {
      final bool granted = await StorageService.hasSharedAccess();
      if (!mounted) {
        return;
      }
      if (granted) {
        setState(() => _mode = StorageMode.shared);
      } else if (_mode == null) {
        setState(() {});
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final StorageMode? mode = _mode;
    if (mode != null) {
      return KeyedSubtree(
        key: ValueKey<StorageMode>(mode),
        child: widget.builder(context, mode),
      );
    }

    return _AccessPage(
      onGrant: () async {
        await StorageService.openAccessSettings();
        await _check();
      },
      onSkip: () => setState(() => _mode = StorageMode.private),
    );
  }
}

class _AccessPage extends StatelessWidget {
  const _AccessPage({required this.onGrant, required this.onSkip});

  final Future<void> Function() onGrant;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const ToraMonogram(size: 40),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ToraLabel('ToraScan', color: p.ink),
                      const ToraMicro('Storage setup'),
                    ],
                  ),
                ],
              ),
              const Spacer(flex: 2),
              ToraLabel('Storage access', color: p.accentText),
              const SizedBox(height: 12),
              Text(
                'Allow access to ToraScan/',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Scans and PDFs are written to /storage/emulated/0/ToraScan, so '
                'you can open them from Files. Android asks for “All files '
                'access” once.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              const ToraRule(accent: true),
              const SizedBox(height: 18),
              _Fact(label: 'Folders', value: 'One directory per folder'),
              _Fact(label: 'PDFs', value: 'Named after the scan'),
              _Fact(label: 'Location', value: '/storage/emulated/0/ToraScan'),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onGrant,
                  child: const Text('Grant access'),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onSkip,
                  child: const Text('Use private storage instead'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ToraLabel(label, color: p.ink),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
