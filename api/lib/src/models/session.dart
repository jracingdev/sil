import 'operador.dart';

class Session {
  const Session({
    required this.token,
    required this.operador,
    required this.criadoEm,
  });

  final String token;
  final Operador operador;
  final DateTime criadoEm;
}
