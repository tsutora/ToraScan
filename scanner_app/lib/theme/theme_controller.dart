import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'palettes.dart';

/// Remembers which palette and which brightness the user picked.
///
/// Stored beside the app's private files rather than in the visible library, so
/// the setting does not show up as a stray file in `ToraScan/`.
class ThemeController extends ChangeNotifier {
  static const String _fileName = 'theme.json';

  ToraPaletteFamily _family = ToraPalettes.neutral;
  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ToraPaletteFamily get family => _family;
  ThemeMode get mode => _mode;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final File file = await _file();
      if (await file.exists()) {
        final dynamic decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          _family = ToraPalettes.byId(decoded['palette'] as String?);
          _mode = _modeFrom(decoded['mode'] as String?);
        }
      }
    } catch (_) {
      // A missing or unreadable setting just means the default theme.
    }
    _loaded = true;
    notifyListeners();
  }

  void setFamily(ToraPaletteFamily family) {
    if (family.id == _family.id) {
      return;
    }
    _family = family;
    notifyListeners();
    _save();
  }

  void setMode(ThemeMode mode) {
    if (mode == _mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
    _save();
  }

  Future<File> _file() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> _save() async {
    try {
      final File file = await _file();
      await file.writeAsString(
        jsonEncode(<String, String>{'palette': _family.id, 'mode': _mode.name}),
        flush: true,
      );
    } catch (_) {
      // Losing the preference is harmless; the app keeps working this session.
    }
  }

  static ThemeMode _modeFrom(String? name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// Makes the controller reachable from any screen without threading it through
/// every constructor.
class ToraThemeScope extends InheritedNotifier<ThemeController> {
  const ToraThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final ToraThemeScope? scope = context
        .dependOnInheritedWidgetOfExactType<ToraThemeScope>();
    assert(scope != null, 'No ToraThemeScope above this widget');
    return scope!.notifier!;
  }
}
