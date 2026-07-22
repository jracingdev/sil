import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/operador.dart';
import '../../models/pedido.dart';
import 'api_exception.dart';

class LoginResult {
  const LoginResult({required this.token, required this.operador});
  final String token;
  final Operador operador;
}

/// Cliente HTTP da API S.I.L. (`api/`).
class SilApiClient {
  SilApiClient({http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _http;
  final String baseUrl;
  String? authToken;

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool auth = false, bool json = true}) => {
    if (json) 'content-type': 'application/json; charset=utf-8',
    'accept': 'application/json',
    if (auth && authToken != null) 'authorization': 'Bearer $authToken',
  };

  Future<LoginResult> login(String usuario, String senha) async {
    final response = await _send(
      () => _http.post(
        _uri('/auth/login'),
        headers: _headers(),
        body: jsonEncode({'usuario': usuario, 'senha': senha}),
      ),
    );
    final body = _decodeMap(response);
    if (response.statusCode == 200) {
      final token = body['token']! as String;
      final operador = Operador.fromJson(
        Map<String, Object?>.from(body['operador']! as Map),
      ).copyWith(token: token);
      authToken = token;
      return LoginResult(token: token, operador: operador);
    }
    throw _errorFrom(response, body);
  }

  Future<List<Pedido>> listarPedidos({int? codfilial}) async {
    final query = <String, String>{
      if (codfilial != null) 'codfilial': '$codfilial',
    };
    final response = await _send(
      () => _http.get(
        _uri('/pedidos', query.isEmpty ? null : query),
        headers: _headers(auth: true, json: false),
      ),
    );
    final body = _decodeMap(response);
    if (response.statusCode == 200) {
      final lista = body['pedidos']! as List;
      return lista
          .map((e) => Pedido.fromJson(Map<String, Object?>.from(e as Map)))
          .toList();
    }
    throw _errorFrom(response, body);
  }

  Future<Pedido> reservarPedido(String id, String numComanda) async {
    final response = await _send(
      () => _http.post(
        _uri('/pedidos/$id/reservar'),
        headers: _headers(auth: true),
        body: jsonEncode({'numComanda': numComanda}),
      ),
    );
    final body = _decodeMap(response);
    if (response.statusCode == 200) {
      return Pedido.fromJson(body);
    }
    throw _errorFrom(response, body);
  }

  Future<void> finalizarPedido(String id) async {
    final response = await _send(
      () => _http.post(
        _uri('/pedidos/$id/finalizar'),
        headers: _headers(auth: true),
        body: '{}',
      ),
    );
    if (response.statusCode == 204) return;
    final body = _decodeMap(response);
    throw _errorFrom(response, body);
  }

  void clearSession() => authToken = null;

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call();
    } on http.ClientException {
      throw ApiException(
        'Sem conexão com a API ($baseUrl). Verifique se o servidor está no ar.',
        codigo: 'rede',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Falha de rede: $e', codigo: 'rede');
    }
  }

  Map<String, Object?> _decodeMap(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    return {};
  }

  ApiException _errorFrom(http.Response response, Map<String, Object?> body) {
    final erro = body['erro'] as String? ?? 'Erro na API (${response.statusCode})';
    final codigo = body['codigo'] as String?;
    return ApiException(erro, statusCode: response.statusCode, codigo: codigo);
  }
}
