import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Estado salvo com [FlutterSecureStorage] (mesmo mecanismo do token) para
/// retomar a geração de questões após o usuário fechar o app.
///
/// O backend Laravel expõe `GET /api/buscar-gerar-questoes-tema` de forma
/// **síncrona** e idempotente: chamar de novo com o mesmo `tema` retorna
/// sucesso direto se o tema já foi gerado/vinculado. Portanto basta guardar
/// o `temaDigitado` original e refazer a chamada na retomada.
class PendingTemaGenerationState {
  PendingTemaGenerationState({required this.temaDigitado});

  final String temaDigitado;
}

class PendingTemaGenerationStorage {
  PendingTemaGenerationStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kDigitado = 'pending_tema_digitado';
  // Chave legada — limpamos no clear() para apagar dados de versões antigas.
  static const _kNormLegacy = 'pending_tema_normalizado';

  final FlutterSecureStorage _storage;

  /// Inicia o rastreamento (novo fluxo).
  Future<void> saveStarted(String temaDigitado) async {
    final t = temaDigitado.trim();
    await _storage.write(key: _kDigitado, value: t);
    await _storage.delete(key: _kNormLegacy);
  }

  Future<PendingTemaGenerationState?> read() async {
    final d = await _storage.read(key: _kDigitado);
    if (d == null || d.trim().isEmpty) {
      return null;
    }
    return PendingTemaGenerationState(temaDigitado: d.trim());
  }

  Future<bool> hasPending() async => (await read()) != null;

  Future<void> clear() async {
    await _storage.delete(key: _kDigitado);
    await _storage.delete(key: _kNormLegacy);
  }
}
