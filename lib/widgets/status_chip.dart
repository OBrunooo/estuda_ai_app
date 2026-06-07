import 'package:flutter/material.dart';

/// Variantes de status reutilizáveis no app.
enum StatusChipKind { concluido, emAndamento, novo, info, alerta }

/// Pílula pequena com ícone + texto que comunica o estado de algo (tema,
/// conjunto, etc). É intencionalmente compacta para caber dentro de cards.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.kind,
    this.dense = false,
  });

  final String label;
  final StatusChipKind kind;

  /// Quando `true`, reduz padding e tamanho da fonte (para usar dentro de
  /// cards densos).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = _resolver(scheme);

    final padH = dense ? 8.0 : 10.0;
    final padV = dense ? 4.0 : 6.0;
    final iconSize = dense ? 14.0 : 16.0;
    final textStyle = (dense
            ? Theme.of(context).textTheme.labelSmall
            : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(
      color: fg,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: fg),
          const SizedBox(width: 6),
          Text(label, style: textStyle),
        ],
      ),
    );
  }

  (Color bg, Color fg, IconData icon) _resolver(ColorScheme scheme) {
    switch (kind) {
      case StatusChipKind.concluido:
        // Verde mais "amigável" para celebrar a conclusão, mas dentro do
        // dark theme.
        const green = Color(0xFF6DD3A2);
        return (green.withValues(alpha: 0.14), green, Icons.check_circle_rounded);
      case StatusChipKind.emAndamento:
        return (
          scheme.primary.withValues(alpha: 0.16),
          scheme.tertiary,
          Icons.bolt_rounded,
        );
      case StatusChipKind.novo:
        return (
          scheme.secondary.withValues(alpha: 0.16),
          scheme.secondary,
          Icons.auto_awesome_rounded,
        );
      case StatusChipKind.info:
        return (
          scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          scheme.onSurfaceVariant,
          Icons.info_outline_rounded,
        );
      case StatusChipKind.alerta:
        return (
          scheme.error.withValues(alpha: 0.16),
          scheme.error,
          Icons.error_outline_rounded,
        );
    }
  }
}
