import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle; // fallback optionnel
import 'package:path_provider/path_provider.dart';

import '../../user_config.dart';
import '../services/github_service.dart';
import 'config_model.dart';

class ConfigLoader {
  static const _localConfigFileName = 'config.json';
  static const _localShaFileName    = 'config.sha'; // mémorise le SHA GitHub

  /// Dossier où l’on stocke le cache local (config.json + config.sha)
  static Future<Directory> _configDir() async {
    final dir = await getApplicationSupportDirectory();
    final d = Directory('${dir.path}/config_cache');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> _localConfigFile() async {
    final d = await _configDir();
    return File('${d.path}/$_localConfigFileName');
  }

  static Future<File> _localShaFile() async {
    final d = await _configDir();
    return File('${d.path}/$_localShaFileName');
  }

  static Future<void> syncFromGithubIfChanged({bool force = false}) async {
    final gh = GithubService(UserConfig.GITHUB_TOKEN);
    final path = GithubPath(
      owner: UserConfig.GITHUB_OWNER,
      repo:  UserConfig.GITHUB_REPO,
      branch: UserConfig.GITHUB_BRANCH,
      path:  UserConfig.CONFIG_PATH,
    );

    final localConfig = await _localConfigFile();
    final localSha    = await _localShaFile();

    late final dynamic remote;
    try {
      remote = await gh.fetchFile(path);
    } catch (_) {
      if (await localConfig.exists()) return;
      try {
        final asset = await rootBundle.loadString('assets/config.json');
        await localConfig.writeAsString(asset);
      } catch (_) {}
      return;
    }

    final String remoteContent = remote.content as String;
    final String remoteSha     = (remote.sha ?? '') as String;

    if (force) {
      await localConfig.writeAsString(remoteContent);
      await localSha.writeAsString(remoteSha);
      return;
    }

    final hasLocalSha = await localSha.exists();
    if (!hasLocalSha) {
      if (!await localConfig.exists()) {
        await localConfig.writeAsString(remoteContent);
        await localSha.writeAsString(remoteSha);
      } else {
        final localContent = await localConfig.readAsString();
        if (localContent.trim() != remoteContent.trim()) {
          await localConfig.writeAsString(remoteContent);
        }
        await localSha.writeAsString(remoteSha);
      }
      return;
    }

    final savedSha = await localSha.readAsString();
    if (savedSha.trim() != remoteSha.trim()) {
      await localConfig.writeAsString(remoteContent);
      await localSha.writeAsString(remoteSha);
    }
  }

  static Future<ConfigRoot> loadFresh() async {
    await syncFromGithubIfChanged(force: true);
    return load();
  }

  /// Charge la config depuis le fichier local (supposé synchronisé).
  /// Si le local n’existe toujours pas, essaie l’asset embarqué en dernier recours.
  static Future<ConfigRoot> load() async {
    final localConfig = await _localConfigFile();
    String jsonStr;

    if (await localConfig.exists()) {
      jsonStr = await localConfig.readAsString();
    } else {
      // Back-up: asset embarqué (facultatif)
      jsonStr = await rootBundle.loadString('assets/config.json');
    }

    // Parse
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    return ConfigRoot.fromJson(data);
  }
}
