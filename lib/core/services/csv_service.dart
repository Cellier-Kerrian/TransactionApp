class CsvService {
  CsvService();

  // —————————— Parsing / sérialisation ——————————

  List<List<String>> parseCsv(String content) {
    if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
      content = content.substring(1);
    }

    final lines = content.split('\n');
    final rows = <List<String>>[];
    final buf = StringBuffer();
    var fields = <String>[];
    var inQuotes = false;

    void pushField() {
      var s = buf.toString();
      if (inQuotes) s = s.replaceAll('""', '"');
      fields.add(s);
      buf.clear();
    }

    for (var raw in lines) {
      int i = 0;
      while (i < raw.length) {
        final c = raw[i];
        if (c == '"') {
          if (!inQuotes) {
            inQuotes = true;
          } else {
            final isEscaped = (i + 1 < raw.length && raw[i + 1] == '"');
            if (isEscaped) { buf.write('"'); i++; } else { inQuotes = false; }
          }
        } else if (c == ',' && !inQuotes) {
          pushField();
        } else if (c != '\r') {
          buf.write(c);
        }
        i++;
      }
      if (inQuotes) {
        buf.write('\n');
      } else {
        pushField();
        rows.add(fields);
        fields = <String>[];
      }
    }
    while (rows.isNotEmpty && rows.last.length == 1 && rows.last.first.trim().isEmpty) {
      rows.removeLast();
    }
    return rows;
  }

  /// Recompose le CSV (headers + rows) avec virgules et guillemets
  String toCsvString(List<String> headers, List<List<String>> rows) {
    String esc(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }
    final out = StringBuffer();
    out.writeln(headers.map(esc).join(','));
    for (final r in rows) {
      out.writeln(r.map(esc).join(','));
    }
    return out.toString();
  }

  // —————————— Utilitaires ID / headers ——————————

  String normalizeHeader(String h) {
    final lower = h.toLowerCase().trim();
    const withAccents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿœæ';
    const noAccents   = 'aaaaaaceeeeiiiinooooouuuuyyoeae';
    var s = lower;
    for (int i = 0; i < withAccents.length; i++) {
      s = s.replaceAll(withAccents[i], noAccents[i]);
    }
    s = s.replaceAll(' ', '_');
    s = s.replaceAll(RegExp('[^a-z0-9_ ]'), '');
    return s;
  }

  int indexOfId(List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      if (normalizeHeader(headers[i]) == 'id') return i;
    }
    return -1;
  }

  int nextId(List<String> headers, List<List<String>> rows) {
    final idIdx = indexOfId(headers);
    if (idIdx < 0) return 1;
    int maxId = 0;
    for (final r in rows) {
      if (r.length > idIdx) {
        final v = int.tryParse(r[idIdx].trim());
        if (v != null && v > maxId) maxId = v;
      }
    }
    return maxId + 1;
  }

  List<String> buildRowForHeaders(
      List<String> headers, {
        required String id,
        required String annee,
        required String feuille,
        required String cleNom,
        required String nom,
        required String montant,
        required String previsionnel,
        required String cellPrevisionnel,
      }) {
    final out = List<String>.filled(headers.length, '');
    for (int i = 0; i < headers.length; i++) {
      switch (normalizeHeader(headers[i])) {
        case 'id':
          out[i] = id;
          break;
        case 'annee':
          out[i] = annee;
          break;
        case 'feuille':
          out[i] = feuille;
          break;
        case 'cle_nom':
          out[i] = cleNom;
          break;
        case 'nom':
          out[i] = nom;
          break;
        case 'montant':
          out[i] = montant;
          break;
        case 'previsionnel':
          out[i] = previsionnel;
          break;
        case 'cell_previsionnel':
          out[i] = cellPrevisionnel;
          break;
        default:
          out[i] = '';
      }
    }
    return out;
  }
}
