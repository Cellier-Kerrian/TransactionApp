import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/config/config_loader.dart';
import '../../core/config/config_model.dart';
import '../../core/models/log_model.dart';
import '../../core/services/csv_service.dart';
import '../../core/services/github_service.dart';
import '../../user_config.dart';

// ─── 1. CLASSES UTILITAIRES & MODÈLES LOCAUX ─────────────────────────────────

class DashboardBackNotification extends Notification {
  final bool canPop;
  final VoidCallback popAction;
  DashboardBackNotification({required this.canPop, required this.popAction});
}

class TransactionLite {
  final String annee;
  final String feuille;
  final String cleNom;
  final String nom;
  final double montant;
  final bool previsionnel;
  final String cellPrevisionnel;

  TransactionLite({
    required this.annee,
    required this.feuille,
    required this.cleNom,
    required this.nom,
    required this.montant,
    required this.previsionnel,
    required this.cellPrevisionnel,
  });

  factory TransactionLite.fromCsv(List<dynamic> row, Map<String, int> headerMap) {
    String val(String key) {
      final idx = headerMap[key];
      if (idx != null && idx < row.length) {
        return row[idx]?.toString().trim() ?? '';
      }
      return '';
    }

    return TransactionLite(
      annee: val('Annee'),
      feuille: val('Feuille'),
      cleNom: val('Cle_Nom'),
      nom: val('Nom'),
      montant: double.tryParse(val('Montant').replaceAll(',', '.')) ?? 0.0,
      previsionnel: val('Previsionnel').toLowerCase() == 'true',
      cellPrevisionnel: val('Cell_Previsionnel'),
    );
  }
}

class DashboardFullData {
  final ConfigRoot config;
  final List<LogEntry> allLogs;
  final List<TransactionLite> allTransactions;

  DashboardFullData({
    required this.config,
    required this.allLogs,
    required this.allTransactions,
  });
}

// ─── 2. WRAPPER PRINCIPAL (NAVIGATEUR) ───────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _NavigatorHistoryObserver _navObserver;

  @override
  void initState() {
    super.initState();
    _navObserver = _NavigatorHistoryObserver(onHistoryChanged: _notifyMainScreen);
  }

  void _notifyMainScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final canPop = _navigatorKey.currentState?.canPop() ?? false;
      DashboardBackNotification(
        canPop: canPop,
        popAction: () {
          if (_navigatorKey.currentState?.canPop() ?? false) {
            _navigatorKey.currentState?.pop();
          }
        },
      ).dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    _notifyMainScreen();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final navigator = _navigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Navigator(
        key: _navigatorKey,
        observers: [_navObserver],
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name == '/') {
            return MaterialPageRoute(builder: (_) => const _DashboardList());
          } else if (settings.name == '/details') {
            final args = settings.arguments as Map<String, dynamic>;
            return PageRouteBuilder(
              pageBuilder: (_, __, ___) => _AccountDetailsScreen(
                compte: args['compte'] as Compte,
                allLogs: args['allLogs'] as List<LogEntry>,
                allTransactions: args['allTransactions'] as List<TransactionLite>,
              ),
              transitionsBuilder: (_, animation, __, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.ease;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(position: animation.drive(tween), child: child);
              },
            );
          }
          return MaterialPageRoute(builder: (_) => const _DashboardList());
        },
      ),
    );
  }
}

class _NavigatorHistoryObserver extends NavigatorObserver {
  final VoidCallback onHistoryChanged;
  _NavigatorHistoryObserver({required this.onHistoryChanged});
  @override
  void didPush(Route route, Route? previousRoute) => onHistoryChanged();
  @override
  void didPop(Route route, Route? previousRoute) => onHistoryChanged();
}

// ─── 3. ECRAN LISTE (DASHBOARD) ──────────────────────────────────────────────

class _DashboardList extends StatefulWidget {
  const _DashboardList();

  @override
  State<_DashboardList> createState() => _DashboardListState();
}

class _DashboardListState extends State<_DashboardList> {
  final _githubService = GithubService(UserConfig.GITHUB_TOKEN);
  final _csvService = CsvService();

