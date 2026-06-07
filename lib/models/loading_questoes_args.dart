/// Argumentos para [LoadingQuestoesScreen]: tema **já vinculado** ao usuário.
///
/// Geração de tema novo deixou de passar por esta tela — agora roda em
/// segundo plano via [TemaStudyService.iniciarGeracaoEmSegundoPlano],
/// com polling silencioso até o tema aparecer em `listar-temas-user`.
class LoadingQuestoesArgs {
  LoadingQuestoesArgs({required this.temaId, required this.temaNome});

  final int temaId;
  final String temaNome;
}
