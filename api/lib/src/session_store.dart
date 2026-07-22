import 'dart:math';

import 'models/models.dart';

/// Sessões em memória. O token nunca é persistido em disco pelo coletor.
class SessionStore {
  final Map<String, Session> _sessions = {};

  Session create(Operador operador) {
    final token =
        'sil-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    final session = Session(
      token: token,
      operador: operador,
      criadoEm: DateTime.now().toUtc(),
    );
    _sessions[token] = session;
    return session;
  }

  Session? get(String? token) {
    if (token == null || token.isEmpty) return null;
    return _sessions[token];
  }

  void revoke(String token) => _sessions.remove(token);
}
