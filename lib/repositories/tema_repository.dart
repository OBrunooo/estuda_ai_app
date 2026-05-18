import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_decode_util.dart';
import '../models/conjunto_estudo.dart';
import '../models/questao_model.dart';
import '../models/tema_resumo_model.dart';

/// Acesso aos endpoints autenticados de tema/conjuntos/questões do Laravel:
///
/// - `GET /api/buscar-gerar-questoes-tema?tema=…` — **síncrono**, pode levar
///   minutos (três chamadas em sequência à OpenAI). Retorna `{success, message}`.
/// - `GET /api/listar-temas-user` — `{temas: [{id, nome, porcentagem_conclusao}]}`
/// - `GET /api/listar-conjuntos-tema?tema_id=…` — `{conjuntos: [{id, conclusao}]}`
/// - `GET /api/listar-questoes-conjunto?conjunto_id=…` — `{success, questoes: […]}`
/// - `POST /api/concluir-conjunto` body `{conjunto_id}` — marca como concluído.
class TemaRepository {
  TemaRepository(this._client);

  final ApiClient _client;

  /// Verifica se o tema já existe no backend ou dispara a geração via IA.
  ///
  /// A API é **síncrona** (sem polling). Esta chamada pode bloquear vários
  /// minutos; o cliente usa [ApiClient.getLongRunning] (timeout de 60min).
  ///
  /// Devolve [VerificarTemaResponse.ok] com o nome **normalizado** do tema
  /// (maiúsculo) quando o backend o expõe, ou [VerificarTemaResponse.error]
  /// quando o backend rejeita (ex.: tema inválido).
  ///
  /// [temasAntes] (opcional) é a lista de temas do usuário **antes** da
  /// chamada — quando informada, permite identificar o tema recém-criado
  /// nos casos em que a resposta de sucesso não inclui o nome.
  Future<VerificarTemaResponse> verificarOuGerar(
    String tema, {
    List<TemaResumoModel>? temasAntes,
  }) async {
    final raw = await _client.getLongRunning(
      'buscar-gerar-questoes-tema',
      queryParameters: <String, dynamic>{'tema': tema},
    );
    final data = parseResponseData(raw);
    if (data is! Map) {
      throw ApiException('Resposta inesperada ao verificar tema', payload: data);
    }
    final map = Map<String, dynamic>.from(data);
    final success = map['success'];
    final message = (map['message'] ?? map['mensagem'])?.toString() ?? '';

    if (success == false) {
      return VerificarTemaResponse.error(
        message.isNotEmpty ? message : 'Não foi possível usar este tema',
      );
    }
    if (success != true) {
      throw ApiException(
        'Resposta inesperada do servidor ao gerar tema',
        payload: map,
      );
    }

    // Caso 1: tema já existia. A mensagem traz o nome normalizado.
    final nomePelaMsg = _extrairTemaDeMensagem(message);
    if (nomePelaMsg != null) {
      return VerificarTemaResponse.ok(nomePelaMsg);
    }

    // Caso 2: tema novo. A API não devolve o nome normalizado, então
    // listamos os temas e descobrimos qual entrou.
    final atuais = await listarTemas();
    final idsAntes = (temasAntes ?? const <TemaResumoModel>[])
        .map((t) => t.temaId)
        .toSet();
    final novos = atuais.where((t) => !idsAntes.contains(t.temaId)).toList();
    if (novos.length == 1) {
      return VerificarTemaResponse.ok(novos.first.tema);
    }
    if (novos.isNotEmpty) {
      // Pegamos o de maior id (o mais recentemente criado).
      novos.sort((a, b) => b.temaId.compareTo(a.temaId));
      return VerificarTemaResponse.ok(novos.first.tema);
    }
    throw ApiException(
      'Tema gerado, mas não foi possível identificar o nome normalizado.',
      payload: map,
    );
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

  /// Carrega todos os conjuntos do tema **com suas questões** (uma chamada
  /// para listar conjuntos + uma chamada por conjunto para listar questões).
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
      final questoes = await _listarQuestoesConjunto(id);
      out.add(
        ConjuntoEstudo(
          indice: i + 1,
          conjuntoId: id,
          concluido: concluido,
          questoes: questoes,
        ),
      );
    }
    return out;
  }

  Future<List<QuestaoModel>> _listarQuestoesConjunto(int conjuntoId) async {
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

  /// Extrai o nome do tema da mensagem
  /// "O usuário já está cadastrado no tema XYZ".
  String? _extrairTemaDeMensagem(String message) {
    final regex = RegExp(
      r'no tema\s+(.+?)\s*$',
      caseSensitive: false,
    );
    final m = regex.firstMatch(message);
    if (m == null) return null;
    final nome = m.group(1)?.trim();
    if (nome == null || nome.isEmpty) return null;
    return nome;
  }
}

class VerificarTemaResponse {
  VerificarTemaResponse._({this.temaNome, this.errorMessage});

  factory VerificarTemaResponse.ok(String temaNome) {
    return VerificarTemaResponse._(temaNome: temaNome);
  }

  factory VerificarTemaResponse.error(String message) {
    return VerificarTemaResponse._(errorMessage: message);
  }

  final String? temaNome;
  final String? errorMessage;

  bool get isOk => temaNome != null;
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
