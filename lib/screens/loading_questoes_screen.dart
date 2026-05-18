import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/network/api_exception.dart';
import '../models/loading_questoes_args.dart';
import '../services/tema_study_service.dart';

class LoadingQuestoesScreen extends StatefulWidget {
  const LoadingQuestoesScreen({super.key, required this.args});

  final LoadingQuestoesArgs args;

  @override
  State<LoadingQuestoesScreen> createState() => _LoadingQuestoesScreenState();
}

class _LoadingQuestoesScreenState extends State<LoadingQuestoesScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    if (!a.retomarGeracao && !a.isNovoTema && !a.isTemaExistente) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      final svc = context.read<TemaStudyService>();
      final session = widget.args.retomarGeracao
          ? await svc.iniciarSessaoRetomandoGeracao()
          : widget.args.isTemaExistente
              ? await svc.iniciarSessaoPorTemaExistente(
                  temaId: widget.args.temaId!,
                  temaNome: widget.args.temaNome!,
                )
              : await svc.iniciarSessaoPorTemaDigitado(widget.args.temaDigitado!);
      if (!mounted) return;
      context.go('/conjuntos', extra: session);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String get _mensagemCarregando {
    if (widget.args.isTemaExistente) {
      return 'Carregando questões do tema…';
    }
    if (widget.args.retomarGeracao) {
      return 'Isso pode demorar.';
    }
    return 'Isso pode demorar.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Preparando questões'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: _error == null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              _mensagemCarregando,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.45,
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 52,
                              color: scheme.error,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 28),
                            FilledButton(
                              onPressed: () => context.go('/home'),
                              child: const Text('Voltar'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _run,
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
