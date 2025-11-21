class NewCsvTransaction {
  /// "Feuille","Cle_Nom","Nom","Montant","Previsionnel","Cell_Previsionnel"
  final String feuille;          // ex: JANVIER
  final String cleNom;           // ex: in_default / out_food
  final String nom;              // libellé
  final double montant;          // nombre positif, export "10.25"
  final bool previsionnel;       // TRUE/FALSE
  final String cellPrevisionnel; // "None" par défaut

  NewCsvTransaction({
    required this.feuille,
    required this.cleNom,
    required this.nom,
    required this.montant,
    required this.previsionnel,
    required this.cellPrevisionnel,
  });

  Map<String, String> toMap() => {
    'Feuille': feuille,
    'Cle_Nom': cleNom,
    'Nom': nom,
    'Montant': montant.toStringAsFixed(2), // <-- point décimal
    'Previsionnel': previsionnel ? 'TRUE' : 'FALSE',
    'Cell_Previsionnel': cellPrevisionnel,
  };
}
