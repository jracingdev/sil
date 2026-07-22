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
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'S.I.L.',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 34),
            Text(
              'Login do operador',
              style: AppTheme.displayBold.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sistema Integrado Logístico',
              style: TextStyle(color: AppColors.muted),
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
              style: TextStyle(fontSize: 11, color: AppColors.mutedLight),
            ),
            const Spacer(),
            PrimaryButton(label: 'Entrar', onPressed: entrar),
          ],
        ),
      ),
    ),
  );
}
