import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonOk(Object body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response jsonError(String erro, {int status = 400, String? codigo}) =>
    jsonOk(
      {
        'erro': erro,
        'codigo': ?codigo,
      },
      status: status,
    );

Response jsonNoContent() => Response(204);

Future<Map<String, Object?>> readJson(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('JSON deve ser um objeto');
  }
  return Map<String, Object?>.from(decoded);
}

String? bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null) return null;
  final match = RegExp(r'^Bearer\s+(.+)$', caseSensitive: false).firstMatch(header);
  return match?.group(1)?.trim();
}
