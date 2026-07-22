import '../config.dart';
import '../models/models.dart';
import 'winthor_repository.dart';

/// Stub da conexão Oracle/Winthor.
///
/// Quem encomendou o app preenche os métodos com SQL/procedures reais
/// (PCEMPR, PCPEDC, etc.) usando o driver Oracle escolhido pela TI.
///
/// Ative com `SIL_WINTHOR_PROVIDER=oracle` e as variáveis
/// `SIL_ORACLE_CONN`, `SIL_ORACLE_USER`, `SIL_ORACLE_PASSWORD`.
class OracleWinthorRepository implements WinthorRepository {
  OracleWinthorRepository(this.config);

  final ApiConfig config;

  @override
  String get providerName => 'oracle';

  void _ensureConfigured() {
    if (config.oracleConnectionString == null ||
        config.oracleUser == null ||
        config.oraclePassword == null) {
      throw WinthorNotConfiguredException(
        'Defina SIL_ORACLE_CONN, SIL_ORACLE_USER e SIL_ORACLE_PASSWORD',
      );
    }
  }

  @override
  Future<Operador?> autenticar(String usuario, String senha) async {
    _ensureConfigured();
    // TODO(winthor): validar em PCEMPR / tabela de usuários Winthor.
    // Rejeitar TIPOVENDA = C (ou equivalente) com WinthorForbiddenException.
    throw UnimplementedError(
      'OracleWinthorRepository.autenticar — implementar conexão Winthor',
    );
  }

  @override
  Future<List<Pedido>> listarPedidos({required int codfilial}) async {
    _ensureConfigured();
    // TODO(winthor): SELECT na fila de separação (PCPEDC + itens + endereço).
    // Ordenar por prioridade de frete (887, 1038, 313, 1093) e data.
    throw UnimplementedError(
      'OracleWinthorRepository.listarPedidos — implementar conexão Winthor',
    );
  }

  @override
  Future<Pedido> reservarPedido({
    required String id,
    required String numComanda,
    required Operador operador,
  }) async {
    _ensureConfigured();
    // TODO(winthor): reserva atômica (UPDATE condicional / lock) + retorno do payload.
    throw UnimplementedError(
      'OracleWinthorRepository.reservarPedido — implementar conexão Winthor',
    );
  }

  @override
  Future<void> finalizarPedido({
    required String id,
    required Operador operador,
  }) async {
    _ensureConfigured();
    // TODO(winthor):
    // UPDATE PCPEDC SET DTFINALSEP1 = SYSDATE WHERE NUMPED = :id
    throw UnimplementedError(
      'OracleWinthorRepository.finalizarPedido — implementar conexão Winthor',
    );
  }
}
