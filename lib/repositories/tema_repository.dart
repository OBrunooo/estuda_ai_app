import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_decode_util.dart';
import '../models/conjunto_estudo.dart';
import '../models/questao_model.dart';
import '../models/tema_resumo_model.dart';

/// Acesso aos endpoints autenticados de tema/conjuntos/questões do Laravel:
///
/// - `GET /api/buscar-gerar-questoes-tema?tema=…` — **enfileira um job**
///   no backend e retorna imediatamente `{success:true, message:"Buscando
///   e gerando questões para o tema $tema"}`. A geração roda em background;
///   o app descobre que terminou via polling em [listarTemas].
/// - `GET /api/listar-temas-user` — `{temas: [{id, nome, porcentagem_conclusao}]}`
/// - `GET /api/listar-conjuntos-tema?tema_id=…` — `{conjuntos: [{id, conclusao}]}`
/// - `GET /api/listar-questoes-conjunto?conjunto_id=…` — `{success, questoes: […]}`
/// - `POST /api/concluir-conjunto` body `{conjunto_id}` — marca como concluído.
class TemaRepository {
  TemaRepository(this._client);

  final ApiClient _client;

  /// Dispara o job que vai buscar/gerar as questões do tema no backend.
  ///
  /// A chamada é **rápida**: o backend só enfileira o job. As questões
  /// (e o próprio registro do tema) só aparecem em [listarTemas] depois
  /// que o job processar, por isso esse retorno **não** confirma que o
  /// tema já existe — apenas que o job foi disparado.
  ///
  /// Lança [ApiException] em caso de erro de transporte ou se o backend
  /// devolver `success:false` (ex.: tema rejeitado antes do dispatch).
  Future<void> dispararGeracao(String tema) async {
    final raw = await _client.get(
      'buscar-gerar-questoes-tema',
      queryParameters: <String, dynamic>{'tema': tema},
    );
    final data = parseResponseData(raw);
    if (data is! Map) {
      throw ApiException(
        'Resposta inesperada ao iniciar a geração',
        payload: data,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final success = map['success'];
    if (success != true) {
      final msg = (map['message'] ?? map['mensagem'])?.toString();
      throw ApiException(
        msg != null && msg.isNotEmpty
            ? msg
            : 'Não foi possível iniciar a geração do tema',
        payload: map,
      );
    }
  }

  /// Lista os temas vinculados ao usuário autenticado.
  Future<List<TemaResumoModel>> listarTemas() async {
    final raw = await _client.get('listar-temas-user');
    final data = parseResponseData(raw);
    if (data is! Map || data['temas'] is! List) {
      throw ApiException('Lista de temas inválida', payload: data);
    }
    final List<dynamic> items = List<dynamic>.from(data['temas'] as List);
    return items
        .whereType<Map>()
        .map((e) => TemaResumoModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Lista apenas os **metadados** dos conjuntos do tema (id, conclusão) —
  /// **sem** carregar as questões de cada conjunto.
  ///
  /// As questões são carregadas sob demanda via [listarQuestoesConjunto]
  /// somente quando o usuário escolhe um conjunto para estudar, evitando
  /// múltiplas chamadas à API ao abrir o tema.
  Future<List<ConjuntoEstudo>> carregarConjuntosDoTema(int temaId) async {
    final rawConjuntos = await _client.get(
      'listar-conjuntos-tema',
      queryParameters: <String, dynamic>{'tema_id': temaId},
    );
    final dataConjuntos = parseResponseData(rawConjuntos);
    if (dataConjuntos is! Map || dataConjuntos['conjuntos'] is! List) {
      throw ApiException(
        'Lista de conjuntos inválida',
        payload: dataConjuntos,
      );
    }

    final lista = List<dynamic>.from(dataConjuntos['conjuntos'] as List);
    final out = <ConjuntoEstudo>[];
    for (var i = 0; i < lista.length; i++) {
      final item = lista[i];
      if (item is! Map) continue;
      final id = _asInt(item['id']);
      if (id == null) continue;
      final concluido = _asBool(item['conclusao']);
      out.add(
        ConjuntoEstudo(
          indice: i + 1,
          conjuntoId: id,
          concluido: concluido,
        ),
      );
    }
    return out;
  }

  /// Lista as questões de um conjunto específico. Chamada sob demanda quando
  /// o usuário escolhe um conjunto em [ConjuntosSessionScreen].
  Future<List<QuestaoModel>> listarQuestoesConjunto(int conjuntoId) async {
    final raw = await _client.get(
      'listar-questoes-conjunto',
      queryParameters: <String, dynamic>{'conjunto_id': conjuntoId},
    );
    final data = parseResponseData(raw);
    if (data is! Map || data['questoes'] is! List) {
      throw ApiException(
        'Questões do conjunto inválidas',
        payload: data,
      );
    }
    final lista = List<dynamic>.from(data['questoes'] as List);
    return lista
        .whereType<Map>()
        .map((e) => QuestaoModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Marca o conjunto como concluído para o usuário atual.
  Future<void> concluirConjunto(int conjuntoId) async {
    await _client.post(
      'concluir-conjunto',
      data: <String, dynamic>{'conjunto_id': conjuntoId},
    );
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool _asBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1';
}
