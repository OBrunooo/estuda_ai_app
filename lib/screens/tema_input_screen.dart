import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/tema_study_service.dart';
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
    final aceita = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(
            Icons.hourglass_empty_rounded,
            size: 40,
            color: scheme.primary,
          ),
          iconPadding: const EdgeInsets.only(top: 8, bottom: 4),
          title: const Text(
            'Só avisando',
            textAlign: TextAlign.center,
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          content: const Text(
            'Essa etapa pode levar uns minutinhos — é completamente normal.\n\n'
            'Sem pressa: você pode seguir quando quiser ou voltar e deixar para depois.',
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Agora não'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Seguir'),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (aceita != true || !mounted) return;

    final entendeu = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(
            Icons.collections_bookmark_rounded,
            size: 40,
            color: scheme.primary,
          ),
          iconPadding: const EdgeInsets.only(top: 8, bottom: 4),
          title: const Text(
            'Tudo certo',
            textAlign: TextAlign.center,
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          content: const Text(
            'O tema vai aparecer na sua lista assim que estiver pronto.\n\n'
            'Pode ficar na tela inicial e usar o app normalmente enquanto isso.',
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
    if (entendeu != true || !mounted) return;

    context.read<TemaStudyService>().iniciarGeracaoEmSegundoPlano(tema);
    context.go('/home');
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
