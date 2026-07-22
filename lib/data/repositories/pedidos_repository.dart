import '../../config/api_config.dart';
import '../api/sil_api_client.dart';
import '../local/pedido_store.dart';
import '../mock_data.dart';
import '../../models/pedido.dart';

class PedidosRepository {
  const PedidosRepository({this.api});

  final SilApiClient? api;

  Future<List<Pedido>> listar({int? codfilial}) async {
    if (ApiConfig.useMock || api == null) {
      return _listarMock();
    }
    return api!.listarPedidos(codfilial: codfilial);
  }

  Future<List<Pedido>> _listarMock() async {
    final pedidos = [...pedidosMock];
    pedidos.sort((a, b) {
      final prioridade = transportadora(
        a.codFornecFrete,
      ).prioridade.compareTo(transportadora(b.codFornecFrete).prioridade);
      return prioridade != 0 ? prioridade : a.data.compareTo(b.data);
    });
    return pedidos;
  }

  /// Reserva atômica na API seguido pelo download para SQLite.
  Future<Pedido> iniciar(Pedido pedido, String comanda) async {
    final Pedido reservado;
    if (ApiConfig.useMock || api == null) {
      reservado = pedido.copyWith(numComanda: comanda);
    } else {
      reservado = await api!.reservarPedido(pedido.id, comanda);
    }
    await PedidoStore.instance.salvar(reservado);
    return reservado;
  }

  /// Na API real: UPDATE PCPEDC SET DTFINALSEP1 = SYSDATE (via backend).
  Future<void> finalizar(Pedido pedido) async {
    if (!ApiConfig.useMock && api != null) {
      await api!.finalizarPedido(pedido.id);
    }
    await PedidoStore.instance.remover(pedido.id);
  }
}
