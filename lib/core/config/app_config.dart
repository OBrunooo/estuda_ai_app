import 'package:flutter/foundation.dart' show kDebugMode;

/// Base URL da API Laravel (prefixo `/api` já incluído).
///
/// Sobrescreva em build, se precisar (com ou sem barra no final — o app normaliza):
/// `flutter run --dart-define=API_BASE_URL=http://SEU_IP:80/api`
///
/// - **Debug:** padrão `http://127.0.0.1:8000/api/` (servidor Laravel local).
///   No emulador Android use `10.0.2.2` (alias do host) ou passe `--dart-define`,
///   pois `127.0.0.1` aponta para o próprio emulador → "Connection refused".
/// - **Release:** padrão `https://studia.vps-bruno-gomes.com/api/`.
class AppConfig {
  AppConfig._();

  static const String _fromEnvironment = String.fromEnvironment('API_BASE_URL');

  /// URL base do prefixo `/api` do Laravel.
  ///
  /// **Deve terminar com `/`** para o Dio juntar corretamente com paths relativos
  /// (`temas`, `login`). Sem a barra final, `baseUrl` + `/temas` vira `http://host/temas`
  /// (sem `api`) e a requisição falha.
  static String get apiBaseUrl {
    if (_fromEnvironment.isNotEmpty) {
      return _ensureTrailingSlash(_fromEnvironment);
    }
    if (kDebugMode) {
      return 'http://127.0.0.1:8000/api/';
    }
    return 'https://studia.vps-bruno-gomes.com/api/';
  }

  static String _ensureTrailingSlash(String url) {
    final t = url.trim();
    if (t.isEmpty) return t;
    return t.endsWith('/') ? t : '$t/';
  }

  /// Timeouts padrão para login, listagem e demais chamadas curtas.
  ///
  /// Valores mais altos evitam falso "erro de conexão" quando o Laravel demora
  /// a responder (servidor de desenvolvimento ocupado, cold start, etc.).
  /// Ajuste via `--dart-define=API_DEFAULT_TIMEOUT_SECONDS=180` se precisar.
  static Duration get defaultConnectTimeout {
    const seconds = int.fromEnvironment(
      'API_DEFAULT_CONNECT_TIMEOUT_SECONDS',
      defaultValue: 30,
    );
    return Duration(seconds: seconds.clamp(8, 120));
  }

  static Duration get defaultReceiveTimeout {
    const seconds = int.fromEnvironment(
      'API_DEFAULT_TIMEOUT_SECONDS',
      defaultValue: 120,
    );
    return Duration(seconds: seconds.clamp(30, 600));
  }

  static Duration get defaultSendTimeout {
    const seconds = int.fromEnvironment(
      'API_DEFAULT_SEND_TIMEOUT_SECONDS',
      defaultValue: 60,
    );
    return Duration(seconds: seconds.clamp(20, 300));
  }
}
