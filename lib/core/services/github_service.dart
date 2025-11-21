import 'dart:convert';
import 'package:http/http.dart' as http;

import 'csv_service.dart';

class GithubPath {
  final String owner;
  final String repo;
  final String branch;
  final String path;

  GithubPath({
    required this.owner,
    required this.repo,
    required this.branch,
    required this.path,
  });
}

class GithubFileResponse {
  final String content; // contenu texte (décodé)
  final String? sha;    // sha de la version (null si création)

  GithubFileResponse({required this.content, required this.sha});
}

class GithubService {
  final String? token; // peut être null tant que non configuré
  GithubService(this.token);

  static const _base = 'https://api.github.com';

  Map<String, String> _headers() {
    if (token == null || token!.isEmpty) {
      throw Exception('TOKEN_GITHUB_ABSENT');
    }
    return {
      'Authorization': 'token $token',
      'Accept': 'application/vnd.github+json',
      'Content-Type': 'application/json',
    };
    // Note: le préfixe moderne peut aussi être "Bearer", mais "token" reste accepté.
  }

  /// GET /repos/{owner}/{repo}/contents/{path}?ref={branch}
  /// - Si le fichier n'existe pas (404) → retourne content='' et sha=null
  Future<GithubFileResponse> fetchFile(GithubPath p) async {
    final uri = Uri.parse('$_base/repos/${p.owner}/${p.repo}/contents/${Uri.encodeComponent(p.path)}?ref=${p.branch}');
    final resp = await http.get(uri, headers: _headers());

    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final encoded = (json['content'] as String?) ?? '';
      // Le contenu peut contenir des sauts de ligne ; enlever ceux générés par GitHub
      final normalized = encoded.replaceAll('\n', '');
      final bytes = base64.decode(normalized);
      final content = utf8.decode(bytes);
      final sha = json['sha'] as String?;
      return GithubFileResponse(content: content, sha: sha);
    }

    if (resp.statusCode == 404) {
      // Fichier non trouvé → considéré comme "vide / à créer"
      return GithubFileResponse(content: '', sha: null);
    }

    throw Exception('GitHub fetchFile failed (${resp.statusCode}): ${resp.body}');
  }

  /// PUT /repos/{owner}/{repo}/contents/{path}
  /// - Crée ou met à jour un fichier (content base64)
  /// - Si `sha` null → création ; sinon mise à jour
  Future<void> putFile(
      GithubPath p,
      String content, {
        required String message,
        String? sha,
      }) async {
    final uri = Uri.parse('$_base/repos/${p.owner}/${p.repo}/contents/${Uri.encodeComponent(p.path)}');
    final b64 = base64.encode(utf8.encode(content));
    final body = <String, dynamic>{
      'message': message,
      'content': b64,
      'branch': p.branch,
      if (sha != null) 'sha': sha,
    };

    final resp = await http.put(uri, headers: _headers(), body: jsonEncode(body));
    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception('GitHub putFile failed (${resp.statusCode}): ${resp.body}');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers CSV pour append avec auto-ID
// ─────────────────────────────────────────────────────────────────────────────

extension GithubCsvAppend on GithubService {
  Future<void> appendCsvRowWithAutoId(
      GithubPath path, {
        required int annee,                 // <-- NOUVEAU
        required String feuille,
        required String cleNom,
        required String nom,
        required double montant,
        required bool previsionnel,
        required String cellPrevisionnel,
        String commitMessage = 'Add transaction',
      }) async {
    final csv = CsvService();

    final res = await fetchFile(path);        // {content, sha} (création si vide gérée plus bas)
    final currentContent = res.content.trim();
    final currentSha = res.sha;

    List<String> headers = [];
    List<List<String>> rows = [];

    if (currentContent.isEmpty) {
      // Squelette minimal si le fichier n'existe pas encore
      headers = [
        'Id',
        'Annee',
        'Feuille',
        'Cle_Nom',
        'Nom',
        'Montant',
        'Previsionnel',
        'Cell_Previsionnel',
      ];
      rows = [];
    } else {
      final parsed = csv.parseCsv(currentContent);
      if (parsed.isEmpty) {
        headers = [
          'Id',
          'Annee',
          'Feuille',
          'Cle_Nom',
          'Nom',
          'Montant',
          'Previsionnel',
          'Cell_Previsionnel',
        ];
        rows = [];
      } else {
        headers = parsed.first;
        rows = parsed.sublist(1);
      }
    }

    final next = csv.nextId(headers, rows);

    final newRow = csv.buildRowForHeaders(
      headers,
      id: next.toString(),
      annee: annee.toString(),
      feuille: feuille,
      cleNom: cleNom,
      nom: nom,
      montant: montant.toStringAsFixed(2),
      previsionnel: previsionnel ? 'True' : 'False',
      cellPrevisionnel: cellPrevisionnel,
    );

    rows.add(newRow);
    final newContent = csv.toCsvString(headers, rows);

    await putFile(path, newContent, message: commitMessage, sha: currentSha);
  }
}

extension GithubTokenValidation on GithubService {
  Future<bool> validateToken() async {
    final r = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    if (r.statusCode == 200) return true;
    if (r.statusCode == 401) return false;
    return false;
  }
}

extension GithubChecks on GithubService {
  Future<bool> fileExists(GithubPath path) async {
    try {
      await fetchFile(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
