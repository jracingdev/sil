import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class FilialScreen extends StatelessWidget {
  const FilialScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final operador = context.watch<SessionService>().operador;
    if (operador == null) return const SizedBox.shrink();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.verified_user_outlined,
                size: 48,
                color: AppColors.accentDark,
              ),
              const SizedBox(height: 18),
              const Text(
                'Você está logando como',
                style: TextStyle(color: AppColors.muted),
              ),
              Text(
                '${operador.matricula} - ${operador.nome}',
                textAlign: TextAlign.center,
                style: AppTheme.displayBold.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Filial ${operador.codfilial}',
                style: AppTheme.display.copyWith(fontSize: 19),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<SessionService>().logout();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (_) => false,
                        );
                      },
                      child: const Text('NÃO'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Sim',
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/menu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
