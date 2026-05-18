import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/auth_notifier.dart';
import '../app/avatar_notifier.dart';
import 'user_avatar.dart';

/// Abre a tela de perfil (nome, e-mail, avatar, sair); preview maior na AppBar.
class ProfileAppBarButton extends StatelessWidget {
  const ProfileAppBarButton({super.key});

  /// Diâmetro visível do avatar na AppBar (home / novo tema).
  static const double _avatarDiameter = 56;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final avatar = context.watch<AvatarNotifier>();
    final name = auth.currentUser?.name.trim() ?? '';
    final initial =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return IconButton(
      tooltip: 'Perfil',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 56,
        minHeight: 56,
      ),
      onPressed: () => context.push('/perfil'),
      icon: SizedBox(
        width: _avatarDiameter,
        height: _avatarDiameter,
        child: UserAvatar(
          avatarId: avatar.selectedId,
          fallbackInitial: initial,
          radius: _avatarDiameter / 2,
        ),
      ),
    );
  }
}
