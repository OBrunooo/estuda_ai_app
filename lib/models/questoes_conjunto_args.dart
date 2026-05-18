import 'conjunto_estudo.dart';

/// Navegação para [QuestoesSessionScreen] com um único conjunto (seção).
class QuestoesConjuntoArgs {
  QuestoesConjuntoArgs({
    required this.temaNome,
    required this.conjunto,
  });

  final String temaNome;
  final ConjuntoEstudo conjunto;
}
