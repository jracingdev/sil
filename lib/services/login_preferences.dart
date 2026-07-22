import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências de login: lembrar usuário + credenciais protegidas para biometria.
class LoginPreferences {
  LoginPreferences._();
  static final instance = LoginPreferences._();

  static const _kLembrar = 'login_lembrar';
  static const _kUsuario = 'login_usuario';
  static const _kBiometria = 'login_biometria';
  static const _kSenha = 'login_senha';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> get lembrar async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLembrar) ?? false;
  }

  Future<String?> get usuarioSalvo async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kLembrar) ?? false)) return null;
    return prefs.getString(_kUsuario);
  }

  Future<bool> get biometriaAtiva async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometria) ?? false;
  }

  Future<bool> get biometriaDisponivel async {
    try {
      final suporte = await _localAuth.isDeviceSupported();
      final pode = await _localAuth.canCheckBiometrics;
      if (!suporte && !pode) return false;
      final tipos = await _localAuth.getAvailableBiometrics();
      return tipos.isNotEmpty || suporte;
    } catch (_) {
      return false;
    }
  }

  Future<void> salvarAposLogin({
    required String usuario,
    required String senha,
    required bool lembrar,
    required bool ativarBiometria,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final user = usuario.trim().toUpperCase();

    await prefs.setBool(_kLembrar, lembrar);
    if (lembrar) {
      await prefs.setString(_kUsuario, user);
    } else {
      await prefs.remove(_kUsuario);
      await prefs.setBool(_kBiometria, false);
      await _secure.delete(key: _kSenha);
      await _secure.delete(key: _kUsuario);
      return;
    }

    if (ativarBiometria) {
      await prefs.setBool(_kBiometria, true);
      await _secure.write(key: _kUsuario, value: user);
      await _secure.write(key: _kSenha, value: senha);
    } else {
      await prefs.setBool(_kBiometria, false);
      await _secure.delete(key: _kSenha);
      await _secure.delete(key: _kUsuario);
    }
  }

  Future<({String usuario, String senha})?> autenticarComBiometria() async {
    final ativa = await biometriaAtiva;
    if (!ativa) return null;

    final ok = await _localAuth.authenticate(
      localizedReason: 'Confirme a biometria para entrar no S.I.L.',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );
    if (!ok) return null;

    final usuario = await _secure.read(key: _kUsuario);
    final senha = await _secure.read(key: _kSenha);
    if (usuario == null || senha == null) return null;
    return (usuario: usuario, senha: senha);
  }
}
