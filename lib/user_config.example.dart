import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserConfig {
  // ⚠️ Exemple uniquement, à copier en user_config.dart et à personnaliser

  static String USER_NAME = '';
  static String GITHUB_TOKEN  = '';

  static String get CSV_PATH => "data/${USER_NAME}/user_transactions.csv";
  static String get CONFIG_PATH => "data/${USER_NAME}/config.json";

  static const String GITHUB_OWNER  = "owner_name";
  static const String GITHUB_REPO   = "repo_name";
  static const String GITHUB_BRANCH = "main";

  static const Color APP_SEED_COLOR = Colors.grey;

  static String CODE_USERNAME = '0001';
  static String CODE_TOKEN = '0000';

  static const String _kUserName = 'user_name';
  static const String _kToken = 'github_token';

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    USER_NAME = p.getString(_kUserName) ?? '';
    GITHUB_TOKEN = p.getString(_kToken) ?? '';
  }

  static Future<void> setUserName(String name) async {
    USER_NAME = name;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUserName, name);
  }

  static Future<void> setGitHubToken(String token) async {
    GITHUB_TOKEN = token;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
  }
}
