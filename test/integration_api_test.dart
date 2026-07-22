import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_coletor/data/api/api_exception.dart';
import 'package:rhm_coletor/data/api/sil_api_client.dart';
import 'package:rhm_coletor/services/session_service.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sil_api/sil_api.dart';

/// Sobe a API real em porta efêmera e valida o cliente Flutter contra ela.
void main() {
  late HttpServer server;
  late SilApiClient client;
  late String baseUrl;

  setUp(() async {
    final api = SilApi(config: const ApiConfig());
    server = await shelf_io.serve(api.handler, InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.host}:${server.port}';
    client = SilApiClient(baseUrl: baseUrl);
  });

  tearDown(() async {
    client.clearSession();
    await server.close(force: true);
  });

  test('health da API de integração', () async {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse('$baseUrl/health'));
    final response = await request.close();
    expect(response.statusCode, 200);
    httpClient.close(force: true);
  });

  test('fluxo coletor: login → listar → reservar → finalizar', () async {
    final session = SessionService(api: client);
    final erro = await session.login('RSGUIMARAES', '1234');
    expect(erro, isNull);
    expect(client.authToken, isNotNull);

    final pedidos = await client.listarPedidos(
      codfilial: session.operador!.codfilial,
    );
    expect(pedidos, isNotEmpty);
    expect(pedidos.first.codFornecFrete, 887);

    final id = pedidos.first.id;
    final reservado = await client.reservarPedido(id, '99');
    expect(reservado.numComanda, '99');
    expect(reservado.itens, isNotEmpty);

    await client.finalizarPedido(id);

    final restantes = await client.listarPedidos();
    expect(restantes.any((p) => p.id == id), isFalse);
  });

  test('não-separador é rejeitado no login', () async {
    final session = SessionService(api: client);
    final erro = await session.login('MCOMPRAS', '1234');
    expect(erro, contains('separadores'));
    expect(session.operador, isNull);
  });

  test('pedido sem token retorna 401', () async {
    expect(
      () => client.listarPedidos(),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
  });
}
