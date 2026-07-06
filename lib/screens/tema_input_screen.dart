import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/tema_study_service.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/profile_app_bar_button.dart';

class TemaInputScreen extends StatefulWidget {
  const TemaInputScreen({super.key});

  @override
  State<TemaInputScreen> createState() => _TemaInputScreenState();
}

class _TemaInputScreenState extends State<TemaInputScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    if (!_formKey.currentState!.validate()) return;
    final tema = _controller.text.trim();

    // Bloqueio por cooldown — defesa em profundidade caso o usuário chegue
    // aqui por outro caminho que não seja o FAB da Home.
    final svc = context.read<TemaStudyService>();
    final restante = svc.tempoRestanteCooldown;
    if (restante != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Já existe uma solicitação de geração recente em processamento. '
            'Aguarde ${_formatarRestante(restante)} antes de pedir outro tema.',
          ),
        ),
      );
      return;
    }

    final confirmar = await showAppConfirmDialog(
      context: context,
      icon: Icons.auto_awesome_rounded,
      titulo: 'Gerar este tema?',
      mensagem:
          'Vamos preparar suas questões. O processo costuma levar alguns '
          'minutos. Você pode continuar usando o app normalmente — o tema '
          'aparecerá na sua lista assim que estiver pronto.',
      confirmarLabel: 'Gerar tema',
    );
    if (confirmar != true || !mounted) return;

    context.read<TemaStudyService>().iniciarGeracaoEmSegundoPlano(tema);
    context.go('/home');
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
        title: const Text('Novo tema'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: const [ProfileAppBarButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'O que você quer estudar?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Digite um tema conceitual (ex.: arquitetura de software). '
                  'O app envia para a API, que busca questões existentes ou gera novas.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Tema',
                    hintText: 'Ex.: lógica de programação',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 3) {
                      return 'Descreva o tema com pelo menos 3 caracteres';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _continuar,
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
