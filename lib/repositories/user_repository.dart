import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_decode_util.dart';
import '../models/user_model.dart';

/// Endpoints autenticados de perfil do Laravel:
/// - `GET /api/me` — `{user: {...}}`
/// - `POST /api/update-name-user` — body `{name}` → `{success, message}`
/// - `POST /api/update-avatar-user` — body `{avatar}` (0–10) → `{success, message}`
class UserRepository {
  UserRepository(this._client);

  final ApiClient _client;

  Future<UserModel> fetchMe() async {
    final raw = await _client.get('me');
    final data = parseResponseData(raw);
    if (data is! Map || data['user'] is! Map) {
      throw ApiException('Resposta de perfil inválida', payload: data);
    }
    return UserModel.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
  }

  Future<void> updateName(String name) async {
    final raw = await _client.post(
      'update-name-user',
      data: <String, dynamic>{'name': name},
    );
    _assertSuccess(raw, 'Erro ao atualizar nome');
  }

  Future<void> updateAvatar(int avatarId) async {
    final raw = await _client.post(
      'update-avatar-user',
      data: <String, dynamic>{'avatar': avatarId},
    );
    _assertSuccess(raw, 'Erro ao atualizar avatar');
  }

  void _assertSuccess(dynamic raw, String fallback) {
    final data = parseResponseData(raw);
    if (data is! Map) {
      throw ApiException(fallback, payload: data);
    }
    if (data['success'] == false) {
      final msg = (data['message'] ?? data['mensagem'])?.toString();
      throw ApiException(msg ?? fallback, payload: data);
    }
  }
}
