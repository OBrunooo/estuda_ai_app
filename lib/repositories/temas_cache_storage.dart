import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tema_resumo_model.dart';

/// Cache local da lista de temas do usuário, usado pela estratégia
/// **stale-while-revalidate** na [HomeScreen].
///
/// As chaves são segmentadas por `userId` (`temas_cache_user_<id>`), para
/// que múltiplos usuários no mesmo dispositivo não vejam dados uns dos
/// outros caso troquem de conta.
class TemasCacheStorage {
  TemasCacheStorage();

  static const String _kPrefix = 'temas_cache_user_';

  String _key(int userId) => '$_kPrefix$userId';

  /// Lê o cache do usuário; retorna `null` se não houver dados salvos ou
  /// se a desserialização falhar (cache corrompido é tratado como ausente).
  Future<List<TemaResumoModel>?> read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((e) => TemaResumoModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// Sobrescreve o cache do usuário com a [lista] atual da API.
  Future<void> write(int userId, List<TemaResumoModel> lista) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = lista
        .map(
          (t) => <String, dynamic>{
            'id': t.temaId,
            'nome': t.tema,
            'porcentagem_conclusao': t.conclusao,
          },
        )
        .toList(growable: false);
    await prefs.setString(_key(userId), jsonEncode(payload));
  }
}
