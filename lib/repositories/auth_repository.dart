import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_decode_util.dart';
import '../core/network/pending_tema_generation_storage.dart';
import '../core/network/token_storage.dart';
import '../models/user_model.dart';

/// Acesso aos endpoints públicos de autenticação do Laravel:
/// - `POST /api/registrar`
/// - `POST /api/login`
/// - `POST /api/logout` (Sanctum)
///
/// Sucesso (200) sempre devolve `{user: {...}, token: "..."}`.
/// Erros: 401 `{status: "error", message}` (credenciais), 422 `{errors: {...}}`.
class AuthRepository {
  AuthRepository(this._client, this._tokenStorage, this._pendingGeracao);

  final ApiClient _client;
  final TokenStorage _tokenStorage;
  final PendingTemaGenerationStorage _pendingGeracao;

  Future<AuthResult> login({required String email, required String senha}) async {
    try {
      final raw = await _client.post(
        'login',
        data: <String, dynamic>{'email': email, 'senha': senha},
      );
      return _persistOnSuccess(_parseAuthSuccess(raw));
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    }
  }

  Future<AuthResult> registrar({
    required String email,
    required String senha,
    required String nome,
  }) async {
    try {
      final raw = await _client.post(
        'registrar',
        data: <String, dynamic>{'email': email, 'senha': senha, 'nome': nome},
      );
      return _persistOnSuccess(_parseAuthSuccess(raw));
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    }
  }

  Future<void> logout() async {
    try {
      await _client.post('logout');
    } on ApiException {
      // Token inválido ou rede: limpamos localmente do mesmo jeito.
    } finally {
      await _tokenStorage.clearToken();
      await _pendingGeracao.clear();
    }
  }

  /// `POST /api/forgot-password` body `{email}`.
  ///
  /// Sucesso (200): backend envia um token de 6 dígitos por e-mail.
  /// 404: e-mail não cadastrado. Em ambos os casos, propaga [ApiException]
  /// com a mensagem retornada pelo backend, ou retorna a mensagem de sucesso.
  Future<String> forgotPassword({required String email}) async {
    final raw = await _client.post(
      'forgot-password',
      data: <String, dynamic>{'email': email},
    );
    final data = parseResponseData(raw);
    String? msg;
    if (data is Map) {
      msg = (data['mensagem'] ?? data['message'])?.toString();
    }
    return msg ?? 'Token enviado para o seu e-mail.';
  }

  /// `POST /api/reset-password` body
  /// `{email, token, senha, senha_confirmation}`.
  ///
  /// O backend usa a regra `confirmed`, então o campo de confirmação deve se
  /// chamar `senha_confirmation` (snake_case com sufixo `_confirmation`).
  Future<String> resetPassword({
    required String email,
    required String token,
    required String senha,
    required String senhaConfirmation,
  }) async {
    final raw = await _client.post(
      'reset-password',
      data: <String, dynamic>{
        'email': email,
        'token': token,
        'senha': senha,
        'senha_confirmation': senhaConfirmation,
      },
    );
    final data = parseResponseData(raw);
    String? msg;
    if (data is Map) {
      msg = (data['message'] ?? data['mensagem'])?.toString();
    }
    return msg ?? 'Senha redefinida com sucesso.';
  }

  Future<bool> hasStoredToken() async {
    final t = await _tokenStorage.readToken();
    return t != null && t.isNotEmpty;
  }

  Future<AuthResult> _persistOnSuccess(AuthResult result) async {
    if (result.isSuccess) {
      await _tokenStorage.writeToken(result.token!);
    }
    return result;
  }

  AuthResult _parseAuthSuccess(dynamic raw) {
    final data = parseResponseData(raw);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Resposta de autenticação inválida', payload: data);
    }
    final token = data['token'];
    final userMap = data['user'];
    if (token is! String || token.isEmpty || userMap is! Map) {
      final msg = (data['message'] ?? data['mensagem'])?.toString();
      throw ApiException(
        msg ?? 'Resposta de autenticação incompleta',
        payload: data,
      );
    }
    final user = UserModel.fromJson(Map<String, dynamic>.from(userMap));
    return AuthResult.success(user, token);
  }
}

class AuthResult {
  AuthResult._({this.user, this.token, this.errorMessage});

  factory AuthResult.success(UserModel user, String token) {
    return AuthResult._(user: user, token: token);
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(errorMessage: message);
  }

  final UserModel? user;
  final String? token;
  final String? errorMessage;

  bool get isSuccess => user != null && token != null;
}
