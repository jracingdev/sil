import '../local/pedido_store.dart';
import '../mock_data.dart';
import '../../models/pedido.dart';

class PedidosRepository {
  const PedidosRepository();

  Future<List<Pedido>> listar() async {
    final pedidos = [...pedidosMock];
    pedidos.sort((a, b) {
      final prioridade = transportadora(
        a.codFornecFrete,
      ).prioridade.compareTo(transportadora(b.codFornecFrete).prioridade);
      return prioridade != 0 ? prioridade : a.data.compareTo(b.data);
    });
    return pedidos;
  }

  /// Mock da reserva atômica na API seguido pelo download para SQLite.
  Future<Pedido> iniciar(Pedido pedido, String comanda) async {
    final reservado = pedido.copyWith(numComanda: comanda);
    await PedidoStore.instance.salvar(reservado);
    return reservado;
  }

  /// Na API real este método executará UPDATE PCPEDC SET DTFINALSEP1 = SYSDATE.
  Future<void> finalizar(Pedido pedido) =>
      PedidoStore.instance.remover(pedido.id);
}
