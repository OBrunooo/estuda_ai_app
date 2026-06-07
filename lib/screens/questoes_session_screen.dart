import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/conjunto_estudo.dart';
import '../models/questao_model.dart';
import '../repositories/tema_repository.dart';
import '../widgets/progress_pill.dart';

class _ShuffledQuestion {
  _ShuffledQuestion({
    required this.questao,
    required this.options,
  });

  final QuestaoModel questao;
  final List<_OptionTile> options;
}

class _OptionTile {
  _OptionTile({required this.label, required this.isCorrect});

  final String label;
  final bool isCorrect;
}

class _QuestaoNaSessao {
  _QuestaoNaSessao({required this.shuffled});

  final _ShuffledQuestion shuffled;

  _QuestaoNaSessao copiaEmbaralhada(Random rnd) {
    final q = shuffled.questao;
    final opts = <_OptionTile>[
      _OptionTile(label: q.alternativa1, isCorrect: true),
      _OptionTile(label: q.alternativa2, isCorrect: false),
      _OptionTile(label: q.alternativa3, isCorrect: false),
      _OptionTile(label: q.alternativa4, isCorrect: false),
    ]..shuffle(rnd);
    return _QuestaoNaSessao(
      shuffled: _ShuffledQuestion(questao: q, options: opts),
    );
  }
}

/// Questões de **um único conjunto** (seção), após escolha em [ConjuntosSessionScreen].
class QuestoesSessionScreen extends StatefulWidget {
  const QuestoesSessionScreen({
    super.key,
    required this.temaNome,
    required this.conjunto,
  });

  final String temaNome;
  final ConjuntoEstudo conjunto;

  @override
  State<QuestoesSessionScreen> createState() => _QuestoesSessionScreenState();
}

class _QuestoesSessionScreenState extends State<QuestoesSessionScreen> {
  late List<_QuestaoNaSessao> _entries;
  final Random _rnd = Random();
  int _index = 0;
  int? _selected;
  bool _revealed = false;
  bool _finalizando = false;

  @override
  void initState() {
    super.initState();
    _entries = [];
    for (final q in widget.conjunto.questoes) {
      final opts = <_OptionTile>[
        _OptionTile(label: q.alternativa1, isCorrect: true),
        _OptionTile(label: q.alternativa2, isCorrect: false),
        _OptionTile(label: q.alternativa3, isCorrect: false),
        _OptionTile(label: q.alternativa4, isCorrect: false),
      ]..shuffle(_rnd);
      _entries.add(
        _QuestaoNaSessao(
          shuffled: _ShuffledQuestion(questao: q, options: opts),
        ),
      );
    }
  }

  void _onSelect(int optionIndex) {
    if (_revealed) return;
    setState(() => _selected = optionIndex);
  }

  void _confirmar() {
    if (_selected == null || _revealed) return;
    setState(() => _revealed = true);
  }

