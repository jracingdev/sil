import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';
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

  Future<void> entrar() async {
    if (!context.read<ConnectivityService>().online) {
      setState(() => erro = 'É necessária conexão para entrar.');
      return;
    }
    final resultado = await context.read<SessionService>().login(
      usuario.text,
      senha.text,
    );
    if (!mounted) return;
    if (resultado != null) {
      setState(() {
        erro = resultado;
        usuario.clear();
        senha.clear();
      });
    } else {
      Navigator.pushReplacementNamed(context, '/filial');
    }
  }

  @override
  void dispose() {
    usuario.dispose();
    senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
      child: PrimaryButton(label: 'Entrar', onPressed: entrar),
    ),
  );
}
