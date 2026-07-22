import '../models/models.dart';

/// Contrato de acesso ao ERP Winthor.
///
/// Quem conecta o Oracle implementa esta interface (ver
/// [OracleWinthorRepository]) e configura `SIL_WINTHOR_PROVIDER=oracle`.
abstract class WinthorRepository {
  /// Nome do provedor ativo (`mock` | `oracle`).
  String get providerName;

  /// Autentica operador. Retorna null se credenciais inválidas.
  /// Deve rejeitar não-separadores (ex.: TIPOVENDA = C) lançando
  /// [WinthorForbiddenException].
  Future<Operador?> autenticar(String usuario, String senha);

  /// Pedidos pendentes de separação, já ordenados por prioridade de frete + data.
  Future<List<Pedido>> listarPedidos({required int codfilial});

  /// Reserva atômica + payload completo para download no coletor.
  /// Lança [WinthorConflictException] se já reservado.
  Future<Pedido> reservarPedido({
    required String id,
    required String numComanda,
    required Operador operador,
  });

  /// Finaliza separação (ex.: UPDATE PCPEDC SET DTFINALSEP1 = SYSDATE).
  Future<void> finalizarPedido({
    required String id,
    required Operador operador,
  });
}

class WinthorNotFoundException implements Exception {
  WinthorNotFoundException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WinthorConflictException implements Exception {
  WinthorConflictException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WinthorForbiddenException implements Exception {
  WinthorForbiddenException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WinthorNotConfiguredException implements Exception {
  WinthorNotConfiguredException(this.message);
  final String message;
  @override
  String toString() => message;
}
