import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/operador.dart';

class SessionService extends ChangeNotifier {
  Operador? operador;

  Future<String?> login(String usuario, String senha) async {
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
    operador = null;
    notifyListeners();
  }
}