  Future<void> _proxima() async {
    final cur = _entries[_index];
    final acertou = _selected != null &&
        cur.shuffled.options[_selected!].isCorrect;

    if (!acertou) {
      _entries.add(cur.copiaEmbaralhada(_rnd));
    }

    final novoIndex = _index + 1;
    if (novoIndex >= _entries.length) {
      setState(() => _finalizando = true);
      try {
        if (!widget.conjunto.concluido) {
          await context.read<TemaRepository>().concluirConjunto(
                widget.conjunto.conjuntoId,
              );
        }
      } catch (_) {}
      if (mounted) context.pop(true);
      return;
    }

    setState(() {
      _index = novoIndex;
      _selected = null;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.temaNome)),
        body: const Center(child: Text('Nenhuma questão neste conjunto.')),
      );
    }

    final total = _entries.length;
    final progress = total == 0 ? 0.0 : (_index + 1) / total;
    final sh = _entries[_index].shuffled;
    final acertouNesta = _revealed &&
        _selected != null &&
        sh.options[_selected!].isCorrect;
    final concluirSecao = acertouNesta && _index == _entries.length - 1;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.temaNome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _finalizando ? null : () => context.pop(false),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(38),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Questão ${_index + 1} de $total',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressPill(value: progress, height: 8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PERGUNTA',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.tertiary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sh.questao.questao,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(sh.options.length, (i) {
                        final o = sh.options[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AlternativaCard(
                            letra: String.fromCharCode(0x41 + i),
                            label: o.label,
                            selected: !_revealed && _selected == i,
                            revealed: _revealed,
                            isCorrect: o.isCorrect,
                            isWrongSelected:
                                _revealed && _selected == i && !o.isCorrect,
                            onTap: _revealed ? null : () => _onSelect(i),
                          ),
                        );
                      }),
                      if (_revealed) ...[
                        const SizedBox(height: 8),
                        _ResultadoBanner(acertou: acertouNesta),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: !_revealed
                ? FilledButton(
                    onPressed:
                        _selected != null && !_finalizando ? _confirmar : null,
                    child: const Text('Confirmar resposta'),
                  )
                : FilledButton(
                    onPressed: _finalizando
                        ? null
                        : () async {
                            await _proxima();
                          },
                    child: _finalizando
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(concluirSecao ? 'Concluir seção' : 'Próxima'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cards de alternativa
// ─────────────────────────────────────────────────────────────────────────────

class _AlternativaCard extends StatelessWidget {
  const _AlternativaCard({
    required this.letra,
    required this.label,
    required this.selected,
    required this.revealed,
    required this.isCorrect,
    required this.isWrongSelected,
    required this.onTap,
  });

  final String letra;
  final String label;
  final bool selected;
  final bool revealed;
  final bool isCorrect;
  final bool isWrongSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const green = Color(0xFF6DD3A2);
    const red = Color(0xFFFF6B6B);

    // Estado visual: idle | selected | reveal-correct | reveal-wrong | reveal-other
    Color borderColor = scheme.outlineVariant;
    Color fillColor = scheme.surfaceContainerHigh.withValues(alpha: 0.55);
    Color badgeBg = scheme.surfaceContainerHighest;
    Color badgeFg = scheme.onSurfaceVariant;
    double borderW = 1.0;
    IconData? trailingIcon;
    Color? trailingColor;

    if (revealed) {
      if (isCorrect) {
        borderColor = green;
        fillColor = green.withValues(alpha: 0.16);
        badgeBg = green.withValues(alpha: 0.25);
        badgeFg = green;
        borderW = 2.0;
        trailingIcon = Icons.check_circle_rounded;
        trailingColor = green;
      } else if (isWrongSelected) {
        borderColor = red;
        fillColor = red.withValues(alpha: 0.14);
        badgeBg = red.withValues(alpha: 0.22);
        badgeFg = red;
        borderW = 2.0;
        trailingIcon = Icons.cancel_rounded;
        trailingColor = red;
      }
    } else if (selected) {
      borderColor = scheme.primary;
      fillColor = scheme.primary.withValues(alpha: 0.10);
      badgeBg = scheme.primary;
      badgeFg = Colors.white;
      borderW = 1.5;
    }

    const radius = 18.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: scheme.primary.withValues(alpha: 0.06),
        hoverColor: scheme.onSurface.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: fillColor,
            border: Border.all(color: borderColor, width: borderW),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letra,
                    style: TextStyle(
                      color: badgeFg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.35,
                        ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailingIcon, color: trailingColor, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner de resultado (após revelar)
// ─────────────────────────────────────────────────────────────────────────────

class _ResultadoBanner extends StatelessWidget {
  const _ResultadoBanner({required this.acertou});

  final bool acertou;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF6DD3A2);
    const red = Color(0xFFFF6B6B);

    final color = acertou ? green : red;
    final icon = acertou ? Icons.celebration_rounded : Icons.refresh_rounded;
    final titulo = acertou ? 'Boa! Você acertou.' : 'Quase! Vamos tentar de novo.';
    final corpo = acertou
        ? 'Continue assim — você está no caminho certo.'
        : 'Essa questão volta no final do conjunto para fixar.';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  corpo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
