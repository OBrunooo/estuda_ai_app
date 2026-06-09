/// Tipos visuais de notificação (mapeiam para ícone/cor no painel).
///
/// Espelham o campo `tipo` enviado pelo backend Laravel. Qualquer valor
/// desconhecido é tratado como [info].
enum AppNotificationKind { info, success, warning, error }

/// Notificação do usuário, como persistida pelo backend.
///
/// Mapeia o item retornado por `GET /api/listar-notificacoes-user`:
/// ```json
/// {
///   "id": 1,
///   "user_id": 1,
///   "message": "Você já está cadastrado a um tema referente a: Javascript",
///   "tipo": "info",
///   "created_at": "2026-06-09T03:05:15.000000Z",
///   "updated_at": "2026-06-09T03:05:15.000000Z"
/// }
/// ```
class AppNotification {
  const AppNotification({
    required this.id,
    required this.mensagem,
    required this.kind,
    required this.criadaEm,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is int
        ? idRaw
        : idRaw is num
            ? idRaw.toInt()
            : int.tryParse(idRaw?.toString() ?? '') ?? 0;

    final mensagem = (json['message'] ?? json['mensagem'])?.toString() ?? '';
    final tipo = json['tipo']?.toString();
    final criadaEmRaw = json['created_at']?.toString();
    final criadaEm = criadaEmRaw == null
        ? DateTime.now()
        : DateTime.tryParse(criadaEmRaw)?.toLocal() ?? DateTime.now();

    return AppNotification(
      id: id,
      mensagem: mensagem,
      kind: _kindFromTipo(tipo),
      criadaEm: criadaEm,
    );
  }

  final int id;
  final String mensagem;
  final AppNotificationKind kind;
  final DateTime criadaEm;

  static AppNotificationKind _kindFromTipo(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'success':
      case 'sucesso':
        return AppNotificationKind.success;
      case 'warning':
      case 'warn':
      case 'aviso':
        return AppNotificationKind.warning;
      case 'error':
      case 'erro':
        return AppNotificationKind.error;
      case 'info':
      default:
        return AppNotificationKind.info;
    }
  }
}
