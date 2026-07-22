import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api/api_exception.dart';
import '../data/mock_data.dart';
import '../data/repositories/pedidos_repository.dart';
import '../models/pedido.dart';
import '../services/connectivity_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});
  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  Pedido? selecionado;
  Future<List<Pedido>>? pedidos;
  bool _carregou = false;

  PedidosRepository get repo => context.read<PedidosRepository>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_carregou) return;
    _carregou = true;
    final codfilial = context.read<SessionService>().operador?.codfilial;
    pedidos = repo.listar(codfilial: codfilial);
  }

  Future<void> _recarregar() async {
    final codfilial = context.read<SessionService>().operador?.codfilial;
    setState(() {
      selecionado = null;
      pedidos = repo.listar(codfilial: codfilial);
    });
  }

  Future<void> iniciar() async {
    if (selecionado == null) return;
    if (!context.read<ConnectivityService>().online) {
      _mensagem('É necessária conexão para reservar e baixar o pedido.');
      return;
    }
    final comanda = await showDialog<String>(
      context: context,
      builder: (_) => _ComandaDialog(pedido: selecionado!),
    );
    if (comanda == null || !mounted) return;
    try {
      final pedido = await repo.iniciar(selecionado!, comanda);
      if (!mounted) return;
      await Navigator.pushNamed(context, '/separacao', arguments: pedido);
      if (mounted) await _recarregar();
    } on ApiException catch (e) {
      if (mounted) _mensagem(e.message);
    }
  }

  void _mensagem(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const TopBar(title: 'Pedidos a separar', back: true),
    body: FutureBuilder<List<Pedido>>(
      future: pedidos,
      builder: (context, snapshot) {
        if (pedidos == null ||
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final erro = snapshot.error is ApiException
              ? (snapshot.error! as ApiException).message
              : '${snapshot.error}';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(erro, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }
        final lista = snapshot.data ?? const <Pedido>[];
        if (lista.isEmpty) {
          return const Center(child: Text('Nenhum pedido pendente.'));
        }
        return RefreshIndicator(
          onRefresh: _recarregar,
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final pedido = lista[index];
              final ativo = selecionado?.id == pedido.id;
              final frete = transportadora(pedido.codFornecFrete);
              return Card(
                color: ativo ? AppColors.accentSoft : null,
                child: ListTile(
                  onTap: () => setState(() => selecionado = pedido),
                  leading: Icon(
                    ativo
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: ativo ? AppColors.accentDark : AppColors.mutedLight,
                  ),
                  title: Text('Pedido: ${pedido.id}', style: AppTheme.monoBold),
                  subtitle: Text(
                    'Transport: ${frete.nome}\nData: ${pedido.dataFormatada}\nCliente: ${pedido.cliente}',
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: PrimaryButton(
        label: 'Iniciar separação',
        onPressed: selecionado == null ? null : iniciar,
      ),
    ),
  );
}

class _ComandaDialog extends StatefulWidget {
  const _ComandaDialog({required this.pedido});
  final Pedido pedido;
  @override
  State<_ComandaDialog> createState() => _ComandaDialogState();
}

class _ComandaDialogState extends State<_ComandaDialog> {
  final campo = TextEditingController();
  String? erro;
  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Pedido ${widget.pedido.id}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.pedido.cliente),
          const SizedBox(height: 16),
          TextField(
            controller: campo,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Número da comanda'),
          ),
          if (erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                erro!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCELAR'),
      ),
      FilledButton(
        onPressed: () {
          if (campo.text.trim().isEmpty) {
            setState(() => erro = 'Número da comanda é obrigatório');
          } else {
            Navigator.pop(context, campo.text.trim());
          }
        },
        child: const Text('OK'),
      ),
    ],
  );
}
