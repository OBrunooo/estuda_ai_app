import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/conjunto_estudo.dart';
import '../models/questoes_conjunto_args.dart';
import '../models/study_session.dart';
import '../services/tema_study_service.dart';

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
    final ok = await context.push<bool>(
      '/questoes',
      extra: QuestoesConjuntoArgs(
        temaNome: _session.temaNome,
        conjunto: c,
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final conjuntos = _session.conjuntos;

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.temaNome),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Seções',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Escolha um conjunto para estudar. Seções já feitas aparecem destacadas.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  ...conjuntos.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ConjuntoCard(
                        conjunto: c,
                        onTap: () => _abrirConjunto(c),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ConjuntoCard extends StatelessWidget {
  const _ConjuntoCard({
    required this.conjunto,
    required this.onTap,
  });

  final ConjuntoEstudo conjunto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final concluido = conjunto.concluido;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: concluido
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: concluido ? scheme.secondary : scheme.outlineVariant,
              width: concluido ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: concluido
                    ? scheme.primary.withValues(alpha: 0.28)
                    : scheme.primaryContainer,
                child: Icon(
                  concluido ? Icons.check_rounded : Icons.menu_book_outlined,
                  color: concluido
                      ? scheme.secondary
                      : scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conjunto ${conjunto.indice}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      concluido ? 'Concluído' : 'Não concluído',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: concluido
                                ? scheme.secondary
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: concluido
                    ? scheme.secondary
                    : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
