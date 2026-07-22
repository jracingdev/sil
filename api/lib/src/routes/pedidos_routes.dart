import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http_json.dart';
import '../winthor/winthor_repository.dart';
import 'auth_routes.dart';

Router buildPedidosRouter({required WinthorRepository winthor}) {
  final router = Router();

  router.get('/', (Request request) async {
    final session = sessionOf(request);
    final queryFilial = int.tryParse(request.url.queryParameters['codfilial'] ?? '');
    final codfilial = queryFilial ?? session.operador.codfilial;

    try {
      final pedidos = await winthor.listarPedidos(codfilial: codfilial);
      return jsonOk({
        'pedidos': pedidos.map((p) => p.toJson()).toList(),
      });
    } on WinthorNotConfiguredException catch (e) {
      return jsonError(e.message, status: 503, codigo: 'winthor_nao_configurado');
    } on UnimplementedError catch (e) {
      return jsonError(
        e.message ?? 'Winthor não implementado',
        status: 501,
        codigo: 'winthor_nao_implementado',
      );
    }
  });

  router.post('/<id>/reservar', (Request request, String id) async {
    final session = sessionOf(request);
    late final Map<String, Object?> body;
    try {
      body = await readJson(request);
    } on FormatException catch (e) {
      return jsonError(e.message, status: 400, codigo: 'json_invalido');
    }

    final numComanda = (body['numComanda'] as String?)?.trim() ?? '';
    if (numComanda.isEmpty) {
      return jsonError(
        'Informe numComanda',
        status: 400,
        codigo: 'campos_obrigatorios',
      );
    }

    try {
      final pedido = await winthor.reservarPedido(
        id: id,
        numComanda: numComanda,
        operador: session.operador,
      );
      return jsonOk(pedido.toJson());
    } on WinthorNotFoundException catch (e) {
      return jsonError(e.message, status: 404, codigo: 'pedido_nao_encontrado');
    } on WinthorConflictException catch (e) {
      return jsonError(e.message, status: 409, codigo: 'pedido_ja_reservado');
    } on WinthorNotConfiguredException catch (e) {
      return jsonError(e.message, status: 503, codigo: 'winthor_nao_configurado');
    } on UnimplementedError catch (e) {
      return jsonError(
        e.message ?? 'Winthor não implementado',
        status: 501,
        codigo: 'winthor_nao_implementado',
      );
    }
  });

  router.post('/<id>/finalizar', (Request request, String id) async {
    final session = sessionOf(request);
    try {
      await winthor.finalizarPedido(id: id, operador: session.operador);
      return jsonNoContent();
    } on WinthorNotFoundException catch (e) {
      return jsonError(e.message, status: 404, codigo: 'pedido_nao_encontrado');
    } on WinthorNotConfiguredException catch (e) {
      return jsonError(e.message, status: 503, codigo: 'winthor_nao_configurado');
    } on UnimplementedError catch (e) {
      return jsonError(
        e.message ?? 'Winthor não implementado',
        status: 501,
        codigo: 'winthor_nao_implementado',
      );
    }
  });

  return router;
}
