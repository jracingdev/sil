import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http_json.dart';
import '../models/models.dart';
import '../session_store.dart';
import '../winthor/winthor_repository.dart';

Router buildAuthRouter({
  required WinthorRepository winthor,
  required SessionStore sessions,
}) {
  final router = Router();

  router.post('/login', (Request request) async {
    late final Map<String, Object?> body;
    try {
      body = await readJson(request);
    } on FormatException catch (e) {
      return jsonError(e.message, status: 400, codigo: 'json_invalido');
    }

    final usuario = (body['usuario'] as String?)?.trim() ?? '';
    final senha = body['senha'] as String? ?? '';
    if (usuario.isEmpty || senha.isEmpty) {
      return jsonError(
        'Informe usuario e senha',
        status: 400,
        codigo: 'campos_obrigatorios',
      );
    }

    try {
      final operador = await winthor.autenticar(usuario, senha);
      if (operador == null) {
        return jsonError(
          'Usuário ou senha incorretos',
          status: 401,
          codigo: 'credenciais_invalidas',
        );
      }
      final session = sessions.create(operador);
      return jsonOk({
        'token': session.token,
        'operador': session.operador.toJson(),
      });
    } on WinthorForbiddenException catch (e) {
      return jsonError(e.message, status: 403, codigo: 'nao_separador');
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

Middleware requireAuth(SessionStore sessions) {
  return (Handler inner) {
    return (Request request) async {
      final token = bearerToken(request);
      final session = sessions.get(token);
      if (session == null) {
        return jsonError(
          'Token ausente ou inválido',
          status: 401,
          codigo: 'nao_autenticado',
        );
      }
      return inner(request.change(context: {
        ...request.context,
        'session': session,
      }));
    };
  };
}

Session sessionOf(Request request) => request.context['session']! as Session;
