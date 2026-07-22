import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'http_json.dart';
import 'routes/auth_routes.dart';
import 'routes/pedidos_routes.dart';
import 'session_store.dart';
import 'winthor/mock_winthor_repository.dart';
import 'winthor/oracle_winthor_repository.dart';
import 'winthor/winthor_repository.dart';

class SilApi {
  SilApi({
    required this.config,
    WinthorRepository? winthor,
    SessionStore? sessions,
  })  : winthor = winthor ?? _createWinthor(config),
        sessions = sessions ?? SessionStore();

  final ApiConfig config;
  final WinthorRepository winthor;
  final SessionStore sessions;

  static WinthorRepository _createWinthor(ApiConfig config) {
    if (config.usaOracle) {
      return OracleWinthorRepository(config);
    }
    return MockWinthorRepository();
  }

  Handler get handler {
    final router = Router();

    router.get('/health', (Request request) {
      return jsonOk({
        'status': 'ok',
        'winthor': winthor.providerName,
      });
    });

    router.mount(
      '/auth',
      buildAuthRouter(winthor: winthor, sessions: sessions).call,
    );

    final pedidos = Pipeline()
        .addMiddleware(requireAuth(sessions))
        .addHandler(buildPedidosRouter(winthor: winthor).call);

    router.mount('/pedidos', pedidos);

    return Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsHeaders())
        .addHandler(router.call);
  }
}
