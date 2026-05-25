import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/auth_notifier.dart';
import '../app/avatar_notifier.dart';
import '../widgets/avatar_picker_panel.dart';

/// Só troca de avatar (aberta a partir do card na tela [ProfileSettingsScreen]).
class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({super.key});

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  String? _draftId;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _draftId = context.read<AvatarNotifier>().selectedId;
      _seeded = true;
    }
  }

  Future<void> _confirmar() async {
    final id = _draftId;
    if (id != null) {
      final err = await context.read<AvatarNotifier>().selectAndSync(id);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
        return;
      }
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/perfil');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().currentUser;
    final nameTrim = user?.name.trim() ?? '';
    final initial =
        nameTrim.isNotEmpty ? nameTrim.substring(0, 1).toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atualizar avatar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AvatarPickerPanel(
                fallbackInitial: initial,
                previewAvatarId: _draftId,
                onPickAvatar: (id) => setState(() => _draftId = id),
                previewRadius: 64,
                hasUserProfile: user != null,
              ),
              const SizedBox(height: 36),
              FilledButton(
                onPressed: _confirmar,
                child: const Text('Atualizar avatar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
