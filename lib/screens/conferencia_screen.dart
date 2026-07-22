import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';

/// Scaffold do módulo implementado no protótipo, pronto para receber API/SQLite.
class ConferenciaScreen extends StatelessWidget {
  const ConferenciaScreen({super.key});
  static const bonus = [
    (
      'BNS-4021',
      'NF-e 000.145.902',
      'Distribuidora Central de Autopeças',
      4,
      true,
    ),
    ('BNS-4022', 'NF-e 000.145.918', 'Vela & Filtros Ltda', 3, false),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const TopBar(title: 'Bônus de conferência', back: true),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bonus.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final b = bonus[index];
        return Card(
          child: ListTile(
            leading: const Icon(
              Icons.local_shipping_outlined,
              color: AppColors.accentDark,
            ),
            title: Text(
              b.$1,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${b.$3}\n${b.$2} • ${b.$4} volumes'),
            isThreeLine: true,
            trailing: StatusBadge(
              b.$5 ? 'Com romaneio' : 'Apuração total',
              color: b.$5 ? AppColors.success : AppColors.muted,
            ),
          ),
        );
      },
    ),
  );
}
