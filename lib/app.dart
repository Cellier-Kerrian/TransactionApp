import 'package:flutter/material.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/transactions/add_transaction_screen.dart';
import 'widgets/github_info_dialog.dart';
import 'theme.dart';
import 'core/services/reload_bus.dart';
import 'core/services/github_service.dart';
import 'core/services/csv_service.dart';
import 'user_config.dart';

class ComptesApp extends StatefulWidget {
  const ComptesApp({super.key});
  @override
  State<ComptesApp> createState() => _ComptesAppState();
}

class _ComptesAppState extends State<ComptesApp> {
  int _index = 0;
  final _navKey = GlobalKey<NavigatorState>();
  int _reloadVersion = 0;
  late final VoidCallback _onReload;

  VoidCallback? _dashboardBackAction;
  String? _lastUpdateDate;

  @override
  void initState() {
    super.initState();
    _fetchLastUpdateDate();

    _onReload = () {
      setState(() => _reloadVersion++);
      _fetchLastUpdateDate();
    };
    TransactionsRefresher.instance.addListener(_onReload);
  }

  @override
  void dispose() {
    TransactionsRefresher.instance.removeListener(_onReload);
    super.dispose();
  }

  Future<void> _fetchLastUpdateDate() async {
    try {
      final gh = GithubService(UserConfig.GITHUB_TOKEN);
      final path = GithubPath(
        owner: UserConfig.GITHUB_OWNER,
        repo: UserConfig.GITHUB_REPO,
        branch: UserConfig.GITHUB_BRANCH,
        path: UserConfig.LOGS_PATH,
      );

      final resp = await gh.fetchFile(path);
      if (resp.content.isNotEmpty) {
        final rows = CsvService().parseCsv(resp.content);
        if (rows.length > 1 && rows[1].isNotEmpty) {
          final rawDate = rows[1][0];
          String formattedDate = rawDate;

          if (rawDate.length >= 16) {
            final month = rawDate.substring(5, 7);
            final day   = rawDate.substring(8, 10);
            final hour  = rawDate.substring(11, 13);
            final min   = rawDate.substring(14, 16);
            formattedDate = "$day/$month $hour:$min";
          }

          if (mounted) {
            setState(() {
              _lastUpdateDate = formattedDate;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Erreur recup date logs: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TransactionsApp',
      theme: buildAppTheme(),
      navigatorKey: _navKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TransactionsApp'),
          leading: (_index == 0 && _dashboardBackAction != null)
              ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _dashboardBackAction,
          )
              : null,
          actions: [
            IconButton(
              tooltip: 'Infos GitHub',
              icon: const Icon(Icons.info_outline),
              onPressed: () async {
                final ctx = _navKey.currentContext!;
                final res = await showGithubInfoDialog(ctx);
                if (res != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text(res.message), backgroundColor: res.color),
                  );
                }
              },
            ),
          ],
        ),

        body: NotificationListener<DashboardBackNotification>(
          onNotification: (notification) {
            setState(() {
              _dashboardBackAction = notification.canPop ? notification.popAction : null;
            });
            return true;
          },
          child: _index == 0
              ? DashboardScreen(key: ValueKey('dash-$_reloadVersion'))
              : AddTransactionScreen(key: ValueKey('add-$_reloadVersion')),
        ),

        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Condition ajoutée ici : _index == 0 (Dashboard uniquement)
            if (_index == 0 && _lastUpdateDate != null)
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 4),
                child: Text(
                  "$_lastUpdateDate",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),

            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) {
                setState(() {
                  _index = i;
                  if (_index != 0) {
                    _dashboardBackAction = null;
                  }
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Transactions',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}