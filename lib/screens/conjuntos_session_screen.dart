import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../core/network/api_exception.dart';
import '../models/conjunto_estudo.dart';
import '../models/questoes_conjunto_args.dart';
import '../models/study_session.dart';
import '../repositories/tema_repository.dart';
import '../services/tema_study_service.dart';
import '../widgets/progress_pill.dart';
import '../widgets/status_chip.dart';

/// Após carregar o tema: o usuário escolhe qual **conjunto (seção)** estudar.
/// Conjuntos já concluídos no backend recebem outra estilização.
class ConjuntosSessionScreen extends StatefulWidget {
  const ConjuntosSessionScreen({super.key, required this.session});

  final StudySession session;

  @override
  State<ConjuntosSessionScreen> createState() => _ConjuntosSessionScreenState();
}

class _ConjuntosSessionScreenState extends State<ConjuntosSessionScreen> {
  late StudySession _session;
  bool _loading = false;
  // Conjunto cujas questões estão sendo carregadas no momento (após o tap).
  int? _abrindoConjuntoId;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final svc = context.read<TemaStudyService>();
      final s = await svc.iniciarSessaoPorTemaExistente(
        temaId: _session.temaId,
        temaNome: _session.temaNome,
      );
      if (mounted) setState(() => _session = s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirConjunto(ConjuntoEstudo c) async {
    if (_abrindoConjuntoId != null) return;
    setState(() => _abrindoConjuntoId = c.conjuntoId);

    ConjuntoEstudo conjuntoComQuestoes;
    try {
      final repo = context.read<TemaRepository>();
      final questoes = await repo.listarQuestoesConjunto(c.conjuntoId);
      if (!mounted) return;
      if (questoes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este conjunto ainda não tem questões disponíveis.'),
          ),
        );
        return;
      }
      conjuntoComQuestoes = c.copyWith(questoes: questoes);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar as questões: $e'),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _abrindoConjuntoId = null);
    }

