import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../models/app_notification.dart';
import '../repositories/notifications_repository.dart';
import '../repositories/notifications_seen_storage.dart';

// Reexporta o modelo para que callers continuem importando o notifier — evita
// quebrar imports antigos como `import '../app/notifications_notifier.dart';`.
export '../models/app_notification.dart';

/// Coleção das notificações do usuário, vinda do backend.
///
/// Fluxo principal:
/// 1. [aplicarUsuario] é chamado quando o usuário autentica (ou troca) — ele
///    carrega o `lastSeenId` persistido para esse usuário e limpa a lista
///    atual.
/// 2. [refresh] busca a lista mais recente via [NotificationsRepository.listar]
///    e ordena por id descendente.
/// 3. [unreadCount] é derivado: notificações com `id > lastSeenId` são "não
///    lidas".
/// 4. [marcarTodasComoLidas] atualiza o `lastSeenId` localmente e o persiste,
///    para que o badge não reapareça ao reabrir o app.
///
/// O backend não expõe endpoint de exclusão nem de marcação de leitura — por
/// isso só lemos do servidor; tudo de "lida" é local.
class NotificationsNotifier extends ChangeNotifier {
  NotificationsNotifier(this._repo, this._seenStorage);

  final NotificationsRepository _repo;
  final NotificationsSeenStorage _seenStorage;

  int? _userId;
  List<AppNotification> _list = const <AppNotification>[];
  int _lastSeenId = 0;
  bool _loading = false;
  String? _erro;

  /// Lista atual, ordenada da mais recente para a mais antiga.
  List<AppNotification> get all => List.unmodifiable(_list);

  /// Quantidade de notificações ainda não vistas pelo usuário.
  int get unreadCount => _list.where((n) => n.id > _lastSeenId).length;

  bool get isEmpty => _list.isEmpty;

  /// Indica que [refresh] está em andamento.
  bool get loading => _loading;

  /// Mensagem de erro da última tentativa de [refresh], ou `null` se OK.
  String? get erro => _erro;

  /// Helper para a UI: a notificação [n] já foi vista pelo usuário?
  bool isLida(AppNotification n) => n.id <= _lastSeenId;

  /// Troca o usuário "dono" da lista. Limpa o estado anterior e relê o
  /// `lastSeenId` persistido para o novo usuário.
  ///
  /// Quando [userId] é `null` (logout), reseta tudo.
  Future<void> aplicarUsuario(int? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    _list = const <AppNotification>[];
    _erro = null;
    if (userId == null) {
      _lastSeenId = 0;
    } else {
      _lastSeenId = await _seenStorage.read(userId);
    }
    notifyListeners();
  }

  /// Recarrega a lista do servidor. Em caso de falha, mantém a lista atual
  /// e expõe a mensagem em [erro].
  Future<void> refresh() async {
    if (_userId == null) return;
    _loading = true;
    _erro = null;
    notifyListeners();
    try {
      final novas = await _repo.listar();
      novas.sort((a, b) => b.id.compareTo(a.id));
      _list = novas;
    } on ApiException catch (e) {
      _erro = e.message;
    } catch (e) {
      _erro = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Marca todas as notificações atuais como vistas, persistindo o maior id
  /// para o usuário corrente. Chamada quando o painel é fechado.
  Future<void> marcarTodasComoLidas() async {
    if (_list.isEmpty) return;
    final maior = _list.first.id; // pós-sort, primeiro item tem maior id
    if (maior <= _lastSeenId) return;
    _lastSeenId = maior;
    notifyListeners();
    final uid = _userId;
    if (uid != null) {
      await _seenStorage.write(uid, maior);
    }
  }
}
