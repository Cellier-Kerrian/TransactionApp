import 'package:flutter/material.dart';

import '../../core/services/github_service.dart';
import '../../core/services/csv_service.dart';
import '../../user_config.dart';
import '../../core/config/config_loader.dart';
import '../../core/config/config_model.dart';

class CsvManagerScreen extends StatefulWidget {
  const CsvManagerScreen({super.key});

  @override
  State<CsvManagerScreen> createState() => _CsvManagerScreenState();
}

class _CsvManagerScreenState extends State<CsvManagerScreen> {
  bool _loading = true;
  String? _error;

  List<String> _headers = [];
  List<List<String>> _rows = [];

  late GithubPath _path;
  late GithubService _gh;
  String? _sha;

  ConfigRoot? _cfg;

  // Index des colonnes (calculés dynamiquement depuis _headers)
  int _idxId = -1;
  int _idxAnnee = -1;
  int _idxFeuille = -1;
  int _idxCleNom = -1;
  int _idxNom = -1;
  int _idxMontant = -1;
  int _idxPrev = -1; // Prévisionnel

  // Filtre par compte (null = Tous)
  String? _selectedCompteName;

  @override
  void initState() {
    super.initState();
    _gh = GithubService(UserConfig.GITHUB_TOKEN);
    _path = GithubPath(
      owner: UserConfig.GITHUB_OWNER,
      repo: UserConfig.GITHUB_REPO,
      branch: UserConfig.GITHUB_BRANCH,
      path: UserConfig.CSV_PATH,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _cfg ??= await ConfigLoader.load();

      final res = await _gh.fetchFile(_path);
      _sha = res.sha;
      final content = res.content;

      if (content.trim().isEmpty) {
        _headers = _cfg?.csvHeaders ??
            ['Id', 'Annee', 'Feuille', 'Cle_Nom', 'Nom', 'Montant', 'Previsionnel', 'Cell_Previsionnel'];
        _rows = [];
      } else {
        final parsed = CsvService().parseCsv(content);
        if (parsed.isEmpty) {
          _headers = _cfg?.csvHeaders ??
              ['Id', 'Annee', 'Feuille', 'Cle_Nom', 'Nom', 'Montant', 'Previsionnel', 'Cell_Previsionnel'];
          _rows = [];
        } else {
          _headers = parsed.first;
          _rows = parsed.sublist(1);
        }
      }

      _computeColumnIndexes();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ------------------ Helpers colonnes ------------------

  void _computeColumnIndexes() {
    final csv = CsvService();

    _idxId = -1;
    _idxAnnee = -1;
    _idxFeuille = -1;
    _idxCleNom = -1;
    _idxNom = -1;
    _idxMontant = -1;
    _idxPrev = -1;

    for (int i = 0; i < _headers.length; i++) {
      switch (csv.normalizeHeader(_headers[i])) {
        case 'id':
          _idxId = i;
          break;
        case 'annee':
          _idxAnnee = i;
          break;
        case 'feuille':
          _idxFeuille = i;
          break;
        case 'cle_nom':
          _idxCleNom = i;
          break;
        case 'nom':
          _idxNom = i;
          break;
        case 'montant':
          _idxMontant = i;
          break;
        case 'previsionnel':
        case 'prevsionnel':
          _idxPrev = i;
          break;
      }
    }
  }

  String _getCell(List<String> row, int idx) =>
      (idx >= 0 && idx < row.length) ? row[idx] : '';

  bool _parsePrev(String s) {
    final v = s.trim().toLowerCase();
    return v == 'vrai' || v == 'true' || v == '1' || v == 'oui';
  }

  // ------------------ Helpers comptes/feuilles ------------------

  List<String> _allCompteNames() {
    if (_cfg == null) return const [];
    return _cfg!.comptes.map((c) => c.nom).toList();
  }

  Compte? _compteByName(String? name) {
    if (_cfg == null || name == null) return null;
    try {
      return _cfg!.comptes.firstWhere((c) => c.nom == name);
    } catch (_) {
      return null;
    }
  }

  /// Nom du compte pour une feuille donnée
  String? _compteNameForFeuille(String feuille) {
    if (_cfg == null) return null;
    for (final c in _cfg!.comptes) {
      if (c.feuilles.contains(feuille)) return c.nom;
    }
    return null;
  }

  bool _compteHasMultipleFeuilles(String? compteName) {
    final c = _compteByName(compteName);
    if (c == null) return false;
    return c.feuilles.length > 1;
  }

  // ------------------ Filtrage ------------------

  List<List<String>> _filteredRows() {
    if (_selectedCompteName == null) return _rows; // Tous
    return _rows.where((r) {
      final feuille = _getCell(r, _idxFeuille);
      final compte = _compteNameForFeuille(feuille);
      return compte == _selectedCompteName;
    }).toList();
  }

  // ------------------ Actions ------------------

  Future<void> _deleteRow(int filteredIndex) async {
    try {
      if (_idxId < 0) {
        throw 'Colonne "Id" introuvable dans le CSV.';
      }

      // Id depuis la vue filtrée actuelle
      final filtered = _filteredRows();
      if (filteredIndex < 0 || filteredIndex >= filtered.length) return;
      final rowView = filtered[filteredIndex];
      final idStr = _getCell(rowView, _idxId).trim();

      // Re-fetch latest
      final latest = await _gh.fetchFile(_path);
      _sha = latest.sha;
      final parsed = CsvService().parseCsv(latest.content);
      if (parsed.isEmpty) return;
      final headers = parsed.first;
      final rows = parsed.sublist(1);

      final idColLatest = CsvService().indexOfId(headers);
      if (idColLatest < 0) throw 'Colonne "Id" introuvable (fichier distant).';

      // Position absolue par Id
      final absolutePos = rows.indexWhere(
              (r) => idColLatest < r.length && r[idColLatest].trim() == idStr);
      if (absolutePos < 0) return;

      // Supprimer + push
      rows.removeAt(absolutePos);
      final newContent = CsvService().toCsvString(headers, rows);
      await _gh.putFile(_path, newContent, message: 'Delete transaction', sha: _sha);

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction supprimée'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Confirmation avec encart jaune & icône, et logique feuille/compte
  Future<void> _confirmDelete(int filteredIndex) async {
    final rows = _filteredRows();
    if (filteredIndex < 0 || filteredIndex >= rows.length) return;

    final r        = rows[filteredIndex];
    final nom      = _getCell(r, _idxNom);
    final montant  = _getCell(r, _idxMontant);
    final feuille  = _getCell(r, _idxFeuille);
    final compte   = _compteNameForFeuille(feuille) ?? '—';
    final showFeuille = _compteHasMultipleFeuilles(compte);

    final t = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la transaction ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom en gras
            Text(
              nom,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Compte (toujours) + Feuille (si >1 feuilles pour ce compte)
            Text(
              showFeuille ? '$compte – $feuille' : compte,
              style: t.bodyMedium,
            ),
            const SizedBox(height: 2),

            // Montant
            Text('$montant €', style: t.bodyMedium),
            const SizedBox(height: 12),

            // Alerte visuelle
            Container(
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette action est irréversible.',
                      style: t.bodyMedium?.copyWith(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteRow(filteredIndex);
    }
  }

  Future<void> _editRow(int filteredIndex) async {
    final filtered = _filteredRows();
    if (filteredIndex < 0 || filteredIndex >= filtered.length) return;

    final current = List<String>.from(filtered[filteredIndex]);

    // Valeurs courantes depuis la vue (via index dynamiques)
    int selectedYear = int.tryParse(_getCell(current, _idxAnnee)) ?? DateTime.now().year;
    String feuille = _getCell(current, _idxFeuille);
    String cleNom  = _getCell(current, _idxCleNom);
    final libelleC = TextEditingController(text: _getCell(current, _idxNom));
    final montantC = TextEditingController(text: _getCell(current, _idxMontant));
    bool previsionnel = _parsePrev(_getCell(current, _idxPrev));

    // Compte initial depuis la feuille
    String? compteName = _compteNameForFeuille(feuille);

    List<String> _feuillesForCompte(String? cName) {
      if (cName == null || _cfg == null) return const <String>[];
      final c = _compteByName(cName);
      return c?.feuilles ?? const <String>[];
    }

    List<TypeTransaction> _typesForCompte(String? cName) {
      if (cName == null || _cfg == null) return const <TypeTransaction>[];
      final c = _compteByName(cName);
      return c?.types ?? const <TypeTransaction>[];
    }

    final allComptes = _allCompteNames();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();

        List<String> feuillesCourantes = _feuillesForCompte(compteName);
        List<TypeTransaction> typesCourants = _typesForCompte(compteName);

        // normaliser la feuille et la clé
        if (!feuillesCourantes.contains(feuille) && feuillesCourantes.isNotEmpty) {
          feuille = feuillesCourantes.first;
        }
        String? cleCourante = typesCourants.any((t) => t.cle == cleNom)
            ? cleNom
            : (typesCourants.isNotEmpty ? typesCourants.first.cle : null);

        List<int> _yearOptions() {
          final y = DateTime.now().year;
          // de l'année précédente (y-1) à dans 3 ans (y+3)
          return List.generate(5, (i) => y - 1 + i);
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            void onCompteChanged(String? newCompte) {
              setState(() {
                compteName = newCompte;
                feuillesCourantes = _feuillesForCompte(compteName);
                typesCourants = _typesForCompte(compteName);

                // si 1 seule feuille → auto
                if (feuillesCourantes.isNotEmpty) {
                  feuille = feuillesCourantes.first;
                } else {
                  feuille = '';
                }

                if (cleCourante == null || !typesCourants.any((t) => t.cle == cleCourante)) {
                  cleCourante = typesCourants.isNotEmpty ? typesCourants.first.cle : null;
                }
              });
            }

            void onFeuilleChanged(String? newFeuille) {
              if (newFeuille == null) return;
              setState(() {
                feuille = newFeuille;
                if (cleCourante == null || !typesCourants.any((t) => t.cle == cleCourante)) {
                  cleCourante = typesCourants.isNotEmpty ? typesCourants.first.cle : null;
                }
              });
            }

            final showFeuilleSelector = feuillesCourantes.length > 1;

            return AlertDialog(
              title: const Text('Modifier la transaction'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // COMPTE
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: compteName ?? (allComptes.isNotEmpty ? allComptes.first : null),
                        decoration: const InputDecoration(labelText: 'Compte'),
                        items: allComptes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: onCompteChanged,
                        validator: (v) => (v == null || v.isEmpty) ? 'Choisir un compte' : null,
                      ),
                      const SizedBox(height: 10),

                      // FEUILLE (afficher seulement s'il y a > 1)
                      if (showFeuilleSelector) ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: feuillesCourantes.contains(feuille)
                              ? feuille
                              : (feuillesCourantes.isNotEmpty ? feuillesCourantes.first : null),
                          decoration: const InputDecoration(labelText: 'Feuille'),
                          items: feuillesCourantes
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: onFeuilleChanged,
                          validator: (v) => (v == null || v.isEmpty) ? 'Choisir une feuille' : null,
                        ),
                        const SizedBox(height: 10),
                      ],

                      // TYPE (Cle_Nom) — dépend du compte
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: cleCourante,
                        decoration: const InputDecoration(labelText: 'Type de transaction'),
                        items: typesCourants
                            .map((t) => DropdownMenuItem(
                          value: t.cle,
                          child: Text('${t.nom} (${t.cle})', overflow: TextOverflow.ellipsis),
                        ))
                            .toList(),
                        onChanged: (v) => setState(() => cleCourante = v),
                        validator: (v) => (v == null || v.isEmpty) ? 'Choisir un type' : null,
                      ),
                      const SizedBox(height: 10),

                      // ANNÉE — nouveau champ
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: selectedYear,
                        decoration: const InputDecoration(labelText: 'Année'),
                        items: _yearOptions()
                            .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                            .toList(),
                        onChanged: (v) => setState(() => selectedYear = v ?? selectedYear),
                        validator: (v) => v == null ? 'Choisir une année' : null,
                      ),
                      const SizedBox(height: 10),

                      // NOM
                      TextFormField(
                        controller: libelleC,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 10),

                      // MONTANT
                      TextFormField(
                        controller: montantC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Montant'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Montant requis';
                          final parsed = double.tryParse(v.replaceAll(',', '.'));
                          if (parsed == null) return 'Montant invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // PRÉVISIONNEL — interrupteur
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => previsionnel = !previsionnel),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                const Expanded(child: Text('Prévisionnel')),
                                Switch(
                                  value: previsionnel,
                                  onChanged: (val) => setState(() => previsionnel = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                FilledButton(
                  onPressed: () {
                    if (!showFeuilleSelector) {
                      final fs = _feuillesForCompte(compteName);
                      if (fs.isNotEmpty) feuille = fs.first;
                    }
                    if (formKey.currentState!.validate()) {
                      cleNom = cleCourante ?? '';
                      Navigator.of(ctx).pop(true);
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        if (_idxId < 0) {
          throw 'Colonne "Id" introuvable dans le CSV.';
        }

        // Reprend l’Id de la ligne depuis la vue filtrée actuelle
        final filteredNow = _filteredRows();
        final rowViewNow = filteredNow[filteredIndex];
        final idStr = _getCell(rowViewNow, _idxId).trim();

        // Re-fetch latest
        final latest = await _gh.fetchFile(_path);
        _sha = latest.sha;
        final parsed = CsvService().parseCsv(latest.content);
        if (parsed.isEmpty) return;
        final headers = parsed.first;
        final rows = parsed.sublist(1);

        // Re-calcul des index sur le fichier distant
        final csv = CsvService();
        int idColLatest = -1, idxAnnee = -1, idxFeuille = -1, idxCle = -1, idxNom = -1, idxMontant = -1, idxPrev = -1;
        for (int i = 0; i < headers.length; i++) {
          switch (csv.normalizeHeader(headers[i])) {
            case 'id': idColLatest = i; break;
            case 'annee': idxAnnee = i; break;
            case 'feuille': idxFeuille = i; break;
            case 'cle_nom': idxCle = i; break;
            case 'nom': idxNom = i; break;
            case 'montant': idxMontant = i; break;
            case 'previsionnel':
            case 'prevsionnel':
              idxPrev = i; break;
          }
        }
        if (idColLatest < 0) throw 'Colonne "Id" introuvable (fichier distant).';

        // Trouve la position absolue par Id
        final absolutePosLatest =
        rows.indexWhere((r) => idColLatest < r.length && r[idColLatest].trim() == idStr);
        if (absolutePosLatest < 0) return;

        // Applique les modifs
        final row = List<String>.from(rows[absolutePosLatest]);
        if (idxAnnee >= 0) row[idxAnnee] = selectedYear.toString();        // <-- Année
        if (idxFeuille >= 0) row[idxFeuille] = feuille;
        if (idxCle >= 0) row[idxCle] = cleNom;
        if (idxNom >= 0) row[idxNom] = libelleC.text.trim();
        if (idxMontant >= 0) {
          final v = double.parse(montantC.text.replaceAll(',', '.'));
          row[idxMontant] = v.toStringAsFixed(2);
        }
        if (idxPrev >= 0) {
          row[idxPrev] = previsionnel ? 'True' : 'False';                  // <-- True/False
        }

        rows[absolutePosLatest] = row;

        // Push
        final newContent = csv.toCsvString(headers, rows);
        await _gh.putFile(_path, newContent, message: 'Edit transaction', sha: _sha);

        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction modifiée'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur modification: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (_loading) {
      return const Scaffold(
        appBar: _AppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: const _AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur: $_error'),
        ),
      );
    }

    final comptes = _allCompteNames();
    final rows = _filteredRows();

    return Scaffold(
      appBar: const _AppBar(),
      body: Column(
        children: [
          // Filtre compte
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedCompteName,
              decoration: const InputDecoration(labelText: 'Filtrer par compte'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem(value: null, child: Text('Tous')),
                ...comptes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _selectedCompteName = v),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('Aucune transaction dans le CSV.'))
                : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final r = rows[i];

                final feuille  = _getCell(r, _idxFeuille);
                final nom      = _getCell(r, _idxNom);
                final montant  = _getCell(r, _idxMontant);

                final compteName = _compteNameForFeuille(feuille) ?? '—';
                final showFeuilleLine = _compteHasMultipleFeuilles(compteName);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nom (lisible)
                              Text(
                                nom,
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),

                              // Compte et éventuellement Feuille
                              if (showFeuilleLine) ...[
                                Text('$compteName - $feuille', style: t.bodyMedium),
                                const SizedBox(height: 2),
                              ] else ...[
                                Text(compteName, style: t.bodyLarge),
                                const SizedBox(height: 2),
                              ],

                              // Montant
                              Text('$montant €', style: t.labelLarge),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editRow(i);
                            if (value == 'delete') _confirmDelete(i);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Modifier')),
                            PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Recharger'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('CSV – Transactions'));
  }
}
