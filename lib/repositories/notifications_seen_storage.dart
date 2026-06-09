import 'package:shared_preferences/shared_preferences.dart';

/// Persiste por usuário o **maior id de notificação já visualizado**, usado
/// para calcular o badge de "não lidas" entre execuções do app.
///
/// O backend não expõe estado de leitura — esse controle é puramente local.
class NotificationsSeenStorage {
  NotificationsSeenStorage();

  static const String _kPrefix = 'notifications_last_seen_user_';

  String _key(int userId) => '$_kPrefix$userId';

  /// Retorna o maior id já visualizado pelo usuário, ou `0` quando ainda
  /// não houve nenhuma visualização registrada.
  Future<int> read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(userId)) ?? 0;
  }

  /// Atualiza o maior id visualizado. Idempotente: chamadas com valor menor
  /// ou igual ao já armazenado são descartadas silenciosamente.
  Future<void> write(int userId, int lastSeenId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key(userId)) ?? 0;
    if (lastSeenId <= current) return;
    await prefs.setInt(_key(userId), lastSeenId);
  }
}
