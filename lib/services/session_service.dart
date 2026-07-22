import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../data/api/api_exception.dart';
import '../data/api/sil_api_client.dart';
import '../data/mock_data.dart';
import '../models/operador.dart';

class SessionService extends ChangeNotifier {
  SessionService({this._api});

  final SilApiClient? _api;

  Operador? operador;

  SilApiClient get api {
    final client = _api;
    if (client == null) {
      throw StateError('SilApiClient não configurado no SessionService');
    }
    return client;
  }

  Future<String?> login(String usuario, String senha) async {
    if (ApiConfig.useMock || _api == null) {
      return _loginMock(usuario, senha);
    }
    try {
      final result = await api.login(usuario, senha);
      operador = result.operador;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  String? _loginMock(String usuario, String senha) {
    final registro = credenciaisMock[usuario.trim().toUpperCase()];
    if (registro == null || registro['senha'] != senha) {
      return 'Usuário ou senha incorretos';
    }
    if (registro['tipo'] != 'S') {
      return 'Login permitido apenas para separadores';
    }
    operador = autenticarMock(usuario, senha);
    notifyListeners();
    return null;
  }

  void logout() {
    // O token só existe em memória; nunca é gravado no dispositivo.
    _api?.clearSession();
    operador = null;
    notifyListeners();
  }
}