    if (!mounted) return;
    final ok = await context.push<bool>(
      '/questoes',
      extra: QuestoesConjuntoArgs(
        temaNome: _session.temaNome,
        conjunto: conjuntoComQuestoes,
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final conjuntos = _session.conjuntos;
    final total = conjuntos.length;
    final feitos = conjuntos.where((c) => c.concluido).length;
    final progresso = total == 0 ? 0.0 : feitos / total;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _session.temaNome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _HeaderTema(
                    temaNome: _session.temaNome,
                    total: total,
                    feitos: feitos,
                    progresso: progresso,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Conjuntos',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Text(
                          '$total',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Estude cada conjunto na ordem. Os que você já concluiu '
                    'ficam marcados como uma medalha.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < conjuntos.length; i++) ...[
                    _ConjuntoCard(
                      conjunto: conjuntos[i],
                      proximo: _ehProximoDisponivel(conjuntos, i),
                      carregando: _abrindoConjuntoId == conjuntos[i].conjuntoId,
                      desabilitado: _abrindoConjuntoId != null &&
                          _abrindoConjuntoId != conjuntos[i].conjuntoId,
                      onTap: () => _abrirConjunto(conjuntos[i]),
                    ),
                    if (i != conjuntos.length - 1) const _Conector(),
                  ],
                ],
              ),
            ),
    );
  }

  /// O próximo conjunto disponível é o primeiro não concluído na ordem.
  bool _ehProximoDisponivel(List<ConjuntoEstudo> lista, int idx) {
    if (lista[idx].concluido) return false;
    for (var j = 0; j < idx; j++) {
      if (!lista[j].concluido) return false;
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header com progresso do tema
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderTema extends StatelessWidget {
  const _HeaderTema({
    required this.temaNome,
    required this.total,
    required this.feitos,
    required this.progresso,
  });

  final String temaNome;
  final int total;
  final int feitos;
  final double progresso;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completou = total > 0 && feitos == total;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.22),
            scheme.tertiary.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  completou
                      ? Icons.workspace_premium_rounded
                      : Icons.school_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      temaNome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ProgressPill(
            value: progresso,
            showPercent: true,
            trailingLabel: total == 0
                ? 'Sem conjuntos'
                : '$feitos de $total ${total == 1 ? "conjunto" : "conjuntos"} '
                    'concluídos',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de Conjunto
// ─────────────────────────────────────────────────────────────────────────────

class _ConjuntoCard extends StatefulWidget {
  const _ConjuntoCard({
    required this.conjunto,
    required this.proximo,
    required this.onTap,
    this.carregando = false,
    this.desabilitado = false,
  });

  final ConjuntoEstudo conjunto;
  final bool proximo;
  final VoidCallback onTap;
  // Este card foi tocado e estamos buscando as questões dele.
  final bool carregando;
  // Outro card está carregando — bloqueia o tap neste para evitar concorrência.
  final bool desabilitado;

  @override
  State<_ConjuntoCard> createState() => _ConjuntoCardState();
}

class _ConjuntoCardState extends State<_ConjuntoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final concluido = widget.conjunto.concluido;
    final ativo = !widget.desabilitado && !widget.carregando;
    final destaque = widget.proximo && !concluido;

    final corBorda = concluido
        ? const Color(0xFF6DD3A2).withValues(alpha: 0.55)
        : destaque
            ? scheme.primary.withValues(alpha: 0.75)
            : scheme.outlineVariant;
    final larguraBorda = destaque ? 1.5 : 1.0;

    final Gradient? fundoGrad = destaque
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.16),
              scheme.tertiary.withValues(alpha: 0.06),
            ],
          )
        : null;

    return Opacity(
      opacity: widget.desabilitado ? 0.55 : 1.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? 0.98 : 1.0,
        child: Material(
          color: fundoGrad == null
              ? scheme.surfaceContainerHigh
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: ativo ? widget.onTap : null,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Ink(
              decoration: BoxDecoration(
                gradient: fundoGrad,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: corBorda, width: larguraBorda),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _ConjuntoMedalha(
                      indice: widget.conjunto.indice,
                      concluido: concluido,
                      destaque: destaque,
                      carregando: widget.carregando,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conjunto ${widget.conjunto.indice}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          StatusChip(
                            label: widget.carregando
                                ? 'Carregando…'
                                : concluido
                                    ? 'Concluído'
                                    : destaque
                                        ? 'Próximo'
                                        : 'Disponível',
                            kind: widget.carregando
                                ? StatusChipKind.info
                                : concluido
                                    ? StatusChipKind.concluido
                                    : destaque
                                        ? StatusChipKind.emAndamento
                                        : StatusChipKind.info,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.carregando)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: scheme.primary,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: concluido
                            ? const Color(0xFF6DD3A2)
                            : destaque
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConjuntoMedalha extends StatelessWidget {
  const _ConjuntoMedalha({
    required this.indice,
    required this.concluido,
    required this.destaque,
    required this.carregando,
  });

  final int indice;
  final bool concluido;
  final bool destaque;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const green = Color(0xFF6DD3A2);

    final Gradient? grad;
    final Color fallback;
    final Color borderColor;
    final Widget child;

    if (concluido) {
      grad = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF77E1AE),
          Color(0xFF3DAE7E),
        ],
      );
      fallback = green;
      borderColor = green.withValues(alpha: 0.55);
      child = const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 24,
      );
    } else if (destaque) {
      grad = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [scheme.primary, scheme.tertiary],
      );
      fallback = scheme.primary;
      borderColor = scheme.primary.withValues(alpha: 0.6);
      child = Text(
        '$indice',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      );
    } else {
      grad = null;
      fallback = scheme.surfaceContainerHighest;
      borderColor = scheme.outlineVariant;
      child = Text(
        '$indice',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      );
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: grad,
        color: grad == null ? fallback : null,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: (concluido || destaque)
            ? [
                BoxShadow(
                  color: (concluido ? green : scheme.primary).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conector entre conjuntos (sensação de progressão)
// ─────────────────────────────────────────────────────────────────────────────

class _Conector extends StatelessWidget {
  const _Conector();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 20,
            alignment: Alignment.center,
            child: Container(
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.outlineVariant,
                    scheme.outlineVariant.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Espaço vazio à direita só pra alinhar com o card.
          Expanded(child: Container(color: AppTheme.midnight, height: 0)),
        ],
      ),
    );
  }
}
