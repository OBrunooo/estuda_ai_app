import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/notifications_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sino + badge para a AppBar
// ─────────────────────────────────────────────────────────────────────────────

/// Ícone de sino da AppBar, com badge contando não lidas. Ao tocar, abre o
/// painel de notificações como bottom sheet rolável.
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
    notifier.refresh();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => _NotificationsPanel(notifier: notifier),
    ).whenComplete(() {
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

// ─────────────────────────────────────────────────────────────────────────────
// Painel (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsPanel extends StatefulWidget {
  const _NotificationsPanel({required this.notifier});

  final NotificationsNotifier notifier;

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (context, _) {
        final items = widget.notifier.all;
        final loading = widget.notifier.loading;
        final erro = widget.notifier.erro;
        final unread = widget.notifier.unreadCount;

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: media.size.height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PanelHeader(
                  unreadCount: unread,
                  loading: loading,
                  onMarcarLidas: unread == 0
                      ? null
                      : () => widget.notifier.marcarTodasComoLidas(),
                ),
                Flexible(
                  child: _buildBody(
                    items: items,
                    loading: loading,
                    erro: erro,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required List<AppNotification> items,
    required bool loading,
    required String? erro,
  }) {
    // 1. Primeiro carregamento sem dados em cache → shimmer.
    if (items.isEmpty && loading) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => _SkeletonList(t: _pulse.value),
      );
    }

    // 2. Erro sem dados → mensagem com retry implícito via pull-to-refresh.
    if (items.isEmpty && erro != null) {
      return _RefreshableMessage(
        onRefresh: () => widget.notifier.refresh(),
        child: _PanelMensagem(
          icon: Icons.cloud_off_rounded,
          color: Theme.of(context).colorScheme.error,
          titulo: 'Não foi possível carregar',
          descricao: erro,
        ),
      );
    }

    // 3. Vazio → ilustração + pull-to-refresh.
    if (items.isEmpty) {
      return _RefreshableMessage(
        onRefresh: () => widget.notifier.refresh(),
        child: _PanelMensagem(
          icon: Icons.notifications_off_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          titulo: 'Tudo em dia',
          descricao: 'Você não tem notificações por enquanto.',
        ),
      );
    }

    // 4. Lista normal, agrupada por período.
    final grupos = _agruparPorPeriodo(items);
    final entries = grupos.entries.toList(growable: false);

    return RefreshIndicator(
      onRefresh: () => widget.notifier.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: entries.length,
        itemBuilder: (context, gi) {
          final entry = entries[gi];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (gi > 0) const SizedBox(height: 18),
              _SectionHeader(label: entry.key),
              const SizedBox(height: 8),
              for (final n in entry.value) ...[
                _NotificationTile(
                  notification: n,
                  naoLida: !widget.notifier.isLida(n),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Divide as notificações em "Hoje", "Esta semana" e "Anteriores",
  /// preservando a ordem (mais recente → mais antiga). Grupos vazios são
  /// omitidos.
  Map<String, List<AppNotification>> _agruparPorPeriodo(
    List<AppNotification> items,
  ) {
    final agora = DateTime.now();
    final inicioDeHoje = DateTime(agora.year, agora.month, agora.day);
    final inicioDaSemana = inicioDeHoje.subtract(const Duration(days: 7));

    final hoje = <AppNotification>[];
    final semana = <AppNotification>[];
    final anteriores = <AppNotification>[];

    for (final n in items) {
      if (!n.criadaEm.isBefore(inicioDeHoje)) {
        hoje.add(n);
      } else if (!n.criadaEm.isBefore(inicioDaSemana)) {
        semana.add(n);
      } else {
        anteriores.add(n);
      }
    }

    final out = <String, List<AppNotification>>{};
    if (hoje.isNotEmpty) out['Hoje'] = hoje;
    if (semana.isNotEmpty) out['Esta semana'] = semana;
    if (anteriores.isNotEmpty) out['Anteriores'] = anteriores;
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho do painel
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.unreadCount,
    required this.loading,
    required this.onMarcarLidas,
  });

  final int unreadCount;
  final bool loading;
  final VoidCallback? onMarcarLidas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Row(
        children: [
          Text(
            'Notificações',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 10),
            _UnreadPill(count: unreadCount),
          ],
          const Spacer(),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          TextButton(
            onPressed: onMarcarLidas,
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            child: const Text('Marcar como lidas'),
          ),
        ],
      ),
    );
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de notificação
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.naoLida,
  });

  final AppNotification notification;
  final bool naoLida;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, iconColor) = _iconFor(notification.kind, scheme);

    final fundo = naoLida
        ? scheme.primary.withValues(alpha: 0.09)
        : scheme.surfaceContainerHigh.withValues(alpha: 0.55);
    final borda = naoLida
        ? scheme.primary.withValues(alpha: 0.32)
        : scheme.outlineVariant.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.mensagem,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            naoLida ? FontWeight.w600 : FontWeight.w400,
                        height: 1.35,
                        color: naoLida
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.82),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _tempoRelativo(notification.criadaEm),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          if (naoLida) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color) _iconFor(AppNotificationKind kind, ColorScheme scheme) {
    switch (kind) {
      case AppNotificationKind.success:
        return (Icons.check_circle_outline_rounded, const Color(0xFF6DD3A2));
      case AppNotificationKind.warning:
        return (Icons.warning_amber_rounded, Colors.orange.shade400);
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
    if (diff.inDays < 7) return 'há ${diff.inDays} d';
    if (diff.inDays < 30) return 'há ${(diff.inDays / 7).floor()} sem';
    return 'há ${(diff.inDays / 30).floor()} m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton (carregamento inicial)
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.t});

  /// Valor entre 0 e 1 do pulse atual (vindo do AnimationController do pai).
  final double t;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const _SectionHeader(label: 'Hoje'),
        const SizedBox(height: 8),
        for (var i = 0; i < 4; i++) ...[
          _SkeletonTile(t: t),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Pulse entre dois tons de superfície para o efeito shimmer suave.
    final base = Color.lerp(
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
      t,
    )!;
    final block = Color.lerp(
      scheme.surfaceContainerHighest,
      scheme.outlineVariant.withValues(alpha: 0.55),
      t,
    )!;

    BoxDecoration deco(double radius) => BoxDecoration(
          color: block,
          borderRadius: BorderRadius.circular(radius),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 42, height: 42, decoration: deco(12)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, decoration: deco(4)),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.7,
                  alignment: Alignment.centerLeft,
                  child: Container(height: 12, decoration: deco(4)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 64,
                  child: Container(height: 10, decoration: deco(4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / erro com pull-to-refresh
// ─────────────────────────────────────────────────────────────────────────────

class _RefreshableMessage extends StatelessWidget {
  const _RefreshableMessage({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _PanelMensagem extends StatelessWidget {
  const _PanelMensagem({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.descricao,
  });

  final IconData icon;
  final Color color;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 36, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          descricao,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}
