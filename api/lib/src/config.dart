/// Configuração da API via variáveis de ambiente.
class ApiConfig {
  const ApiConfig({
    this.host = '0.0.0.0',
    this.port = 8080,
    this.winthorProvider = 'mock',
    this.oracleConnectionString,
    this.oracleUser,
    this.oraclePassword,
  });

  final String host;
  final int port;

  /// `mock` (padrão) ou `oracle`.
  final String winthorProvider;

  /// Ex.: `localhost:1521/ORCL` — preenchido por quem conecta o ERP.
  final String? oracleConnectionString;
  final String? oracleUser;
  final String? oraclePassword;

  bool get usaOracle => winthorProvider.toLowerCase() == 'oracle';

  factory ApiConfig.fromMap(Map<String, String> env) {
    return ApiConfig(
      host: env['SIL_API_HOST'] ?? '0.0.0.0',
      port: int.tryParse(env['SIL_API_PORT'] ?? '') ?? 8080,
      winthorProvider: env['SIL_WINTHOR_PROVIDER'] ?? 'mock',
      oracleConnectionString: env['SIL_ORACLE_CONN'],
      oracleUser: env['SIL_ORACLE_USER'],
      oraclePassword: env['SIL_ORACLE_PASSWORD'],
    );
  }
}
