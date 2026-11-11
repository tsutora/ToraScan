# ToraScan — app source

Flutter source for ToraScan. See the [repository README](../README.md) for what the app does, its permissions and where it stores scans.

```bash
flutter pub get
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

The APKs are named `ToraScan-<version>-<abi>.apk`, with the version taken from
`pubspec.yaml`, in `build/app/outputs/flutter-apk/` (and the untouched Gradle
outputs in `build/app/outputs/apk/release/`). The `app-<abi>-release.apk` files
next to them are the names the Flutter tool itself looks for; ignore those.
