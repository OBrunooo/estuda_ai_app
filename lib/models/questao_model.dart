/// Questão com quatro alternativas.
///
/// `GET /api/listar-questoes-conjunto` devolve itens no formato:
/// `{id, questao, alternativa1, alternativa2, alternativa3, alternativa4}`.
///
/// Convenção do backend (`QuestoesController::analisarESelecionarQuestoes`):
/// **a primeira alternativa é sempre a correta**. O Flutter embaralha as
/// alternativas na UI (ver `QuestoesSessionScreen`).
class QuestaoModel {
  QuestaoModel({
    required this.id,
    required this.questao,
    required this.alternativa1,
    required this.alternativa2,
    required this.alternativa3,
    required this.alternativa4,
  });

  factory QuestaoModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is int
        ? idRaw
        : idRaw is num
            ? idRaw.toInt()
            : int.tryParse(idRaw?.toString() ?? '') ?? 0;
    return QuestaoModel(
      id: id,
      questao: (json['questao'] ?? '').toString(),
      alternativa1: (json['alternativa1'] ?? '').toString(),
      alternativa2: (json['alternativa2'] ?? '').toString(),
      alternativa3: (json['alternativa3'] ?? '').toString(),
      alternativa4: (json['alternativa4'] ?? '').toString(),
    );
  }

  final int id;
  final String questao;
  final String alternativa1;
  final String alternativa2;
  final String alternativa3;
  final String alternativa4;
}
