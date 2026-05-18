/// Argumentos para [LoadingQuestoesScreen]: tema novo (texto), retomada após fechar o app,
/// ou tema já vinculado ao usuário.
class LoadingQuestoesArgs {
  LoadingQuestoesArgs.novo(String tema)
      : temaDigitado = tema.trim(),
        temaId = null,
        temaNome = null,
        retomarGeracao = false;

  /// Continua o polling usando [PendingTemaGenerationStorage] (tema + opcional normalizado).
  LoadingQuestoesArgs.retomarGeracao()
      : temaDigitado = null,
        temaId = null,
        temaNome = null,
        retomarGeracao = true;

  LoadingQuestoesArgs.existente({required this.temaId, required this.temaNome})
      : temaDigitado = null,
        retomarGeracao = false;

  final String? temaDigitado;
  final int? temaId;
  final String? temaNome;
  final bool retomarGeracao;

  bool get isNovoTema =>
      !retomarGeracao &&
      temaDigitado != null &&
      temaDigitado!.isNotEmpty;

  bool get isTemaExistente =>
      !retomarGeracao && temaId != null && temaNome != null;
}
