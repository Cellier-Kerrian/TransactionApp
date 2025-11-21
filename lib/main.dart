import 'package:flutter/material.dart';
import 'core/config/config_loader.dart';
import 'app.dart';
import 'user_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserConfig.init();
  if (UserConfig.GITHUB_TOKEN.isNotEmpty && UserConfig.USER_NAME.isNotEmpty) {
    try { await ConfigLoader.syncFromGithubIfChanged(); } catch (_) {}
  }
  runApp(const ComptesApp());
}
