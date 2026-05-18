import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Base URL da API Laravel (prefixo `/api` já incluído).
///
/// Sobrescreva em build, se precisar (com ou sem barra no final — o app normaliza):
/// `flutter run --dart-define=API_BASE_URL=http://SEU_IP:8000/api`
///
/// - **Emulador Android:** o padrão é `http://10.0.2.2:8000/api` (alias do host).
///   `127.0.0.1` no emulador aponta para o próprio emulador → "Connection refused".
/// - **Dispositivo físico Android:** use o IP da sua máquina na LAN (ex. `192.168.0.10`)
///   via `--dart-define`; `10.0.2.2` não funciona no aparelho real.
/// - **iOS Simulator / desktop:** padrão `http://127.0.0.1:8000/api`.
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
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/';
    }
    return 'http://127.0.0.1:8000/api/';
  }

  static String _ensureTrailingSlash(String url) {
    final t = url.trim();
    if (t.isEmpty) return t;
    return t.endsWith('/') ? t : '$t/';
  }

  /// Tempo máximo de espera (só recebimento) para
  /// `GET /api/buscar-gerar-questoes-tema`, que é **síncrono** no Laravel e
  /// pode levar muitos minutos (três chamadas em sequência à OpenAI).
  ///
  /// Padrão: **60 minutos**. Ajuste se precisar:
  /// `--dart-define=API_GENERATION_TIMEOUT_SECONDS=7200` (2 h)
  static Duration get generationReceiveTimeout {
    const seconds = int.fromEnvironment(
      'API_GENERATION_TIMEOUT_SECONDS',
      defaultValue: 3600,
    );
    return Duration(seconds: seconds.clamp(300, 86400));
  }

  /// Conexão inicial (handshake TCP) — curto **mesmo** na chamada de geração:
  /// abrir o socket não depende do tempo de processamento no servidor; se o
  /// servidor está fora, queremos detectar em poucos segundos.
  static const Duration generationConnectTimeout = Duration(seconds: 8);

  /// Timeouts padrão para login, listagem e demais chamadas curtas.
  ///
  /// `connectTimeout` proposital curto (8s) para que o app reaja rápido
  /// quando o backend está fora do ar / a rede está caída.
  /// `receiveTimeout` cobre a janela de resposta normal do Laravel
  /// (login, lista, etc.).
  static const Duration defaultConnectTimeout = Duration(seconds: 8);
  static const Duration defaultReceiveTimeout = Duration(seconds: 30);
  static const Duration defaultSendTimeout = Duration(seconds: 20);
}
