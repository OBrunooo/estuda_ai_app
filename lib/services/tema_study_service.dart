import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/tema_geracao_notifier.dart';
import '../core/network/api_exception.dart';
import '../core/network/pending_tema_generation_storage.dart';
import '../models/study_session.dart';
import '../models/tema_resumo_model.dart';
import '../repositories/tema_repository.dart';

/// Orquestra verificação/geração do tema e carregamento das questões.
///
/// O backend Laravel expõe `GET /api/buscar-gerar-questoes-tema` de forma
/// **síncrona** (sem polling): uma única chamada HTTP fica aguardando até a
/// IA terminar. O `ApiClient` usa timeouts longos para isso. Mesmo assim,
/// salvamos o tema digitado em [PendingTemaGenerationStorage] para permitir
/// **retomar** caso o app seja fechado durante a espera — a chamada repetida
/// é idempotente (o controller reconhece o tema já criado e apenas vincula
/// o usuário).
class TemaStudyService {
  TemaStudyService(
    this._temaRepository,
    this._pendingGeracao,
    this._geracaoNotifier,
    this._navigatorKey,
  );

  final TemaRepository _temaRepository;
  final PendingTemaGenerationStorage _pendingGeracao;
  final TemaGeracaoNotifier _geracaoNotifier;
  final GlobalKey<NavigatorState> _navigatorKey;

  bool _geracaoAtiva = false;
  bool get geracaoAtiva => _geracaoAtiva;

  /// Novo tema: roda em segundo plano (usuário fica na home). [SnackBar] ao
  /// terminar ou em caso de erro.
  void iniciarGeracaoEmSegundoPlano(String temaDigitado) {
    if (_geracaoAtiva) return;
    _geracaoAtiva = true;
    _geracaoNotifier.notificarMudanca();
    Future<void>(() async {
      try {
        final session = await iniciarSessaoPorTemaDigitado(temaDigitado);
        // IMPORTANTE: liberamos a flag ANTES de notificar para que os
        // listeners (ex.: HomeScreen) leiam `geracaoAtiva = false` e
        // possam fazer chamadas ao backend com segurança.
        _geracaoAtiva = false;
        _avisarGeracaoConcluida(session);
      } catch (e) {
        _geracaoAtiva = false;
        _avisarGeracaoErro(e);
      }
    });
  }

  /// Retoma geração salva no dispositivo (mesma chamada idempotente), em
  /// segundo plano.
  void retomarGeracaoEmSegundoPlano() {
    if (_geracaoAtiva) return;
    _geracaoAtiva = true;
    _geracaoNotifier.notificarMudanca();
    Future<void>(() async {
      try {
        final session = await iniciarSessaoRetomandoGeracao();
        _geracaoAtiva = false;
        _avisarGeracaoConcluida(session);
      } catch (e) {
        _geracaoAtiva = false;
        _avisarGeracaoErro(e);
      }
    });
  }

  void _avisarGeracaoConcluida(StudySession session) {
    _geracaoNotifier.notificarMudanca();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Seu tema está pronto.'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () {
              if (!ctx.mounted) return;
              ctx.go('/conjuntos', extra: session);
            },
          ),
        ),
      );
    });
  }

  void _avisarGeracaoErro(Object e) {
    _geracaoNotifier.notificarMudanca();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(msg),
        ),
      );
    });
  }

  Future<bool> temGeracaoPendente() => _pendingGeracao.hasPending();

  Future<PendingTemaGenerationState?> lerGeracaoPendente() =>
      _pendingGeracao.read();

  Future<void> descartarGeracaoPendente() => _pendingGeracao.clear();

  Future<StudySession> iniciarSessaoPorTemaDigitado(String temaDigitado) async {
    final tema = temaDigitado.trim();
    await _pendingGeracao.saveStarted(tema);
    return _completarSessao(tema);
  }

  /// Retoma usando o tema salvo em [PendingTemaGenerationStorage].
  /// O endpoint é idempotente.
  Future<StudySession> iniciarSessaoRetomandoGeracao() async {
    final pending = await _pendingGeracao.read();
    if (pending == null) {
      throw ApiException(
        'Não há geração em andamento salva neste aparelho.',
      );
    }
    return _completarSessao(pending.temaDigitado);
  }

  Future<StudySession> _completarSessao(String tema) async {
    // Snapshot da lista para identificar o tema novo quando a API não devolve
    // o nome normalizado na resposta de sucesso.
    final temasAntes = await _safeListarTemas();

    final ver = await _temaRepository.verificarOuGerar(
      tema,
      temasAntes: temasAntes,
    );
    if (!ver.isOk) {
      await _pendingGeracao.clear();
      throw ApiException(ver.errorMessage ?? 'Não foi possível usar este tema');
    }
    final nome = ver.temaNome!;

    // Garante que temos o id do tema (mesmo que a verificação só tenha
    // identificado pelo nome).
    final temas = await _temaRepository.listarTemas();
    final match = temas.where((t) => t.tema == nome).toList();
    if (match.isEmpty) {
      throw ApiException(
        'Tema "$nome" não encontrado na lista após verificação. '
        'Tente sincronizar novamente.',
      );
    }
    final temaId = match.first.temaId;

    final conjuntos = await _temaRepository.carregarConjuntosDoTema(temaId);
    if (conjuntos.isEmpty) {
      throw ApiException(
        'Nenhum conjunto de questões retornado para este tema.',
      );
    }

    await _pendingGeracao.clear();
    return StudySession(temaNome: nome, temaId: temaId, conjuntos: conjuntos);
  }

  /// Carrega questões de um tema já associado ao usuário.
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

  Future<List<TemaResumoModel>> _safeListarTemas() async {
    try {
      return await _temaRepository.listarTemas();
    } on ApiException {
      return const <TemaResumoModel>[];
    }
  }
}
