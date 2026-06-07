import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/auth_notifier.dart';
import '../app/tema_geracao_notifier.dart';
import '../core/network/api_exception.dart';
import '../models/loading_questoes_args.dart';
import '../models/tema_resumo_model.dart';
import '../repositories/tema_repository.dart';
import '../repositories/temas_cache_storage.dart';
import '../services/tema_study_service.dart';
import '../widgets/notifications_button.dart';
import '../widgets/profile_app_bar_button.dart';
import '../widgets/progress_pill.dart';
import '../widgets/status_chip.dart';

/// Tela inicial após login: lista temas do usuário ([GET /temas]) e acesso a novo tema.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TemaResumoModel>? _temas;
  // No estado inicial não sabemos se há cache; tratamos como loading até
  // [_carregarInicial] decidir entre "render do cache" e "render via API".
  bool _loading = true;
  String? _error;
  late final TemaGeracaoNotifier _geracaoNotifier;

  @override
  void initState() {
    super.initState();
    _geracaoNotifier = context.read<TemaGeracaoNotifier>();
    _geracaoNotifier.addListener(_onGeracaoEmSegundoPlano);
    _carregarInicial();
  }

  @override
  void dispose() {
    _geracaoNotifier.removeListener(_onGeracaoEmSegundoPlano);
    super.dispose();
  }

  void _onGeracaoEmSegundoPlano() {
    if (!mounted) return;
    // Polling sinalizou mudança: revalida em background, sem reexibir o
    // loading principal — os dados em tela continuam visíveis até a API
    // responder.
    _revalidarEmBackground();
  }

  /// Decide entre o caminho "tem cache" (renderiza imediato + revalida em
  /// background) e o caminho "primeiro acesso" (loading + fetch + cache).
  Future<void> _carregarInicial() async {
    final cache = context.read<TemasCacheStorage>();
    final auth = context.read<AuthNotifier>();
    final userId = auth.currentUser?.id;

    List<TemaResumoModel>? cached;
    if (userId != null) {
      cached = await cache.read(userId);
    }

    if (!mounted) return;

    if (cached != null && cached.isNotEmpty) {
      // Cache hit: mostra direto sem loading e revalida em paralelo.
      setState(() {
        _temas = cached;
        _loading = false;
        _error = null;
      });
      _revalidarEmBackground();
      return;
    }

    // Primeiro acesso (ou cache vazio): mantém o comportamento original
    // — loading visível + fetch bloqueante.
    await _buscarERender(comLoading: true);
  }

  /// Atualiza os temas via API sem mostrar o loading principal. Em caso de
  /// falha, mantém o que está em tela (cache continua válido).
  Future<void> _revalidarEmBackground() async {
    await _buscarERender(comLoading: false);
  }

  /// Núcleo de carregamento. [comLoading] decide se a UI deve substituir
  /// o conteúdo pelo indicador de progresso central (`true` apenas quando
  /// não há nada para mostrar).
  Future<void> _buscarERender({required bool comLoading}) async {
    if (comLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repo = context.read<TemaRepository>();
      final lista = await repo.listarTemas();
      if (!mounted) return;

      // Persiste o cache (segmentado por userId) — fire-and-forget.
      final auth = context.read<AuthNotifier>();
      final userId = auth.currentUser?.id;
      if (userId != null) {
        unawaited(context.read<TemasCacheStorage>().write(userId, lista));
      }

      final atuais = _temas;
      final mudou = atuais == null || !_listasIguais(atuais, lista);
      if (mudou) {
        setState(() {
          _temas = lista;
          _loading = false;
          _error = null;
        });
      } else if (_loading) {
        // Mesmo conteúdo, mas precisamos desligar o loading se ele estava
        // ligado.
        setState(() => _loading = false);
      }
    } on ApiException catch (e) {
      // Em revalidação silenciosa, ignora — mantém o cache exibido.
      if (!comLoading) return;
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (!comLoading) return;
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool _listasIguais(List<TemaResumoModel> a, List<TemaResumoModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final ai = a[i];
      final bi = b[i];
      if (ai.temaId != bi.temaId ||
          ai.tema != bi.tema ||
          ai.conclusao != bi.conclusao) {
        return false;
      }
    }
    return true;
  }

  Future<void> _refresh() async {
    // Pull-to-refresh: nunca trocamos a tela pelo loading central — o
    // próprio [RefreshIndicator] já exibe o spinner do gesto.
    await _revalidarEmBackground();
  }

  void _abrirTema(TemaResumoModel t) {
    context.push(
      '/loading',
      extra: LoadingQuestoesArgs(temaId: t.temaId, temaNome: t.tema),
    );
  }

  void _abrirNovoTema() {
    final svc = context.read<TemaStudyService>();
    final restante = svc.tempoRestanteCooldown;
    if (restante != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Já existe uma solicitação de geração recente em processamento. '
            'Aguarde ${_formatarRestante(restante)} antes de pedir outro tema.',
          ),
        ),
      );
      return;
    }
    context.push('/novo-tema');
  }

  String _formatarRestante(Duration d) {
    final totalSeg = d.inSeconds < 1 ? 1 : d.inSeconds;
    final m = totalSeg ~/ 60;
    final s = totalSeg % 60;
    if (m > 0 && s > 0) return '${m}min ${s}s';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seus temas'),
        actions: const [
          NotificationsButton(),
          ProfileAppBarButton(),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNovoTema,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo tema'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(
        message: _error!,
        onRetry: () => _buscarERender(comLoading: true),
      );
    }

    final temas = _temas ?? [];

    if (temas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _EmptyTemasState(
                onCriar: () => context.push('/novo-tema'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        itemCount: temas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final t = temas[i];
          return _TemaCard(tema: t, onTap: () => _abrirTema(t));
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Componentes internos da Home
// ─────────────────────────────────────────────────────────────────────────────

class _TemaCard extends StatefulWidget {
  const _TemaCard({required this.tema, required this.onTap});

  final TemaResumoModel tema;
  final VoidCallback onTap;

  @override
  State<_TemaCard> createState() => _TemaCardState();
}

class _TemaCardState extends State<_TemaCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tema = widget.tema;
    final concluido = tema.concluido;
    final progresso = tema.conclusao / 100.0;
    final naoIniciado = tema.conclusao <= 0;

    final iconBg = concluido
        ? const Color(0xFF6DD3A2).withValues(alpha: 0.18)
        : scheme.primary.withValues(alpha: 0.18);
    final iconFg = concluido
        ? const Color(0xFF6DD3A2)
        : scheme.primary;

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      scale: _pressed ? 0.98 : 1.0,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: concluido
                    ? const Color(0xFF6DD3A2).withValues(alpha: 0.45)
                    : scheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        concluido
                            ? Icons.workspace_premium_rounded
                            : Icons.menu_book_rounded,
                        color: iconFg,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tema.tema,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                          ),
                          const SizedBox(height: 8),
                          StatusChip(
                            label: concluido
                                ? 'Concluído'
                                : naoIniciado
                                    ? 'Pronto para começar'
                                    : 'Em andamento',
                            kind: concluido
                                ? StatusChipKind.concluido
                                : naoIniciado
                                    ? StatusChipKind.novo
                                    : StatusChipKind.emAndamento,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ProgressPill(
                  value: progresso,
                  showPercent: true,
                  trailingLabel: 'Progresso',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTemasState extends StatelessWidget {
  const _EmptyTemasState({required this.onCriar});

  final VoidCallback onCriar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.22),
                    scheme.tertiary.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 52,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Nenhum tema ainda',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crie seu primeiro tema e a gente busca\nas questões para você estudar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onCriar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar tema'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
