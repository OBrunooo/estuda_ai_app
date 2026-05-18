import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/conjunto_estudo.dart';
import '../models/questao_model.dart';
import '../repositories/tema_repository.dart';

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
          preferredSize: const Size.fromHeight(5),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
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
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        sh.questao.questao,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(sh.options.length, (i) {
                        final o = sh.options[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AlternativaCard(
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

class _AlternativaCard extends StatelessWidget {
  const _AlternativaCard({
    required this.label,
    required this.selected,
    required this.revealed,
    required this.isCorrect,
    required this.isWrongSelected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool revealed;
  final bool isCorrect;
  final bool isWrongSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color borderColor = scheme.outlineVariant.withValues(alpha: 0.85);
    Color? fillColor = scheme.surfaceContainerHigh.withValues(alpha: 0.55);

    if (revealed) {
      if (isCorrect) {
        borderColor = Colors.green.shade400;
        fillColor = Colors.green.withValues(alpha: 0.18);
      } else if (isWrongSelected) {
        borderColor = Colors.red.shade400;
        fillColor = Colors.red.withValues(alpha: 0.18);
      }
    } else if (selected) {
      borderColor = scheme.primary.withValues(alpha: 0.9);
    }

    final borderW = revealed
        ? 2.0
        : selected
            ? 1.5
            : 1.0;

    const radius = 12.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: scheme.onSurface.withValues(alpha: 0.04),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: fillColor,
            border: Border.all(
              color: borderColor,
              width: borderW,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.35,
                        ),
                  ),
                ),
                if (revealed && isCorrect)
                  Icon(Icons.check_rounded, color: Colors.green.shade300, size: 24),
                if (isWrongSelected)
                  Icon(
                    Icons.close_rounded,
                    color: Colors.red.shade300,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