  late Future<DashboardFullData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<DashboardFullData> _loadData() async {
    final results = await Future.wait([
      ConfigLoader.loadFresh(),
      _githubService.fetchFile(GithubPath(
        owner: UserConfig.GITHUB_OWNER,
        repo: UserConfig.GITHUB_REPO,
        branch: 'main',
        path: UserConfig.LOGS_PATH,
      )),
      _githubService.fetchFile(GithubPath(
        owner: UserConfig.GITHUB_OWNER,
        repo: UserConfig.GITHUB_REPO,
        branch: 'main',
        path: UserConfig.CSV_PATH,
      )),
    ]);

    final config = results[0] as ConfigRoot;
    final logResponse = results[1] as GithubFileResponse;
    final transResponse = results[2] as GithubFileResponse;

    String cleanHeader(String h) {
      return h.replaceAll('\uFEFF', '').trim();
    }

    final List<LogEntry> logs = [];
    if (logResponse.content.isNotEmpty) {
      final rows = _csvService.parseCsv(logResponse.content);
      if (rows.isNotEmpty) {
        final headers = rows[0].map((e) => cleanHeader(e.toString())).toList();
        final dataRows = rows.sublist(1).where((row) => row.isNotEmpty).toList();
        logs.addAll(dataRows.map((row) => LogEntry.fromCsv(row, headers)));
      }
    }

    final List<TransactionLite> transactions = [];
    if (transResponse.content.isNotEmpty) {
      final rows = _csvService.parseCsv(transResponse.content);
      if (rows.isNotEmpty) {
        final headers = rows[0].map((e) => cleanHeader(e.toString())).toList();
        final headerMap = {for (var i = 0; i < headers.length; i++) headers[i]: i};

        final dataRows = rows.sublist(1).where((row) => row.isNotEmpty).toList();
        transactions.addAll(dataRows.map((row) => TransactionLite.fromCsv(row, headerMap)));
      }
    }

    return DashboardFullData(
      config: config,
      allLogs: logs,
      allTransactions: transactions,
    );
  }

