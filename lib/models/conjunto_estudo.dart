import 'questao_model.dart';

/// Um conjunto de questões retornado pelo backend.
///
/// `GET /api/listar-conjuntos-tema` devolve `{id, conclusao}` (sem questões),
/// e `GET /api/listar-questoes-conjunto?conjunto_id=` devolve as questões.
///
/// Por padrão, [questoes] vem **vazio**: o app só busca as questões quando o
/// usuário escolhe abrir o conjunto (carregamento sob demanda).
class ConjuntoEstudo {
  ConjuntoEstudo({
    required this.indice,
    required this.conjuntoId,
    this.questoes = const <QuestaoModel>[],
    this.concluido = false,
  });

  /// Índice de exibição (1-baseado), conforme a ordem retornada pela API.
  final int indice;
  final int conjuntoId;

  /// Questões já carregadas neste conjunto. Vazio até o usuário abri-lo.
  final List<QuestaoModel> questoes;

  /// Conclusão do usuário neste conjunto (`user_conclusao_conjunto.conclusao`).
  final bool concluido;

  ConjuntoEstudo copyWith({
    int? indice,
    int? conjuntoId,
    List<QuestaoModel>? questoes,
    bool? concluido,
  }) {
    return ConjuntoEstudo(
      indice: indice ?? this.indice,
      conjuntoId: conjuntoId ?? this.conjuntoId,
      questoes: questoes ?? this.questoes,
      concluido: concluido ?? this.concluido,
    );
  }
}
