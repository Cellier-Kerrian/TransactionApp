import 'package:flutter/material.dart';
import '../core/services/github_service.dart';
import '../user_config.dart';
import '../core/services/reload_bus.dart';
import '../core/config/config_loader.dart';

class GithubTestResult {
  final bool ok;
  final bool fileExists;
  final String message;
  final Color color;
  const GithubTestResult({
    required this.ok,
    required this.fileExists,
    required this.message,
    required this.color,
  });
}

Future<GithubTestResult?> showGithubInfoDialog(BuildContext context) async {
  return showDialog<GithubTestResult?>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Connexion GitHub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Auteur', UserConfig.GITHUB_OWNER),
            _kv('Repo', UserConfig.GITHUB_REPO),
            _kv('Branche', UserConfig.GITHUB_BRANCH),
            _kv('Utilisateur', UserConfig.USER_NAME),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: FilledButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('CODE'),
                  onPressed: () async {
                    final code = await showDialog<String>(
                      context: ctx,
                      builder: (ctx2) {
                        final controller = TextEditingController();
                        String? errorCode;
                        return StatefulBuilder(
                          builder: (ctx3, setSt) => AlertDialog(
                            title: const Text('Entrer le code'),
                            content: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              obscureText: true,
                              decoration: InputDecoration(counterText: '', errorText: errorCode),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx2).pop(null), child: const Text('Annuler')),
                              TextButton(
                                onPressed: () {
                                  final v = controller.text.trim();
                                  final ok = v == UserConfig.CODE_TOKEN || v == UserConfig.CODE_USERNAME || v == '9999';
                                  if (!ok) { setSt(() => errorCode = 'Code invalide'); return; }
                                  Navigator.of(ctx2).pop(v);
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    if (code == null) return;

                    if (code == UserConfig.CODE_TOKEN) {
                      final token = await showDialog<String>(
                        context: ctx,
                        builder: (ctx2) {
                          final c = TextEditingController();
                          bool saving = false;
                          String? error;
                          return StatefulBuilder(
                            builder: (ctx3, setSt) => AlertDialog(
                              title: const Text("Entrer le nouveau token à Github"),
                              content: TextField(
                                controller: c,
                                obscureText: true,
                                decoration: InputDecoration(hintText: 'GITHUB_TOKEN', errorText: error),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx2).pop(null), child: const Text('Annuler')),
                                TextButton(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                    final v = c.text.trim();
                                    if (v.isEmpty) {
                                      setSt(() => error = 'Requis');
                                      return;
                                    }
                                    setSt(() {
                                      saving = true;
                                      error = null;
                                    });
                                    final ok = await GithubService(v).validateToken();
                                    if (!ok) {
                                      setSt(() {
                                        saving = false;
                                        error = 'Token invalide';
                                      });
                                      return;
                                    }
                                    if (ctx2.mounted) Navigator.of(ctx2).pop(v);
                                  },
                                  child: const Text('Enregistrer'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                      if (token == null || token.isEmpty) return;
                      await UserConfig.setGitHubToken(token);
                      await ConfigLoader.syncFromGithubIfChanged(force: true);
                      TransactionsRefresher.instance.reload();
                      if (ctx.mounted) Navigator.of(ctx).pop(null);
                      return;
                    }

                    if (code == UserConfig.CODE_USERNAME) {
                      final name = await showDialog<String>(
                        context: ctx,
                        builder: (ctx2) {
                          final c = TextEditingController(text: UserConfig.USER_NAME);
                          String? error;
                          bool saving = false;
                          return StatefulBuilder(
                            builder: (ctx3, setSt) => AlertDialog(
                              title: const Text("Entrer le nouvel utilisateur"),
                              content: TextField(
                                controller: c,
                                decoration: InputDecoration(hintText: 'USER_NAME', errorText: error),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx2).pop(null), child: const Text('Annuler')),
                                TextButton(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                    final v = c.text.trim();
                                    if (v.isEmpty) { setSt(() => error = 'Requis'); return; }
                                    setSt(() { saving = true; error = null; });

                                    final gh = GithubService(UserConfig.GITHUB_TOKEN);
                                    final cfgPath = _pathWithUser(UserConfig.CONFIG_PATH, v, UserConfig.USER_NAME);
                                    final path = GithubPath(
                                      owner: UserConfig.GITHUB_OWNER,
                                      repo: UserConfig.GITHUB_REPO,
                                      branch: UserConfig.GITHUB_BRANCH,
                                      path: cfgPath,
                                    );
                                    try {
                                      final res = await gh.fetchFile(path);
                                      final exists = !(res.sha == null && res.content.isEmpty);
                                      if (!exists) {
                                        setSt(() { saving = false; error = 'Utilisateur introuvable'; });
                                        return;
                                      }
                                    } catch (_) {
                                      setSt(() { saving = false; error = 'Utilisateur introuvable'; });
                                      return;
                                    }

                                    if (ctx2.mounted) Navigator.of(ctx2).pop(v);
                                  },
                                  child: const Text('Enregistrer'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                      if (name == null || name.isEmpty) return;
                      await UserConfig.setUserName(name);
                      await ConfigLoader.syncFromGithubIfChanged(force: true);
                      TransactionsRefresher.instance.reload();
                      if (ctx.mounted) Navigator.of(ctx).pop(null);
                      return;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('RELOAD'),
                  onPressed: () async {
                    TransactionsRefresher.instance.reload();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Tester la connexion'),
                onPressed: () async {
                  if (UserConfig.USER_NAME.isEmpty || UserConfig.GITHUB_TOKEN.isEmpty) {
                    String missing = '';
                    if (UserConfig.USER_NAME.isEmpty) missing += 'USER_NAME ';
                    if (UserConfig.GITHUB_TOKEN.isEmpty) {
                      if (missing.isNotEmpty) missing += 'et ';
                      missing += 'GITHUB_TOKEN';
                    }

                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Veuillez renseigner $missing')),
                      );
                    }
                    return;
                  }

                  final gh = GithubService(UserConfig.GITHUB_TOKEN);
                  final path = GithubPath(
                    owner: UserConfig.GITHUB_OWNER,
                    repo: UserConfig.GITHUB_REPO,
                    branch: UserConfig.GITHUB_BRANCH,
                    path: UserConfig.CSV_PATH,
                  );

                  try {
                    final res = await gh.fetchFile(path);
                    if (res.sha == null && res.content.isEmpty) {
                      Navigator.of(ctx).pop(const GithubTestResult(
                        ok: true,
                        fileExists: false,
                        message: 'Connexion OK — fichier ajouter.',
                        color: Colors.orange,
                      ));
                    } else {
                      Navigator.of(ctx).pop(const GithubTestResult(
                        ok: true,
                        fileExists: true,
                        message: 'Connexion OK — fichier accessible.',
                        color: Colors.green,
                      ));
                    }
                  } catch (e) {
                    Navigator.of(ctx).pop(GithubTestResult(
                      ok: false,
                      fileExists: false,
                      message: 'Échec de connexion : $e',
                      color: Colors.red,
                    ));
                  }
                }
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Fermer'),
          ),
        ],
      );
    },
  );
}

String _configPathForUser(String user) {
  final current = UserConfig.CONFIG_PATH;
  final withReplace = current.replaceFirst('/${UserConfig.USER_NAME}/', '/$user/');
  if (withReplace != current) return withReplace;
  return 'transaction-manager/data/$user/config.json';
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text('$k :', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

String _pathWithUser(String template, String newUser, String currentUser) {
  if (template.contains('{USER_NAME}')) return template.replaceAll('{USER_NAME}', newUser);
  if (template.contains('/$currentUser/')) return template.replaceAll('/$currentUser/', '/$newUser/');
  return template;
}

