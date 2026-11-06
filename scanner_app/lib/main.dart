import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/storage_gate.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ToraScan is a portrait app: a page is taller than it is wide, and the
  // viewfinder, the crop screen and the preview all lay themselves out for one
  // column. Allowing landscape would either squeeze those screens or rotate a
  // capture the user did not ask to rotate. The manifest pins the activity as
  // well, so this holds before Flutter's first frame too.
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  runApp(const ToraScanApp());
}

class ToraScanApp extends StatefulWidget {
  const ToraScanApp({super.key});

  @override
  State<ToraScanApp> createState() => _ToraScanAppState();
}

class _ToraScanAppState extends State<ToraScanApp> {
  final ThemeController _theme = ThemeController();

  @override
  void initState() {
    super.initState();
    // The stored choice is applied as soon as it is read; the first frame uses
    // the default palette, which is the same one a new install gets anyway.
    _theme.load();
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToraThemeScope(
      controller: _theme,
      child: AnimatedBuilder(
        animation: _theme,
        builder: (BuildContext context, Widget? child) => MaterialApp(
          title: 'ToraScan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(_theme.family.light),
          darkTheme: AppTheme.dark(_theme.family.dark),
          themeMode: _theme.mode,
          home: StorageGate(
            builder: (BuildContext context, StorageMode mode) =>
                HomeScreen(storageMode: mode),
          ),
        ),
      ),
    );
  }
}
