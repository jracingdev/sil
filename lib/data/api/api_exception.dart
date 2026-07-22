/// Erro HTTP/API com mensagem amigável para a UI.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.codigo});

  final String message;
  final int? statusCode;
  final String? codigo;

  @override
  String toString() => message;
}
