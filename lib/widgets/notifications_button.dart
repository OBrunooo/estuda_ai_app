import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/notifications_notifier.dart';
import '../models/loading_questoes_args.dart';

/// Ícone de sino para a AppBar, com badge mostrando notificações não lidas.
/// Abre um bottom sheet com a lista quando tocado.
class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsNotifier>(
      builder: (context, notifier, _) {
        final count = notifier.unreadCount;
        final hasUnread = count > 0;

        return IconButton(
          tooltip: 'Notificações',
          onPressed: () => _abrirPainel(context, notifier),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                hasUnread
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_outlined,
              ),
              if (hasUnread)
                Positioned(
                  right: -4,
                  top: -4,
                  child: _Badge(count: count),
                ),
            ],
          ),
        );
      },
    );
  }

  void _abrirPainel(BuildContext context, NotificationsNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _NotificationsPanel(notifier: notifier),
    ).whenComplete(() {
      // Ao fechar o painel, marcamos tudo como lido para zerar o badge.
      notifier.marcarTodasComoLidas();
    });
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = count > 9 ? '9+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: scheme.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({required this.notifier});

  final NotificationsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: notifier,
      builder: (context, _) {
        final items = notifier.all;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: media.size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        'Notificações',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (items.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            notifier.limpar();
                          },
                          child: const Text('Limpar tudo'),
                        ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 56,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sem notificações por enquanto.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 0),
                      itemBuilder: (context, i) =>
                          _NotificationTile(notification: items[i], notifier: notifier),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.notifier});

  final AppNotification notification;
  final NotificationsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, iconColor) = _iconFor(notification.kind, scheme);
    final action = notification.action;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.15),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        notification.titulo,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            notification.mensagem,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _tempoRelativo(notification.timestamp),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Remover',
        icon: const Icon(Icons.close_rounded, size: 18),
        onPressed: () => notifier.remover(notification.id),
      ),
      onTap: action == null
          ? null
          : () {
              Navigator.of(context).pop();
              GoRouter.of(context).push(
                '/loading',
                extra: LoadingQuestoesArgs(
                  temaId: action.temaId,
                  temaNome: action.temaNome,
                ),
              );
            },
    );
  }

  (IconData, Color) _iconFor(AppNotificationKind kind, ColorScheme scheme) {
    switch (kind) {
      case AppNotificationKind.success:
        return (Icons.check_circle_outline_rounded, Colors.green.shade600);
      case AppNotificationKind.warning:
        return (Icons.warning_amber_rounded, Colors.orange.shade700);
      case AppNotificationKind.error:
        return (Icons.error_outline_rounded, scheme.error);
      case AppNotificationKind.info:
        return (Icons.info_outline_rounded, scheme.primary);
    }
  }

  String _tempoRelativo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'agora há pouco';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return 'há ${diff.inDays} d';
  }
}
