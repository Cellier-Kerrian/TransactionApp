import 'package:flutter/material.dart';

import '../../core/config/config_loader.dart';
import '../../core/config/config_model.dart';
import '../../core/models/transaction_model.dart';
import '../../core/services/csv_service.dart';
import '../../core/services/github_service.dart';
import '../../user_config.dart';
import 'csv_manager_screen.dart';

class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();

  ConfigRoot? cfg;

  Compte? _selectedCompte;
  String? _selectedFeuille;
  TypeTransaction? _selectedType;
  final _nomCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  bool _previsionnel = false;

  // 🔹 Année (nouveau champ)
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _selectedYear = DateTime.now().year; // défaut = année courante
  }

  Future<void> _loadConfig() async {
    final c = await ConfigLoader.loadFresh();
    if (!mounted) return;
    setState(() => cfg = c);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  List<int> _yearOptions() {
    final y = DateTime.now().year;
    return List.generate(5, (i) => y - 1 + i);
  }

  @override
  Widget build(BuildContext context) {
    if (cfg == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final comptes = cfg!.comptes;
    final feuilles = _selectedCompte?.feuilles ?? const <String>[];
    final types = _selectedCompte?.types ?? const <TypeTransaction>[];

    // Logique d'affichage progressif
    final hasCompte = _selectedCompte != null;
    final hasMultipleFeuilles = feuilles.length > 1;
    final hasFeuille = _selectedFeuille != null || (!hasMultipleFeuilles && hasCompte);
    final showFeuilleSelector = hasCompte && hasMultipleFeuilles;
    final showTypeSelector = hasCompte && hasFeuille;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // 1) COMPTE — toujours visible
          DropdownButtonFormField<Compte>(
            isExpanded: true,
            value: _selectedCompte,
            decoration: const InputDecoration(labelText: 'Compte'),
            items: comptes
                .map((c) => DropdownMenuItem(
              value: c,
              child: Text(c.nom, overflow: TextOverflow.ellipsis),
            ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedCompte = v;
                _selectedType = null;

                final fs = v?.feuilles ?? const <String>[];
                if (fs.length == 1) {
                  _selectedFeuille = fs.first;
                } else {
                  _selectedFeuille = null;
                }
              });
            },
            validator: (v) => v == null ? 'Choisir un compte' : null,
          ),
          const SizedBox(height: 12),

          // 2) FEUILLE — visible seulement s'il y a >1 feuille
          if (showFeuilleSelector) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedFeuille,
              decoration: const InputDecoration(labelText: 'Feuille'),
              items: feuilles
                  .map((f) => DropdownMenuItem(
                value: f,
                child: Text(f, overflow: TextOverflow.ellipsis),
              ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedFeuille = v),
              validator: (v) => v == null ? 'Choisir une feuille' : null,
            ),
            const SizedBox(height: 12),
          ],

          // 3) TYPE — visible seulement après que la feuille est déterminée
          if (showTypeSelector) ...[
            DropdownButtonFormField<TypeTransaction>(
              isExpanded: true,
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Type de transaction'),
              items: types
                  .map((t) => DropdownMenuItem(
                value: t,
                child: Text('${t.nom} (${t.cle})', overflow: TextOverflow.ellipsis),
              ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v),
              validator: (v) => v == null ? 'Choisir un type' : null,
            ),
            const SizedBox(height: 14),
          ],

          // 4) ANNÉE — toujours visible
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _selectedYear,
            decoration: const InputDecoration(labelText: 'Année'),
            items: _yearOptions()
                .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _selectedYear = v),
            validator: (v) => v == null ? 'Choisir une année' : null,
          ),
          const SizedBox(height: 12),

          // 5) Libellé + Montant
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _nomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Libellé',
                    hintText: 'Ex: Courses',
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Libellé requis' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _montantCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    hintText: '10.25',
                    prefixText: '€ ',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Montant requis';
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) return 'Montant invalide';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 6) Prévisionnel
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _previsionnel = !_previsionnel),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    const Expanded(child: Text('Prévisionnel')),
                    Switch(
                      value: _previsionnel,
                      onChanged: (val) => setState(() => _previsionnel = val),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Enregistrer'),
                  onPressed: _onSubmit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.table_rows),
                  label: const Text('Gérer le CSV'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CsvManagerScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final feuilles = _selectedCompte!.feuilles;
    if (_selectedFeuille == null && feuilles.length == 1) {
      _selectedFeuille = feuilles.first;
    }

    final montant = double.parse(_montantCtrl.text.replaceAll(',', '.'));

    final path = GithubPath(
      owner: UserConfig.GITHUB_OWNER,
      repo: UserConfig.GITHUB_REPO,
      branch: UserConfig.GITHUB_BRANCH,
      path: UserConfig.CSV_PATH,
    );
    final gh = GithubService(UserConfig.GITHUB_TOKEN);

    try {
      await gh.appendCsvRowWithAutoId(
        path,
        annee: _selectedYear!,
        feuille: _selectedFeuille!,
        cleNom: _selectedType!.cle,
        nom: _nomCtrl.text.trim(),
        montant: montant,
        previsionnel: _previsionnel,
        cellPrevisionnel: 'None',
        commitMessage: 'Add transaction (mobile)',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction ajoutée ✔'), backgroundColor: Colors.green),
      );

      _formKey.currentState!.reset();
      setState(() {
        _selectedYear = DateTime.now().year;
        _selectedCompte = null;
        _selectedFeuille = null;
        _selectedType = null;
        _nomCtrl.clear();
        _montantCtrl.clear();
        _previsionnel = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur GitHub: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
