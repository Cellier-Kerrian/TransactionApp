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

  // Variable pour stocker l'action de retour du Dashboard
  VoidCallback? _dashboardBackAction;

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
          // Affiche la flèche retour SI on est sur le Dashboard (index 0) ET qu'une action de retour existe
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
        // On écoute la notification envoyée par le DashboardScreen
        body: NotificationListener<DashboardBackNotification>(
          onNotification: (notification) {
            // On met à jour l'état pour afficher/cacher la flèche retour
            setState(() {
              if (notification.canPop) {
                _dashboardBackAction = notification.popAction;
              } else {
                _dashboardBackAction = null;
              }
            });
            return true;
          },
          // J'ai remplacé IndexedStack par un switch direct.
          // Cela permet de "tuer" le Dashboard quand on change d'onglet,
          // et donc de revenir à la liste (reset) quand on revient dessus.
          child: _index == 0
              ? DashboardScreen(key: ValueKey('dash-$_reloadVersion'))
              : AddTransactionScreen(key: ValueKey('add-$_reloadVersion')),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() {
              _index = i;
              // Si on quitte le dashboard, on efface le bouton retour
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
      ),
    );
  }
}