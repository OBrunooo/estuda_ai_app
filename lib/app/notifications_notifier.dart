import 'package:flutter/foundation.dart';

/// Tipos visuais de notificação (mapeiam para ícone/cor no painel).
enum AppNotificationKind { info, success, warning, error }

/// Ação opcional anexada a uma notificação — por enquanto, abrir um tema
/// específico que ficou pronto.
class AppNotificationAction {
  const AppNotificationAction.abrirTema({
    required this.temaId,
    required this.temaNome,
  });

  final int temaId;
  final String temaNome;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.titulo,
    required this.mensagem,
    required this.kind,
    DateTime? timestamp,
    this.action,
    this.lida = false,
  }) : timestamp = timestamp ?? DateTime.now();

  final String id;
  final String titulo;
  final String mensagem;
  final DateTime timestamp;
  final AppNotificationKind kind;
  final AppNotificationAction? action;
  bool lida;
}

/// Coleção in-memory de notificações exibidas no painel/sino da home.
///
/// Não persiste entre execuções do app — se o usuário fechar e reabrir,
/// a lista é zerada. (Trocar por persistência local é um upgrade futuro.)
class NotificationsNotifier extends ChangeNotifier {
  final List<AppNotification> _list = <AppNotification>[];

  List<AppNotification> get all => List.unmodifiable(_list);

  int get unreadCount => _list.where((n) => !n.lida).length;

  bool get isEmpty => _list.isEmpty;

  void push({
    required String titulo,
    required String mensagem,
    AppNotificationKind kind = AppNotificationKind.info,
    AppNotificationAction? action,
  }) {
    _list.insert(
      0,
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        titulo: titulo,
        mensagem: mensagem,
        kind: kind,
        action: action,
      ),
    );
    notifyListeners();
  }

  void marcarTodasComoLidas() {
    var mudou = false;
    for (final n in _list) {
      if (!n.lida) {
        n.lida = true;
        mudou = true;
      }
    }
    if (mudou) notifyListeners();
  }

  void remover(String id) {
    final antes = _list.length;
    _list.removeWhere((n) => n.id == id);
    if (_list.length != antes) notifyListeners();
  }

  void limpar() {
    if (_list.isEmpty) return;
    _list.clear();
    notifyListeners();
  }
}
