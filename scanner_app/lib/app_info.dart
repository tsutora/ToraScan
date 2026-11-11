/// The user-visible version of the app, shown in the appearance sidebar.
///
/// It has to match `version:` in pubspec.yaml; `test/app_info_test.dart` reads
/// the pubspec and fails if the two ever drift apart. Android's Settings screen
/// shows the same string, which is what lets a user tell a current build from
/// an old one.
const String toraVersion = '1.1.0';
