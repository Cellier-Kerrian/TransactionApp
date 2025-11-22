class ConfigRoot {
  final List<Compte> comptes;
  final List<String> csvHeaders;
  final CsvDefaults csvDefaultValues;

  ConfigRoot({
    required this.comptes,
    required this.csvHeaders,
    required this.csvDefaultValues,
  });

  factory ConfigRoot.fromJson(Map<String, dynamic> json) {
    return ConfigRoot(
      comptes: (json['comptes'] as List<dynamic>)
          .map((e) => Compte.fromJson(e as Map<String, dynamic>))
          .toList(),
      csvHeaders:
      (json['csv_headers'] as List<dynamic>).map((e) => e.toString()).toList(),
      csvDefaultValues: CsvDefaults.fromJson(
          Map<String, dynamic>.from(json['csv_default_values'] ?? {})),
    );
  }
}

class Compte {
  final String nom;
  final List<String> feuilles;
  final List<TypeTransaction> types;

  Compte({
    required this.nom,
    required this.feuilles,
    required this.types,
  });

  factory Compte.fromJson(Map<String, dynamic> json) {
    return Compte(
      nom: json['nom'] as String,
      feuilles:
      (json['feuilles'] as List<dynamic>).map((e) => e.toString()).toList(),
      types: (json['types_transactions'] as List<dynamic>)
          .map((e) => TypeTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TypeTransaction {
  final String cle;
  final String nom;
  final EnvelopeConfig? envelopeConfig; // Nouveau champ optionnel

  TypeTransaction({required this.cle, required this.nom, this.envelopeConfig});

  factory TypeTransaction.fromJson(Map<String, dynamic> json) {
    return TypeTransaction(
      cle: json['cle'] as String,
      nom: json['nom'] as String,
      // On parse l'objet 'enveloppe' s'il existe
      envelopeConfig: json['enveloppe'] != null
          ? EnvelopeConfig.fromJson(json['enveloppe'])
          : null,
    );
  }
}

// Nouvelle classe pour stocker la config de l'enveloppe liée
class EnvelopeConfig {
  final String nom;
  final String? celluleMax;
  final String? celluleReste;

  EnvelopeConfig({required this.nom, this.celluleMax, this.celluleReste});

  factory EnvelopeConfig.fromJson(Map<String, dynamic> json) {
    return EnvelopeConfig(
      nom: json['nom'] as String,
      celluleMax: json['cellule_max'] as String?,
      celluleReste: json['cellule_reste'] as String?,
    );
  }
}

class CsvDefaults {
  final String cellPrevisionnel;

  CsvDefaults({required this.cellPrevisionnel});

  factory CsvDefaults.fromJson(Map<String, dynamic> json) =>
      CsvDefaults(cellPrevisionnel: (json['cell_previsionnel'] as String?) ?? 'None');
}