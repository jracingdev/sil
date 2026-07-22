import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
import '../services/connectivity_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final operador = context.watch<SessionService>().operador!;
    return Scaffold(
      appBar: TopBar(
        title:
            '$empresaCodigo - ${operador.nomeGuerra} - Filial ${operador.codfilial}',
        subtitle: 'Operador: ${operador.matricula} - ${operador.nome}',
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Todos os módulos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: modulos.map((m) {
                    final permitido = operador.permissoes.contains(m.chave);
                    final ativo = permitido && m.implementado;
                    return ListTile(
                      leading: Icon(
                        ativo ? Icons.inventory_2_outlined : Icons.lock_outline,
                      ),
                      title: Text(m.nome),
                      subtitle: Text(
                        ativo
                            ? 'Liberado'
                            : m.implementado
                            ? 'Sem permissão'
                            : 'Em breve',
                      ),
                      enabled: ativo,
                      onTap: ativo
                          ? () {
                              Navigator.pop(context);
                              _abrir(context, m.chave);
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ),
              ListTile(
                leading: Icon(
                  context.watch<ConnectivityService>().online
                      ? Icons.wifi
                      : Icons.wifi_off,
                ),
                title: const Text('Alternar conexão (mock)'),
                onTap: () => context.read<ConnectivityService>().toggle(),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Módulos liberados',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            _ModuloCard(
              icon: Icons.inventory_2_outlined,
              texto: 'Separação de Pedido',
              onTap: () => _abrir(context, 'picking'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: OutlinedButton.icon(
          onPressed: () {
            context.read<SessionService>().logout();
            Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
          },
          icon: const Icon(Icons.logout),
          label: const Text('SAIR'),
        ),
      ),
    );
  }

  void _abrir(BuildContext context, String chave) => Navigator.pushNamed(
    context,
    chave == 'picking' ? '/pedidos' : '/conferencia',
  );
}

class _ModuloCard extends StatelessWidget {
  const _ModuloCard({
    required this.icon,
    required this.texto,
    required this.onTap,
  });
  final IconData icon;
  final String texto;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon, size: 32, color: AppColors.accentDark),
      title: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
