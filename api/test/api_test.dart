import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:sil_api/sil_api.dart';
import 'package:test/test.dart';

void main() {
  late SilApi api;
  late Handler handler;

  setUp(() {
    api = SilApi(config: const ApiConfig());
    handler = api.handler;
  });

  Future<Response> postJson(String path, Map<String, Object?> body,
      {String? token}) async {
    return handler(
      Request(
        'POST',
        Uri.parse('http://localhost$path'),
        headers: {
          'content-type': 'application/json',
          if (token != null) 'authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ),
    );
  }

  Future<Response> get(String path, {String? token}) async {
    return handler(
      Request(
        'GET',
        Uri.parse('http://localhost$path'),
        headers: {
          if (token != null) 'authorization': 'Bearer $token',
        },
      ),
    );
  }

  test('health responde ok com provedor mock', () async {
    final res = await get('/health');
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map;
    expect(body['status'], 'ok');
    expect(body['winthor'], 'mock');
  });

  test('login separador retorna token e operador', () async {
    final res = await postJson('/auth/login', {
      'usuario': 'RSGUIMARAES',
      'senha': '1234',
    });
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map;
    expect(body['token'], isA<String>());
    expect(body['operador']['nomeGuerra'], 'RSGUIMARAES');
  });

  test('login TIPOVENDA=C é bloqueado', () async {
    final res = await postJson('/auth/login', {
      'usuario': 'MCOMPRAS',
      'senha': '1234',
    });
    expect(res.statusCode, 403);
  });

  test('fluxo listar → reservar → finalizar', () async {
    final login = await postJson('/auth/login', {
      'usuario': 'JOAOSEP',
      'senha': '1234',
    });
    final token =
        (jsonDecode(await login.readAsString()) as Map)['token'] as String;

    final lista = await get('/pedidos', token: token);
    expect(lista.statusCode, 200);
    final pedidos =
        (jsonDecode(await lista.readAsString()) as Map)['pedidos'] as List;
    expect(pedidos, isNotEmpty);
    expect(pedidos.first['codFornecFrete'], 887);

    final id = pedidos.first['id'] as String;
    final reservado = await postJson(
      '/pedidos/$id/reservar',
      {'numComanda': '12'},
      token: token,
    );
    expect(reservado.statusCode, 200);
    final pedido =
        jsonDecode(await reservado.readAsString()) as Map<String, dynamic>;
    expect(pedido['numComanda'], '12');

    final fim = await postJson('/pedidos/$id/finalizar', {}, token: token);
    expect(fim.statusCode, 204);
  });

  test('pedido sem token retorna 401', () async {
    final res = await get('/pedidos');
    expect(res.statusCode, 401);
  });
}
