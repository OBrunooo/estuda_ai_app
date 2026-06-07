import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'json_decode_util.dart';
import 'token_storage.dart';

typedef UnauthorizedCallback = void Function();

/// Cliente HTTP central (Dio) com token Sanctum.
///
/// Todas as chamadas usam timeouts padrão — a geração de questões agora roda
/// em job assíncrono no backend e o app descobre o resultado via polling em
/// `listar-temas-user`.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    UnauthorizedCallback? onUnauthorized,
    String? baseUrl,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _onUnauthorized = onUnauthorized,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: AppConfig.defaultConnectTimeout,
                receiveTimeout: AppConfig.defaultReceiveTimeout,
                sendTimeout: AppConfig.defaultSendTimeout,
                followRedirects: true,
                maxRedirects: 20,
                responseType: ResponseType.json,
                validateStatus: (status) => status != null && status < 600,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          if (e.response?.statusCode == 401) {
            _onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final UnauthorizedCallback? _onUnauthorized;
  final Dio _dio;

  Dio get dio => _dio;

  /// GET com parsing tolerante a corpo string JSON.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// POST com parsing tolerante.
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  dynamic _handleResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final parsed = parseResponseData(response.data);

    if (status == 401) {
      _onUnauthorized?.call();
      throw ApiException(
        _messageFromErrorBody(parsed) ?? 'Não autenticado',
        statusCode: status,
        payload: parsed,
      );
    }

    // Bug do bootstrap/app.php: AuthenticationException retorna 200 com
    // `{status: "error", message: "Usuário não autenticado"}` em vez de 401.
    // Detectamos esse caso para acionar o fluxo de logout normalmente.
    if (status < 400 && _looksLikeAuthError(parsed)) {
      _onUnauthorized?.call();
      throw ApiException(
        _messageFromErrorBody(parsed) ?? 'Não autenticado',
        statusCode: 401,
        payload: parsed,
      );
    }

    if (status >= 400) {
      final message = _messageFromErrorBody(parsed) ?? 'Erro HTTP $status';
      throw ApiException(message, statusCode: status, payload: parsed);
    }

    return parsed;
  }

  /// Detecta o envelope `{status:"error", message/mensagem:"Usuário não autenticado"}`
  /// devolvido pelo handler global do Laravel em respostas 200.
  bool _looksLikeAuthError(dynamic parsed) {
    if (parsed is! Map) return false;
    final s = parsed['status']?.toString().toLowerCase();
    if (s != 'error') return false;
    final m = (parsed['message'] ?? parsed['mensagem'])
        ?.toString()
        .toLowerCase();
    if (m == null) return false;
    return m.contains('não autenticado') ||
        m.contains('nao autenticado') ||
        m.contains('unauthenticated');
  }

  /// Extrai uma mensagem amigável de respostas de erro do Laravel.
  /// Trata:
  /// - 422 `{errors: {campo: ["mensagem", ...]}}` (Validator do Laravel)
  /// - 401/404/500 `{message: ...}` / `{mensagem: ...}` / `{error: ...}`
  /// - `{success:false, message: ...}` (convenção dos controllers)
  String? _messageFromErrorBody(dynamic parsed) {
    if (parsed is! Map) return null;
    final map = Map<String, dynamic>.from(parsed);

    final err = map['errors'];
    if (err is Map) {
      final firstMessages = <String>[];
      err.forEach((_, value) {
        if (value is List && value.isNotEmpty) {
          firstMessages.add(value.first.toString());
        } else if (value != null) {
          firstMessages.add(value.toString());
        }
      });
      if (firstMessages.isNotEmpty) return firstMessages.join('\n');
    } else if (err != null) {
      return err.toString();
    }

    final candidates = [
      map['message'],
      map['mensagem'],
      map['error'],
      map['errorMessage'],
    ];
    for (final c in candidates) {
      if (c != null && c.toString().isNotEmpty) return c.toString();
    }
    return null;
  }

  ApiException _mapDio(DioException e) {
    // Resposta HTTP recebida (>=400) — preserva mensagem do backend.
    if (e.response != null) {
      final parsed = parseResponseData(e.response!.data);
      final code = e.response!.statusCode;
      final msg = _messageFromErrorBody(parsed) ??
          'Erro do servidor (HTTP $code).';
      return ApiException(msg, statusCode: code, payload: parsed);
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return ApiException(
          'Não foi possível conectar ao servidor. Verifique sua conexão '
          'e tente novamente.',
          statusCode: null,
        );
      case DioExceptionType.sendTimeout:
        return ApiException(
          'A conexão demorou para enviar os dados. Verifique sua '
          'internet e tente novamente.',
          statusCode: null,
        );
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'O servidor demorou demais para responder. Tente novamente '
          'em alguns instantes.',
          statusCode: null,
        );
      case DioExceptionType.cancel:
        return ApiException('Requisição cancelada.', statusCode: null);
      case DioExceptionType.badCertificate:
        return ApiException(
          'Certificado do servidor inválido.',
          statusCode: null,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final err = e.error;

    // SocketException = host down, DNS fail, "connection refused", etc.
    if (err is SocketException) {
      return ApiException(
        'Não foi possível conectar ao servidor. Verifique sua conexão '
        'e tente novamente.',
        statusCode: null,
      );
    }

    if (err is FormatException) {
      return ApiException(
        'Resposta inválida do servidor. Tente novamente.',
        statusCode: null,
      );
    }

    return ApiException(
      'Não foi possível concluir a requisição. Tente novamente.',
      statusCode: null,
    );
  }
}
