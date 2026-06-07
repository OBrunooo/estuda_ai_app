import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/network/api_exception.dart';
import '../models/loading_questoes_args.dart';
import '../services/tema_study_service.dart';

/// Tela transitória que carrega os conjuntos de um tema já vinculado e
/// navega para `/conjuntos`. Geração de tema novo **não passa mais por aqui**:
/// roda em segundo plano com polling até o tema aparecer.
class LoadingQuestoesScreen extends StatefulWidget {
  const LoadingQuestoesScreen({super.key, required this.args});

  final LoadingQuestoesArgs args;

  @override
  State<LoadingQuestoesScreen> createState() => _LoadingQuestoesScreenState();
}

class _LoadingQuestoesScreenState extends State<LoadingQuestoesScreen>
    with SingleTickerProviderStateMixin {
  String? _error;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      final svc = context.read<TemaStudyService>();
      final session = await svc.iniciarSessaoPorTemaExistente(
        temaId: widget.args.temaId,
        temaNome: widget.args.temaNome,
      );
      if (!mounted) return;
      context.go('/conjuntos', extra: session);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          widget.args.temaNome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
                      ? _LoadingHero(controller: _pulse, scheme: scheme)
                      : _ErrorBlock(
                          message: _error!,
                          onRetry: _run,
                          onVoltar: () => context.go('/home'),
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

class _LoadingHero extends StatelessWidget {
  const _LoadingHero({required this.controller, required this.scheme});

  final AnimationController controller;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            final glow = 0.3 + (0.4 * t);
            final scale = 0.96 + (0.06 * t);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: glow),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        Text(
          'Preparando seu estudo',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Estamos carregando os conjuntos e questões\ndesse tema. Só um instante…',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.onRetry,
    required this.onVoltar,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.error.withValues(alpha: 0.14),
            border: Border.all(
              color: scheme.error.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.cloud_off_rounded,
            size: 38,
            color: scheme.error,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Algo não saiu como esperado',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onVoltar,
          child: const Text('Voltar para temas'),
        ),
      ],
    );
  }
}
