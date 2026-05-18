import 'dart:convert';

import 'api_exception.dart';

/// O backend Laravel em alguns controllers retorna `json_encode(...)` como
/// string no corpo; com [ResponseType.json] o Dio já entrega [Map]/[List].
/// Este util aceita os dois casos e normaliza strings JSON aninhadas.
dynamic parseResponseData(dynamic data) {
  if (data == null) return null;
  if (data is Map || data is List) {
    return data;
  }
  dynamic current = data;
  while (current is String) {
    final trimmed = current.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
      throw ApiException('Resposta HTML inesperada da API');
    }
    try {
      current = jsonDecode(trimmed);
    } on FormatException {
      return trimmed;
    }
  }
  return current;
}
