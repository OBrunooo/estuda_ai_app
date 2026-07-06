import 'package:flutter/material.dart';

/// Estilo visual do botão de confirmação — muda a cor de acento e do selo.
enum ConfirmTone { primary, destructive }

/// Exibe um diálogo de confirmação padronizado do app (dark + roxo), com um
/// selo de ícone, título, mensagem e as ações Cancelar/Confirmar.
///
/// Mantém dimensões próximas às de um [AlertDialog] comum — apenas melhora a
/// estética. Retorna `true` se o usuário confirmar, `false`/`null` caso
/// contrário.
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required IconData icon,
  required String titulo,
  required String mensagem,
  required String confirmarLabel,
  String cancelarLabel = 'Cancelar',
  ConfirmTone tone = ConfirmTone.primary,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _AppConfirmDialog(
      icon: icon,
      titulo: titulo,
      mensagem: mensagem,
      confirmarLabel: confirmarLabel,
      cancelarLabel: cancelarLabel,
      tone: tone,
    ),
  );
}

class _AppConfirmDialog extends StatelessWidget {
  const _AppConfirmDialog({
    required this.icon,
    required this.titulo,
    required this.mensagem,
    required this.confirmarLabel,
    required this.cancelarLabel,
    required this.tone,
  });

  final IconData icon;
  final String titulo;
  final String mensagem;
  final String confirmarLabel;
  final String cancelarLabel;
  final ConfirmTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final acento =
        tone == ConfirmTone.destructive ? scheme.error : scheme.primary;

    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: acento.withValues(alpha: 0.16),
                border: Border.all(color: acento.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: acento, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    child: Text(cancelarLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: acento,
                      foregroundColor:
                          tone == ConfirmTone.destructive ? scheme.onError : null,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(0, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(confirmarLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
