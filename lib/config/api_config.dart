/// Configuração da API consumida pelo coletor.
class ApiConfig {
  const ApiConfig._();

  /// Base URL via `--dart-define=SIL_API_BASE_URL=http://IP:8080`.
  ///
  /// Padrões:
  /// - Android emulator: `http://10.0.2.2:8080` (host da máquina)
  /// - Override no run: `--dart-define=SIL_API_BASE_URL=http://192.168.x.x:8080`
  static const String baseUrl = String.fromEnvironment(
    'SIL_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Se true, SessionService/PedidosRepository usam mocks locais (útil em testes).
  static const bool useMock = bool.fromEnvironment(
    'SIL_API_USE_MOCK',
    defaultValue: false,
  );
}
