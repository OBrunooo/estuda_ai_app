/// Resumo de um tema vinculado ao usuário.
///
/// Mapeia o item retornado por `GET /api/listar-temas-user`:
/// ```json
/// {"id": 1, "nome": "Laravel", "porcentagem_conclusao": 42}
/// ```
/// `porcentagem_conclusao` pode vir `null` (quando o tema não tem conjuntos
/// calculáveis) e varia de 0 a 100.
class TemaResumoModel {
  TemaResumoModel({
    required this.tema,
    required this.temaId,
    required this.conclusao,
  });

  factory TemaResumoModel.fromJson(Map<String, dynamic> json) {
    final nome = (json['nome'] ?? json['tema'])?.toString();
    final idRaw = json['id'] ?? json['temaId'] ?? json['tema_id'];
    if (nome == null || nome.isEmpty || idRaw == null) {
      throw FormatException(
        'Tema com campos obrigatórios ausentes: $json',
      );
    }
    final id = idRaw is int
        ? idRaw
        : idRaw is num
            ? idRaw.toInt()
            : int.parse(idRaw.toString());

    final c = json['porcentagem_conclusao'] ?? json['conclusao'];
    var conclusao = 0;
    if (c is int) {
      conclusao = c;
    } else if (c is num) {
      conclusao = c.toInt();
    } else if (c is bool) {
      conclusao = c ? 100 : 0;
    } else if (c is String && c.isNotEmpty) {
      conclusao = int.tryParse(c) ?? 0;
    }
    if (conclusao < 0) conclusao = 0;
    if (conclusao > 100) conclusao = 100;

    return TemaResumoModel(tema: nome, temaId: id, conclusao: conclusao);
  }

  /// Nome do tema (normalizado pelo backend, MAIÚSCULO).
  final String tema;
  final int temaId;

  /// Percentual de conclusão (0–100).
  final int conclusao;

  bool get concluido => conclusao >= 100;
}
