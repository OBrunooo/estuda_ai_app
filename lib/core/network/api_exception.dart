class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.payload});

  final String message;
  final int? statusCode;
  final Object? payload;

  @override
  String toString() =>
      'ApiException($statusCode): $message${payload != null ? ' | $payload' : ''}';
}
