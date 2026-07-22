import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_coletor/data/mock_data.dart';
import 'package:rhm_coletor/data/repositories/pedidos_repository.dart';

void main() {
  test('prioriza pedidos pela transportadora definida no manual', () async {
    final pedidos = await const PedidosRepository().listar();

    expect(pedidos.first.codFornecFrete, 887);
    expect(pedidos.last.codFornecFrete, 9999);
    expect(transportadora(9999).prioridade, 99);
  });
}
