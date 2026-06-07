import 'dart:async';

import 'package:flutter/material.dart';

import '../app/notifications_notifier.dart';
import '../app/tema_geracao_notifier.dart';
import '../core/network/api_exception.dart';
import '../models/study_session.dart';
import '../models/tema_resumo_model.dart';
import '../repositories/tema_repository.dart';

/// Item da lista in-memory de gerações em andamento.
class _GeracaoPendente {
  _GeracaoPendente({
    required this.temaDigitado,
    required this.iniciadoEm,
  });

  final String temaDigitado;
  final DateTime iniciadoEm;
}

/// Orquestra o disparo de geração de questões e o polling para descobrir
/// quando o tema fica disponível.
///
/// O endpoint `GET /api/buscar-gerar-questoes-tema` apenas enfileira um job
/// e retorna imediatamente. Como não há endpoint de status, descobrimos que
/// o tema ficou pronto quando ele aparece em [TemaRepository.listarTemas].
///
/// **Cooldown**: para evitar disparos duplicados/concorrentes, há um
/// período mínimo entre disparos por usuário ([cooldownDuracao]). Durante
/// esse período, novas chamadas a [iniciarGeracaoEmSegundoPlano] são
/// recusadas — a UI deve consultar [emCooldown] / [tempoRestanteCooldown]
/// antes de chamar para mostrar mensagem ao usuário.
class TemaStudyService {
  TemaStudyService(
    this._temaRepository,
    this._geracaoNotifier,
    this._notifications,
    this._navigatorKey,
  );

  /// Intervalo entre verificações em `listar-temas-user`.
  static const Duration pollInterval = Duration(seconds: 20);

  /// Tempo máximo que cada item espera na fila antes de ser removido.
  static const Duration pollMaxDuration = Duration(minutes: 10);

  /// Tempo mínimo entre dois disparos de geração (cooldown por usuário).
  ///
  /// Configurável: para produção, troque por `Duration(minutes: 15)` — esta
  /// é a única alteração necessária para mudar o tempo do bloqueio.
  static const Duration cooldownDuracao = Duration(minutes: 2);

  final TemaRepository _temaRepository;
  final TemaGeracaoNotifier _geracaoNotifier;
  final NotificationsNotifier _notifications;
  final GlobalKey<NavigatorState> _navigatorKey;

  final List<_GeracaoPendente> _pendentes = <_GeracaoPendente>[];
  Timer? _pollTimer;
  DateTime? _ultimoDisparoEm;

  /// Há ao menos uma geração em andamento (ou aguardando o primeiro poll).
  bool get geracaoAtiva => _pendentes.isNotEmpty;

  /// Quantos temas estão sendo gerados no momento (in-memory).
  int get quantidadePendentes => _pendentes.length;

  /// Tempo restante do cooldown. Retorna `null` quando o usuário já pode
  /// disparar um novo tema.
  Duration? get tempoRestanteCooldown {
    final t = _ultimoDisparoEm;
    if (t == null) return null;
    final passado = DateTime.now().difference(t);
    if (passado >= cooldownDuracao) return null;
    return cooldownDuracao - passado;
  }

  /// `true` enquanto o usuário ainda não pode disparar um novo tema.
  bool get emCooldown => tempoRestanteCooldown != null;

  // ---------------------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------------------

