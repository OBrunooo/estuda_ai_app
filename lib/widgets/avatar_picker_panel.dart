import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/avatar_option.dart';
import 'user_avatar.dart';

/// Preview + grade de avatares. A persistência fica a cargo da tela (botão confirmar).
class AvatarPickerPanel extends StatelessWidget {
  const AvatarPickerPanel({
    super.key,
    required this.fallbackInitial,
    required this.previewAvatarId,
    required this.onPickAvatar,
    this.previewRadius = 56,
    this.showHintForNoUser = true,
    this.hasUserProfile = true,
  });

  final String fallbackInitial;
  /// Avatar em pré-visualização (ex.: rascunho antes de salvar).
  final String? previewAvatarId;
  final ValueChanged<String> onPickAvatar;
  final double previewRadius;
  final bool showHintForNoUser;
  final bool hasUserProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: UserAvatar(
            avatarId: previewAvatarId,
            fallbackInitial: fallbackInitial,
            radius: previewRadius,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          !hasUserProfile && showHintForNoUser
              ? 'Sessão sem dados de perfil (reinicie o app ou entre de novo).'
              : 'Escolha um ícone e confirme em Atualizar avatar. Fica salvo só neste aparelho.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Escolha seu avatar',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: AvatarOption.all.length,
          itemBuilder: (context, i) {
            final o = AvatarOption.all[i];
            final selected = previewAvatarId == o.id;
            return Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onPickAvatar(o.id),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.7),
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SvgPicture.asset(
                      o.assetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
