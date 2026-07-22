import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rhm_coletor/data/api/api_exception.dart';
import 'package:rhm_coletor/data/api/sil_api_client.dart';
import 'package:rhm_coletor/services/session_service.dart';

void main() {
  group('SilApiClient (HTTP mock)', () {
    test('login guarda token e monta operador', () async {
      final client = SilApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/login');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({
              'token': 'tok-1',
              'operador': {
                'matricula': '12',
                'nome': 'Rodrigo',
                'nomeGuerra': 'RSGUIMARAES',
                'codfilial': 1,
                'permissoes': ['picking'],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.login('RSGUIMARAES', '1234');
      expect(result.token, 'tok-1');
      expect(client.authToken, 'tok-1');
      expect(result.operador.nomeGuerra, 'RSGUIMARAES');
    });

    test('login 403 vira ApiException', () async {
      final client = SilApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'erro': 'Login permitido apenas para separadores',
              'codigo': 'nao_separador',
            }),
            403,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      expect(
        () => client.login('MCOMPRAS', '1234'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.codigo, 'codigo', 'nao_separador'),
        ),
      );
    });

    test('listar envia Bearer e parseia pedidos', () async {
      final client = SilApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer tok-x');
          return http.Response(
            jsonEncode({
              'pedidos': [
                {
                  'id': '1',
                  'data': '2026-02-13',
                  'codFornecFrete': 887,
                  'cliente': 'Cliente',
                  'itens': [
                    {
                      'codauxiliar': '20953',
                      'codfab': 'X',
                      'desc': 'Item',
                      'm': '03',
                      'r': '03',
                      'p': '9',
                      'a': '308',
                      'qtd': 2,
                    },
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      )..authToken = 'tok-x';

      final pedidos = await client.listarPedidos();
      expect(pedidos, hasLength(1));
      expect(pedidos.first.id, '1');
      expect(pedidos.first.itens.first.codauxiliar, '20953');
    });
  });

  group('SessionService', () {
    test('login via API preenche operador', () async {
      final api = SilApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'token': 'sess',
              'operador': {
                'matricula': '45',
                'nome': 'João',
                'nomeGuerra': 'JOAOSEP',
                'codfilial': 1,
                'permissoes': ['picking'],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final session = SessionService(api: api);

      final erro = await session.login('JOAOSEP', '1234');
      expect(erro, isNull);
      expect(session.operador?.nomeGuerra, 'JOAOSEP');
      expect(session.operador?.token, 'sess');
    });

    test('logout limpa token do cliente', () async {
      final api = SilApiClient(baseUrl: 'http://test')..authToken = 'abc';
      final session = SessionService(api: api);
      session.logout();
      expect(api.authToken, isNull);
      expect(session.operador, isNull);
    });
  });
}
