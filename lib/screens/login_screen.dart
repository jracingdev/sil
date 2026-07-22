import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';
import '../services/login_preferences.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usuario = TextEditingController();
  final senha = TextEditingController();
  String? erro;
  bool carregando = false;
  bool lembrar = false;
  bool usarBiometria = false;
  bool biometriaDisponivel = false;
  bool biometriaSalva = false;
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _carregarPreferencias();
  }

  Future<void> _carregarPreferencias() async {
    final prefs = LoginPreferences.instance;
    final lembrarSalvo = await prefs.lembrar;
    final usuarioSalvo = await prefs.usuarioSalvo;
    final bioOk = await prefs.biometriaDisponivel;
    final bioAtiva = await prefs.biometriaAtiva;

    if (!mounted) return;
    setState(() {
      lembrar = lembrarSalvo;
      usarBiometria = bioAtiva && bioOk;
      biometriaDisponivel = bioOk;
      biometriaSalva = bioAtiva;
      if (usuarioSalvo != null) usuario.text = usuarioSalvo;
      _pronto = true;
    });

    if (bioAtiva && bioOk) {
      // Aguarda um frame para a UI montar antes do prompt do sistema.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) entrarComBiometria();
      });
    }
  }

  Future<void> entrar() async {
    if (!context.read<ConnectivityService>().online) {
      setState(() => erro = 'É necessária conexão para entrar.');
      return;
    }
    setState(() {
      carregando = true;
      erro = null;
    });
    final user = usuario.text;
    final pass = senha.text;
    final resultado = await context.read<SessionService>().login(user, pass);
    if (!mounted) return;
    if (resultado != null) {
      setState(() {
        carregando = false;
        erro = resultado;
        senha.clear();
      });
      return;
    }

    await LoginPreferences.instance.salvarAposLogin(
      usuario: user,
      senha: pass,
      lembrar: lembrar,
      ativarBiometria: lembrar && usarBiometria && biometriaDisponivel,
    );

    if (!mounted) return;
    setState(() => carregando = false);
    Navigator.pushReplacementNamed(context, '/filial');
  }

  Future<void> entrarComBiometria() async {
    if (carregando) return;
    if (!context.read<ConnectivityService>().online) {
      setState(() => erro = 'É necessária conexão para entrar.');
      return;
    }
    setState(() {
      carregando = true;
      erro = null;
    });
    try {
      final cred = await LoginPreferences.instance.autenticarComBiometria();
      if (!mounted) return;
      if (cred == null) {
        setState(() {
          carregando = false;
          erro = 'Biometria cancelada ou não disponível.';
        });
        return;
      }
      usuario.text = cred.usuario;
      senha.text = cred.senha;
      final resultado = await context.read<SessionService>().login(
        cred.usuario,
        cred.senha,
      );
      if (!mounted) return;
      setState(() => carregando = false);
      if (resultado != null) {
        setState(() {
          erro = resultado;
          senha.clear();
        });
      } else {
        Navigator.pushReplacementNamed(context, '/filial');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        erro = e.message ?? 'Falha na biometria';
      });
    }
  }

  @override
  void dispose() {
    usuario.dispose();
    senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF102B4E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Text(
                'RHM separação de pedidos',
                style: AppTheme.display.copyWith(
                  color: Colors.white,
                  fontSize: 21,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/sil_logo.png',
                          height: 112,
                          fit: BoxFit.contain,
                          semanticLabel: 'S.I.L. Sistema Integrado de Logistica',
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Login do operador',
                        style: AppTheme.displayBold.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SISTEMA INTEGRADO DE LOGISTICA',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (erro != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            erro!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: usuario,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Usuário',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: senha,
                        obscureText: true,
                        onSubmitted: (_) => entrar(),
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Lembrar-me'),
                        value: lembrar,
                        onChanged: carregando
                            ? null
                            : (v) {
                                setState(() {
                                  lembrar = v ?? false;
                                  if (!lembrar) usarBiometria = false;
                                });
                              },
                      ),
                      if (biometriaDisponivel)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Usar biometria neste aparelho'),
                          subtitle: Text(
                            lembrar
                                ? 'Exige Lembrar-me ativo'
                                : 'Ative Lembrar-me para habilitar',
                            style: const TextStyle(fontSize: 11),
                          ),
                          value: usarBiometria && lembrar,
                          onChanged: carregando || !lembrar
                              ? null
                              : (v) => setState(() => usarBiometria = v ?? false),
                        ),
                      if (biometriaSalva && biometriaDisponivel) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: carregando ? null : entrarComBiometria,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Entrar com biometria'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Text(
                        'A filial é obtida do cadastro PCEMPR.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: PrimaryButton(
          label: carregando ? 'Entrando…' : 'Entrar',
          onPressed: carregando ? null : entrar,
        ),
      ),
    );
  }
}
