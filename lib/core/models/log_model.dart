class EnvelopeData {
  final double balance;
  final double? maxLimit;

  EnvelopeData({required this.balance, this.maxLimit});
}

class LogEntry {
  final DateTime date;
  final String feuille;
  final double tReste;
  final double rReste;
  final Map<String, EnvelopeData> envelopes;

  LogEntry({
    required this.date,
    required this.feuille,
    required this.tReste,
    required this.rReste,
    required this.envelopes, // Correction ici : envelopes
  });

  factory LogEntry.fromCsv(List<dynamic> row, List<String> headers) {
    double parseDouble(dynamic val) {
      if (val == null || val.toString().trim().isEmpty) return 0.0;
      return double.tryParse(val.toString().replaceAll(',', '.')) ?? 0.0;
    }

    final Map<String, EnvelopeData> envs = {};

    // 1. Repérage des colonnes MAX_
    final maxColIndices = <String, int>{};

    for (int i = 10; i < headers.length; i++) {
      final header = headers[i];
      if (header.startsWith("MAX_")) {
        final baseName = header.substring(4);
        maxColIndices[baseName] = i;
      }
    }

    // 2. Parsing des enveloppes
    for (int i = 10; i < row.length && i < headers.length; i++) {
      final header = headers[i];

      if (header.startsWith("MAX_")) continue;

      final valStr = row[i]?.toString().trim();

      if (valStr != null && valStr.isNotEmpty) {
        final balance = parseDouble(valStr);

        double? maxVal;
        if (maxColIndices.containsKey(header)) {
          final maxIndex = maxColIndices[header]!;
          if (maxIndex < row.length) {
            final maxStr = row[maxIndex]?.toString().trim();
            if (maxStr != null && maxStr.isNotEmpty) {
              maxVal = parseDouble(maxStr);
            }
          }
        }

        envs[header] = EnvelopeData(balance: balance, maxLimit: maxVal);
      }
    }

    return LogEntry(
      date: DateTime.tryParse(row[0].toString()) ?? DateTime.now(),
      feuille: row[1].toString(),
      tReste: parseDouble(row[5]),
      rReste: parseDouble(row[9]),
      envelopes: envs, // Correction ici : envelopes
    );
  }
}