  /// Dispara um novo tema. **Recusa silenciosamente** se o cooldown ainda
  /// estiver ativo — a UI deve checar [emCooldown] antes para mostrar
  /// mensagem ao usuário.
  void iniciarGeracaoEmSegundoPlano(String temaDigitado) {
    final tema = temaDigitado.trim();
    if (tema.isEmpty) return;
    if (emCooldown) return;

    _ultimoDisparoEm = DateTime.now();
    _pendentes.add(
      _GeracaoPendente(temaDigitado: tema, iniciadoEm: DateTime.now()),
    );
    _geracaoNotifier.notificarMudanca();

    unawaited(() async {
      try {
        await _temaRepository.dispararGeracao(tema);
      } catch (e) {
        _pendentes.removeWhere((p) => p.temaDigitado == tema);
        // Falha imediata no dispatch: libera o cooldown para o usuário
        // poder tentar novamente sem esperar.
        _ultimoDisparoEm = null;
        _geracaoNotifier.notificarMudanca();
        final msg = e is ApiException
            ? e.message
            : 'Não foi possível iniciar a geração. Tente novamente.';
        _mostrarSnackBar(msg);
        return;
      }

      _notifications.push(
        titulo: 'Geração em andamento',
        mensagem:
            'Seu tema e suas questões estão sendo gerados e buscados. '
            'Aguarde alguns instantes. Caso o processo demore mais do que '
            'o esperado, tente gerar o tema novamente.',
        kind: AppNotificationKind.info,
      );

      _garantirPolling();
    }());
  }

  /// Carrega questões de um tema já vinculado ao usuário.
  Future<StudySession> iniciarSessaoPorTemaExistente({
    required int temaId,
    required String temaNome,
  }) async {
    final conjuntos = await _temaRepository.carregarConjuntosDoTema(temaId);
    if (conjuntos.isEmpty) {
      throw ApiException(
        'Nenhum conjunto de questões retornado para este tema.',
      );
    }
    return StudySession(
      temaNome: temaNome,
      temaId: temaId,
      conjuntos: conjuntos,
    );
  }

  // ---------------------------------------------------------------------------
  // Polling
  // ---------------------------------------------------------------------------

  void _garantirPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => _tentarDetectar());
    // Primeira tentativa imediata — útil quando o tema já está pronto antes
    // do primeiro tick (caso raro mas barato de tratar).
    unawaited(_tentarDetectar());
  }

  void _pararPollingSeOcioso() {
    if (_pendentes.isEmpty) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _tentarDetectar() async {
    if (_pendentes.isEmpty) {
      _pararPollingSeOcioso();
      return;
    }

    // 1) Remove silenciosamente itens antigos (MVP: sem notificação de
    // conclusão/timeout — o usuário verá o resultado quando a lista
    // recarregar).
    final agora = DateTime.now();
    final expirados = _pendentes
        .where((p) => agora.difference(p.iniciadoEm) > pollMaxDuration)
        .toList();
    for (final p in expirados) {
      _pendentes.remove(p);
    }
    if (expirados.isNotEmpty) _geracaoNotifier.notificarMudanca();

    if (_pendentes.isEmpty) {
      _pararPollingSeOcioso();
      return;
    }

    // 2) Procura matches na lista atual de temas do usuário. Quando
    // encontra, apenas remove da fila e notifica a UI para recarregar a
    // lista — sem notificação push, conforme escopo do MVP.
    List<TemaResumoModel> temas;
    try {
      temas = await _temaRepository.listarTemas();
    } catch (_) {
      // Falha de rede / backend: tenta no próximo tick.
      return;
    }

    final achados = <_GeracaoPendente>[];
    for (final p in _pendentes) {
      final m = _encontrarMatch(temas, p.temaDigitado);
      if (m != null) achados.add(p);
    }

    for (final p in achados) {
      _pendentes.remove(p);
    }
    if (achados.isNotEmpty) _geracaoNotifier.notificarMudanca();

    _pararPollingSeOcioso();
  }

  TemaResumoModel? _encontrarMatch(
    List<TemaResumoModel> temas,
    String temaDigitado,
  ) {
    final alvo = _normalizar(temaDigitado);
    for (final t in temas) {
      if (_normalizar(t.tema) == alvo) return t;
    }
    return null;
  }

  String _normalizar(String s) {
    // Backend normaliza para MAIÚSCULO; comparamos case+espaços-insensitive.
    return s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _mostrarSnackBar(String mensagem) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(mensagem),
        ),
      );
    });
  }
}
