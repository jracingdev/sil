import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api/api_exception.dart';
import '../data/local/pedido_store.dart';
import '../data/repositories/pedidos_repository.dart';
import '../models/pedido.dart';
import '../services/beep_service.dart';
import '../services/connectivity_service.dart';
import '../services/device_scanner_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'barcode_scanner_screen.dart';

class SeparacaoScreen extends StatefulWidget {
  const SeparacaoScreen({super.key, required this.pedido});
  final Pedido pedido;
  @override
  State<SeparacaoScreen> createState() => _SeparacaoScreenState();
}

class _SeparacaoScreenState extends State<SeparacaoScreen> {
  final endereco = TextEditingController(), produto = TextEditingController();
  final enderecoFocus = FocusNode(), produtoFocus = FocusNode();
  String? enderecoAberto;
  String? aviso;
  Map<String, int> separados = {};
  bool _nativeScanner = false;
  @override
  void initState() {
    super.initState();
    _carregar();
    _detectarScanner();
  }

  Future<void> _detectarScanner() async {
    final nativeScanner = await DeviceScannerService.instance.hasNativeScanner;
    if (mounted) setState(() => _nativeScanner = nativeScanner);
  }

  Future<void> _carregar() async {
    final valores = await PedidoStore.instance.carregarSeparacao(
      widget.pedido.id,
    );
    if (!mounted) return;
    setState(() => separados = Map.of(valores));
  }

  @override
  void dispose() {
    endereco.dispose();
    produto.dispose();
    enderecoFocus.dispose();
    produtoFocus.dispose();
    super.dispose();
  }

  Future<void> abrirEndereco() async {
    final chave = endereco.text.trim();
    if (widget.pedido.itens.any((item) => item.enderecoKey == chave)) {
      setState(() {
        enderecoAberto = chave;
        aviso = null;
        endereco.clear();
      });
      await BeepService.instance.enderecoOk();
      produtoFocus.requestFocus();
    } else {
      setState(() => aviso = 'Endereço não encontrado no pedido');
      await BeepService.instance.erro();
      enderecoFocus.requestFocus();
    }
  }

  Future<void> bipar() async {
    final codigo = produto.text.trim();
    if (codigo.isEmpty) return;
    final item =
        widget.pedido.itens
            .where((i) => i.enderecoKey == enderecoAberto)
            .cast<ItemPedido?>()
            .firstWhere((i) => i!.codauxiliar == codigo, orElse: () => null) ??
        widget.pedido.itens
            .where((i) => i.enderecoKey == enderecoAberto)
            .cast<ItemPedido?>()
            .firstWhere((i) => i!.codfab == codigo, orElse: () => null);
    produto.clear();
    if (item == null) {
      setState(() => aviso = 'Produto não encontrado no pedido');
      await BeepService.instance.erro();
      return;
    }
    final atual = separados[item.codauxiliar] ?? 0;
    if (atual >= item.qtd) {
      setState(() => aviso = 'Quantidade solicitada já atingida');
      await BeepService.instance.erro();
      return;
    }
    final novo = {...separados, item.codauxiliar: atual + 1};
    setState(() {
      separados = novo;
      aviso = null;
    });
    await PedidoStore.instance.salvarSeparacao(widget.pedido.id, novo);
    await BeepService.instance.produtoOk();
    produtoFocus.requestFocus();
  }

  Future<void> _lerEndereco() => _lerCodigo(
    titulo: 'Ler endereço',
    controller: endereco,
    foco: enderecoFocus,
    processar: abrirEndereco,
  );

  Future<void> _lerProduto() => _lerCodigo(
    titulo: 'Ler código de barras',
    controller: produto,
    foco: produtoFocus,
    processar: bipar,
  );

