import '../models/models.dart';
import 'winthor_repository.dart';

/// Implementação em memória alinhada aos mocks do app Flutter.
class MockWinthorRepository implements WinthorRepository {
  MockWinthorRepository() {
    _pedidos.addAll(_seed);
  }

  @override
  String get providerName => 'mock';

  final Map<String, String> _reservas = {};
  final List<Pedido> _pedidos = [];

  static const _credenciais = <String, Map<String, String>>{
    'RSGUIMARAES': {
      'senha': '1234',
      'matricula': '12',
      'nome': 'Rodrigo Silva Guimarães',
      'tipo': 'S',
    },
    'JOAOSEP': {
      'senha': '1234',
      'matricula': '45',
      'nome': 'João Pereira',
      'tipo': 'S',
    },
    'MCOMPRAS': {
      'senha': '1234',
      'matricula': '77',
      'nome': 'Marcos Souza',
      'tipo': 'C',
    },
  };

  static const _prioridadeFrete = <int, int>{
    887: 0,
    1038: 1,
    313: 2,
    1093: 3,
  };

  @override
  Future<Operador?> autenticar(String usuario, String senha) async {
    final key = usuario.trim().toUpperCase();
    final dados = _credenciais[key];
    if (dados == null || dados['senha'] != senha) return null;
    if (dados['tipo'] != 'S') {
      throw WinthorForbiddenException(
        'Login permitido apenas para separadores',
      );
    }
    return Operador(
      matricula: dados['matricula']!,
      nome: dados['nome']!,
      nomeGuerra: key,
      codfilial: 1,
      permissoes: const ['picking'],
    );
  }

  @override
  Future<List<Pedido>> listarPedidos({required int codfilial}) async {
    final livres = _pedidos.where((p) => !_reservas.containsKey(p.id)).toList();
    livres.sort((a, b) {
      final pa = _prioridadeFrete[a.codFornecFrete] ?? 99;
      final pb = _prioridadeFrete[b.codFornecFrete] ?? 99;
      final byPrio = pa.compareTo(pb);
      return byPrio != 0 ? byPrio : a.data.compareTo(b.data);
    });
    return List.unmodifiable(livres);
  }

  @override
  Future<Pedido> reservarPedido({
    required String id,
    required String numComanda,
    required Operador operador,
  }) async {
    final index = _pedidos.indexWhere((p) => p.id == id);
    if (index < 0) {
      throw WinthorNotFoundException('Pedido $id não encontrado');
    }
    if (_reservas.containsKey(id)) {
      throw WinthorConflictException('Pedido $id já reservado');
    }
    _reservas[id] = operador.matricula;
    final reservado = _pedidos[index].copyWith(numComanda: numComanda);
    _pedidos[index] = reservado;
    return reservado;
  }

  @override
  Future<void> finalizarPedido({
    required String id,
    required Operador operador,
  }) async {
    final index = _pedidos.indexWhere((p) => p.id == id);
    if (index < 0) {
      throw WinthorNotFoundException('Pedido $id não encontrado');
    }
    _pedidos.removeAt(index);
    _reservas.remove(id);
  }
}

const _seed = <Pedido>[
  Pedido(
    id: '1324001',
    data: '2026-02-13',
    codFornecFrete: 887,
    cliente: 'José Pedro Oficina',
    itens: [
      ItemPedido(
        codauxiliar: '20953',
        codfab: '0441487F',
        desc: '0441487 - KIT DO AMORTECEDOR',
        m: '03',
        r: '03',
        p: '9',
        a: '308',
        qtd: 2,
      ),
      ItemPedido(
        codauxiliar: '32094',
        codfab: 'M8L206F',
        desc: 'M8L206 - COXIM',
        m: '03',
        r: '03',
        p: '10',
        a: '301',
        qtd: 3,
      ),
      ItemPedido(
        codauxiliar: '73374',
        codfab: 'LT90194F',
        desc: 'LT90194 - KIT AMORTECEDOR',
        m: '03',
        r: '03',
        p: '10',
        a: '322',
        qtd: 1,
      ),
    ],
  ),
  Pedido(
    id: '2100325',
    data: '2026-02-13',
    codFornecFrete: 1038,
    cliente: 'Dorika Auto Peças',
    itens: [
      ItemPedido(
        codauxiliar: '53333',
        codfab: 'K5T0412LD',
        desc: 'K5T0412 - BIELETA DIANTEIRA LD',
        m: '03',
        r: '04',
        p: '16',
        a: '301',
        qtd: 2,
      ),
      ItemPedido(
        codauxiliar: '53334',
        codfab: 'K5T0412LT',
        desc: 'K5T0412 - BIELETA DIANTEIRA LT',
        m: '03',
        r: '04',
        p: '17',
        a: '301',
        qtd: 2,
      ),
    ],
  ),
  Pedido(
    id: '2001200',
    data: '2026-02-12',
    codFornecFrete: 313,
    cliente: 'Auto Shopping das Peças',
    itens: [
      ItemPedido(
        codauxiliar: '76548',
        codfab: '30194F',
        desc: '30.194 - TENSIONADOR',
        m: '03',
        r: '12',
        p: '16',
        a: '201',
        qtd: 2,
      ),
      ItemPedido(
        codauxiliar: '47757',
        codfab: 'ARL1043F',
        desc: 'ARL1043 - FILTRO DE AR',
        m: '06',
        r: '01',
        p: '5',
        a: '108',
        qtd: 6,
      ),
    ],
  ),
  Pedido(
    id: '8895600',
    data: '2026-02-13',
    codFornecFrete: 313,
    cliente: 'JAP Auto Peças',
    itens: [
      ItemPedido(
        codauxiliar: '10348',
        codfab: 'TR6B10F',
        desc: 'TR6B-10 - VELA DE IGNIÇÃO',
        m: '06',
        r: '01',
        p: '5',
        a: '108',
        qtd: 4,
      ),
    ],
  ),
  Pedido(
    id: '3265880',
    data: '2026-02-12',
    codFornecFrete: 9999,
    cliente: 'Calçadão Auto Peças',
    itens: [
      ItemPedido(
        codauxiliar: '44758',
        codfab: '0462613F',
        desc: '0462613 - KIT DO AMORTECEDOR',
        m: '03',
        r: '03',
        p: '24',
        a: '301',
        qtd: 1,
      ),
    ],
  ),
];
