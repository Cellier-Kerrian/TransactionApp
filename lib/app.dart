import 'package:flutter/material.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/transactions/add_transaction_screen.dart';
import 'widgets/github_info_dialog.dart';
import 'theme.dart';
import 'core/services/reload_bus.dart';

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

  @override
  void initState() {
    super.initState();
    _onReload = () => setState(() => _reloadVersion++);
    TransactionsRefresher.instance.addListener(_onReload);
  }

  @override
  void dispose() {
    TransactionsRefresher.instance.removeListener(_onReload);
    super.dispose();
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
          actions: [
            IconButton(
              tooltip: 'Infos GitHub',
              icon: const Icon(Icons.info_outline),
              onPressed: () async {
                final ctx = _navKey.currentContext!;
                final res = await showGithubInfoDialog(ctx);
                if (res != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(res.message), backgroundColor: res.color),
                  );
                }
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(key: ValueKey('dash-$_reloadVersion')),
            AddTransactionScreen(key: ValueKey('add-$_reloadVersion')),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
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
      ),
    );
  }
}