  Future<void> _lerCodigo({
    required String titulo,
    required TextEditingController controller,
    required FocusNode foco,
    required Future<void> Function() processar,
  }) async {
    foco.requestFocus();
    if (_nativeScanner) {
      final disparado = await DeviceScannerService.instance.triggerLaser();
      if (!disparado && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível disparar o laser. Use a tecla física do coletor.',
            ),
          ),
        );
      }
      return;
    }

    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BarcodeScannerScreen(title: titulo)),
    );
    if (codigo == null || !mounted) return;
    controller.text = codigo;
    await processar();
  }

  Future<void> reiniciar() async {
    setState(() {
      separados = {};
      enderecoAberto = null;
      aviso = null;
    });
    await PedidoStore.instance.salvarSeparacao(widget.pedido.id, {});
  }

  Future<void> finalizar() async {
    if (!context.read<ConnectivityService>().online) {
      _avisoOffline();
      return;
    }
    final faltantes = widget.pedido.itens
        .where((i) => (separados[i.codauxiliar] ?? 0) < i.qtd)
        .toList();
    if (faltantes.isNotEmpty) {
      final confirmar = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .55,
            minChildSize: .3,
            maxChildSize: .9,
            builder: (_, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Itens abaixo da quantidade pedida',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...faltantes.map(
                  (i) => Text(
                    '${i.desc}: ${separados[i.codauxiliar] ?? 0}/${i.qtd}',
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Finalizar assim mesmo',
                  onPressed: () => Navigator.pop(context, true),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('VOLTAR E CONTINUAR'),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmar != true) return;
    }
    if (!mounted) return;
    final repo = context.read<PedidosRepository>();
    try {
      await repo.finalizar(widget.pedido);
      await BeepService.instance.separacaoConcluida();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _avisoOffline() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Sem conexão'),
      content: const Text(
        'Desloque-se até um ponto com sinal antes de finalizar. Os dados bipados continuam salvos localmente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ENTENDI'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final total = widget.pedido.itens.fold(0, (a, i) => a + i.qtd);
    final feito = separados.values.fold(0, (a, i) => a + i);
    final parts = enderecoAberto?.split('-') ?? const [];
    return Scaffold(
      appBar: TopBar(
        title: 'Pedido: ${widget.pedido.id}',
        subtitle: 'Cliente: ${widget.pedido.cliente}',
        back: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: total == 0 ? 0 : feito / total,
                  color: feito == total ? AppColors.success : AppColors.accent,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endereco,
                  focusNode: enderecoFocus,
                  onSubmitted: (_) => abrirEndereco(),
                  decoration: InputDecoration(
                    labelText: 'Bipar endereço (M-R-P-A)',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: IconButton(
                      tooltip: _nativeScanner
                          ? 'Disparar laser'
                          : 'Ler pela câmera',
                      icon: Icon(
                        _nativeScanner
                            ? Icons.document_scanner_outlined
                            : Icons.camera_alt_outlined,
                      ),
                      onPressed: _lerEndereco,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.all(7),
                        color: AppColors.panelAlt,
                        child: Column(
                          children: [
                            Text(
                              ['M', 'R', 'P', 'A'][i],
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                            Text(
                              parts.length == 4 ? parts[i] : '—',
                              style: AppTheme.monoBold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  enabled: enderecoAberto != null,
                  controller: produto,
                  focusNode: produtoFocus,
                  onSubmitted: (_) => bipar(),
                  decoration: InputDecoration(
                    labelText: 'Bipar código de barras',
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    suffixIcon: IconButton(
                      tooltip: _nativeScanner
                          ? 'Disparar laser'
                          : 'Ler pela câmera',
                      icon: Icon(
                        _nativeScanner
                            ? Icons.document_scanner_outlined
                            : Icons.camera_alt_outlined,
                      ),
                      onPressed: enderecoAberto == null ? null : _lerProduto,
                    ),
                  ),
                ),
                if (aviso != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      aviso!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 35,
                  child: Text('M/R/P/A', style: TextStyle(fontSize: 10)),
                ),
                Expanded(
                  child: Text('DESCRIÇÃO', style: TextStyle(fontSize: 10)),
                ),
                Text('QT  SEP', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.pedido.itens.length,
              itemBuilder: (_, index) {
                final item = widget.pedido.itens[index];
                final qtd = separados[item.codauxiliar] ?? 0;
                final concluido = qtd >= item.qtd;
                final aberto = item.enderecoKey == enderecoAberto;
                final color = concluido
                    ? AppColors.successSoft
                    : aberto && qtd > 0
                    ? AppColors.accentSoft
                    : aberto
                    ? Colors.white
                    : AppColors.blocked;
                return Card(
                  color: color,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      item.desc,
                      style: TextStyle(
                        color: aberto || concluido
                            ? AppColors.text
                            : AppColors.muted,
                      ),
                    ),
                    subtitle: Text(
                      item.enderecoKey,
                      style: AppTheme.mono.copyWith(fontSize: 11),
                    ),
                    trailing: Text(
                      '${item.qtd}  $qtd',
                      style: AppTheme.monoBold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cinza: bloqueado • Branco: liberado • Laranja: em coleta • Verde: concluído',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: reiniciar,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('REINICIAR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Finalizar',
                    onPressed: finalizar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
