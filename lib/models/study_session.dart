import 'conjunto_estudo.dart';

/// Sessão de estudo: tema + questões agrupadas por conjunto (como na API).
class StudySession {
  StudySession({
    required this.temaNome,
    required this.temaId,
    required this.conjuntos,
  });

  final String temaNome;
  final int temaId;
  final List<ConjuntoEstudo> conjuntos;

  int get totalQuestoes =>
      conjuntos.fold<int>(0, (s, c) => s + c.questoes.length);
}