  LogEntry? _findCurrentLog(Compte compte, List<LogEntry> logs) {
    final now = DateTime.now();
    const months = [
      'JANVIER', 'FEVRIER', 'MARS', 'AVRIL', 'MAI', 'JUIN',
      'JUILLET', 'AOUT', 'SEPTEMBRE', 'OCTOBRE', 'NOVEMBRE', 'DECEMBRE'
    ];
    final currentMonthName = months[now.month - 1];

    if (compte.feuilles.length == 1) {
      return logs.where((l) => l.feuille == compte.feuilles.first).firstOrNull;
    } else {
      return logs.where((l) => l.feuille == currentMonthName && compte.feuilles.contains(l.feuille)).firstOrNull;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardFullData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final fullData = snapshot.data;
        if (fullData == null || fullData.config.comptes.isEmpty) {
          return const Center(child: Text("Aucune donnée disponible"));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: fullData.config.comptes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final compte = fullData.config.comptes[index];
            final currentLog = _findCurrentLog(compte, fullData.allLogs);

            return _AccountCard(
              accountName: compte.nom,
              log: currentLog,
              onTap: () {
                Navigator.of(context).pushNamed(
                  '/details',
                  arguments: {
                    'compte': compte,
                    'allLogs': fullData.allLogs,
                    'allTransactions': fullData.allTransactions,
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String accountName;
  final LogEntry? log;
  final VoidCallback onTap;

  const _AccountCard({required this.accountName, required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  accountName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (log != null) ...[
                    Text("Théo: ${log!.tReste.toStringAsFixed(2)} €", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text("Réel: ${log!.rReste.toStringAsFixed(2)} €",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (log!.rReste < 0) ? Colors.red : Colors.green
                        )
                    ),
                  ] else ...[
                    const Text("Données indisponibles", style: TextStyle(fontSize: 12, color: Colors.grey))
                  ]
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 4. ECRAN DETAIL (AVEC LOGIQUE CORRIGÉE) ─────────────────────────────────

class _AccountDetailsScreen extends StatefulWidget {
  final Compte compte;
  final List<LogEntry> allLogs;
  final List<TransactionLite> allTransactions;

  const _AccountDetailsScreen({
    required this.compte,
    required this.allLogs,
    required this.allTransactions,
  });

  @override
  State<_AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<_AccountDetailsScreen> {
  late String _selectedFeuille;
  bool _showProjected = false;

  static const _months = [
    'JANVIER', 'FEVRIER', 'MARS', 'AVRIL', 'MAI', 'JUIN',
    'JUILLET', 'AOUT', 'SEPTEMBRE', 'OCTOBRE', 'NOVEMBRE', 'DECEMBRE'
  ];

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  void _initializeSelection() {
    final currentMonthIndex = DateTime.now().month - 1;
    final currentMonthName = _months[currentMonthIndex];
    if (widget.compte.feuilles.contains(currentMonthName)) {
      _selectedFeuille = currentMonthName;
    } else {
      _selectedFeuille = widget.compte.feuilles.first;
    }
  }

  LogEntry? _getLogForSelection() {
    try {
      return widget.allLogs.firstWhere((l) => l.feuille == _selectedFeuille);
    } catch (_) {
      return null;
    }
  }

  String _getTransactionName(String cle) {
    try {
      return widget.compte.types.firstWhere((t) => t.cle == cle).nom;
    } catch (_) {
      return cle;
    }
  }

  /// Calcul des soldes selon la nouvelle logique
  Map<String, double> _calculateBalances(LogEntry? log, List<TransactionLite> transactions) {
    double tReste = log?.tReste ?? 0.0;
    double rReste = log?.rReste ?? 0.0;

    if (!_showProjected) {
      return {'tReste': tReste, 'rReste': rReste};
    }

    for (var t in transactions) {
      double montant = t.montant;
      // Gestion du signe (Entrée/Sortie)
      if (t.cleNom.startsWith('out_')) {
        montant = -montant;
      }
      // Note : On considère que tout ce qui n'est pas 'out_' est une entrée (positif)

      // 1. Solde RÉEL (Projeté)
      // N'inclut QUE les transactions qui NE SONT PAS prévisionnelles (donc effectuées)
      // Si c'est une prévision (futur), le solde réel (banque) ne bouge pas.
      if (!t.previsionnel) {
        rReste += montant;
      }

      // 2. Solde THÉORIQUE (Projeté)
      // Inclut TOUTES les transactions qui ne sont pas déjà connues d'Excel (Cell == None)
      // Que ce soit prévisionnel ou réel, si Excel ne l'a pas, il faut l'ajouter au théorique.
      bool hasCell = t.cellPrevisionnel != 'None' && t.cellPrevisionnel.trim().isNotEmpty;
      if (!hasCell) {
        tReste += montant;
      }
    }

    return {'tReste': tReste, 'rReste': rReste};
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleSheets = widget.compte.feuilles.length > 1;
    final currentLog = _getLogForSelection();

    final envelopes = Map<String, EnvelopeData>.from(currentLog?.envelopes ?? {});
    final ecartData = envelopes.remove("Ecart");

    final sheetTransactions = widget.allTransactions
        .where((t) => t.feuille.trim() == _selectedFeuille.trim())
        .toList();

    final balances = _calculateBalances(currentLog, sheetTransactions);

    return Scaffold(
      primary: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nom du Compte
                  Flexible(
                    child: Text(
                      widget.compte.nom,
                      style: Theme.of(context).textTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Contrôles
                  Row(
                    children: [
                      // Selecteur de feuille (si multiple) - GAUCHE
                      if (hasMultipleSheets) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFeuille,
                              isDense: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() => _selectedFeuille = newValue);
                                }
                              },
                              items: widget.compte.feuilles.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Bouton Style Transactions - DROITE
                      GestureDetector(
                        onTap: () => setState(() => _showProjected = !_showProjected),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Prévisionnel'),
                              const SizedBox(width: 8),
                              Switch(
                                value: _showProjected,
                                onChanged: (val) => setState(() => _showProjected = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 30),

              // --- CONTENU ---
              Expanded(
                child: currentLog == null
                    ? Center(
                  child: Text("Aucune donnée pour $_selectedFeuille", style: const TextStyle(color: Colors.grey)),
                )
                    : SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                        _DetailRow(
                            label: _showProjected ? "Solde Théorique (Projeté)" : "Solde Théorique",
                            amount: balances['tReste']!,
                            color: Colors.grey
                        ),
                        const SizedBox(height: 24),
                        _DetailRow(
                            label: _showProjected ? "Solde Réel (Projeté)" : "Solde Réel",
                            amount: balances['rReste']!,
                            isBold: true
                        ),

                        const SizedBox(height: 40),

                        // Enveloppes
                        if (envelopes.isNotEmpty || ecartData != null) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Enveloppes",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (ecartData != null) ...[
                            SizedBox(
                              width: double.infinity,
                              child: _EnvelopeCard(name: "Ecart", data: ecartData),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (envelopes.isNotEmpty)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: envelopes.length,
                              itemBuilder: (context, index) {
                                final key = envelopes.keys.elementAt(index);
                                final value = envelopes[key]!;
                                return _EnvelopeCard(name: key, data: value);
                              },
                            ),
                          const SizedBox(height: 40),
                        ],

                        // Transactions
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Transactions",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (sheetTransactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              "Aucune transaction pour $_selectedFeuille",
                              style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 20,
                              columns: [
                                const DataColumn(label: Text('Date')),
                                if (hasMultipleSheets) const DataColumn(label: Text('Mois')),
                                const DataColumn(label: Text('Type de transaction')), // Corrigé
                                const DataColumn(label: Text('Nom')),
                                const DataColumn(label: Text('Montant')),
                                const DataColumn(label: Text('Prév.')),
                              ],
                              rows: sheetTransactions.map((t) {
                                return DataRow(cells: [
                                  DataCell(Text(t.annee)),
                                  if (hasMultipleSheets) DataCell(Text(t.feuille)),
                                  DataCell(Text(_getTransactionName(t.cleNom))), // Corrigé
                                  DataCell(Text(t.nom)),
                                  DataCell(Text("${t.montant.toStringAsFixed(2)} €")),
                                  DataCell(
                                      Icon(
                                        t.previsionnel ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                                        size: 16,
                                        color: t.previsionnel ? Colors.green : Colors.grey,
                                      )
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final Color? color;

  const _DetailRow({
    required this.label,
    required this.amount,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final finalColor = color ?? (amount == 0 ? Colors.black : (amount < 0 ? Colors.red : Colors.green));
    final style = isBold
        ? TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: finalColor)
        : TextStyle(fontSize: 18, color: finalColor);

    return Column(
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text("${amount.toStringAsFixed(2)} €", style: style),
      ],
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  final String name;
  final EnvelopeData data;

  const _EnvelopeCard({required this.name, required this.data});

  @override
  Widget build(BuildContext context) {
    final amount = data.balance;
    final max = data.maxLimit;

    if (max == null) {
      return _buildStandardCard(amount);
    }

    return _buildGaugeCard(amount, max);
  }

  Widget _buildStandardCard(double amount) {
    Color textColor = Colors.black;
    if (amount > 0.001) textColor = Colors.green;
    else if (amount < -0.001) textColor = Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              "${amount.toStringAsFixed(2)} €",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeCard(double current, double max) {
    final isOverBudget = current < 0;
    final used = max - current;
    double ratio = (max == 0) ? 0.0 : (used / max);

    if (ratio < 0) ratio = 0;
    if (ratio > 1) ratio = 1;

    Color ringColor;
    if (isOverBudget) {
      ringColor = Colors.black;
      ratio = 1.0;
    } else {
      ringColor = Color.lerp(Colors.green, Colors.red, ratio) ?? Colors.red;
    }

    final showCircle = ratio > 0.01;

    Color textColor = Colors.black;
    if (current > 0.001) textColor = Colors.green;
    else if (current < -0.001) textColor = Colors.red;
    if (isOverBudget) textColor = Colors.black;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (showCircle)
                    AspectRatio(
                      aspectRatio: 1,
                      child: CustomPaint(
                        painter: _RingPainter(
                          percentage: ratio,
                          color: ringColor,
                          strokeWidth: 6,
                        ),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${current.toStringAsFixed(2)} €",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor
                        ),
                      ),
                      Text(
                        "/ ${max.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.percentage,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percentage,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.color != color;
  }
}