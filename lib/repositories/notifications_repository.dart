import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_decode_util.dart';
import '../models/app_notification.dart';

/// Acesso ao endpoint de notificações do usuário autenticado.
///
/// `GET /api/listar-notificacoes-user` retorna `{notificacoes: [...]}`.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final ApiClient _client;

  Future<List<AppNotification>> listar() async {
    final raw = await _client.get('listar-notificacoes-user');
    final data = parseResponseData(raw);
    if (data is! Map || data['notificacoes'] is! List) {
      throw ApiException('Notificações inválidas', payload: data);
    }
    final items = List<dynamic>.from(data['notificacoes'] as List);
    return items
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
