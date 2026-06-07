import 'package:flutter/material.dart';

/// Barra de progresso linear arredondada com gradiente violeta→lavanda.
///
/// É o componente visual de progresso padrão do app — usado em cards de tema,
/// nos cabeçalhos das seções e onde mais precisarmos transmitir avanço.
class ProgressPill extends StatelessWidget {
  const ProgressPill({
    super.key,
    required this.value,
    this.height = 8,
    this.showPercent = false,
    this.trailingLabel,
  });

  /// Progresso de 0.0 a 1.0.
  final double value;

  /// Altura da barra (default `8`).
  final double height;

  /// Quando `true`, mostra o percentual à direita.
  final bool showPercent;

  /// Texto adicional ao lado direito do percentual (ex.: "3 de 7").
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0.0, 1.0);

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(
            height: height,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          ),
          FractionallySizedBox(
            widthFactor: clamped,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    scheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(height),
                boxShadow: clamped > 0
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showPercent && trailingLabel == null) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (trailingLabel != null)
              Expanded(
                child: Text(
                  trailingLabel!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              )
            else
              const Spacer(),
            if (showPercent)
              Text(
                '${(clamped * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        bar,
      ],
    );
  }
}
