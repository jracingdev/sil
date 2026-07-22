class ItemPedido {
  const ItemPedido({
    required this.codauxiliar,
    required this.codfab,
    required this.desc,
    required this.m,
    required this.r,
    required this.p,
    required this.a,
    required this.qtd,
  });

  final String codauxiliar;
  final String codfab;
  final String desc;
  final String m;
  final String r;
  final String p;
  final String a;
  final int qtd;

  String get enderecoKey => '$m-$r-$p-$a';

  Map<String, Object?> toMap() => {
    'codauxiliar': codauxiliar,
    'codfab': codfab,
    'desc': desc,
    'm': m,
    'r': r,
    'p': p,
    'a': a,
    'qtd': qtd,
  };

  factory ItemPedido.fromMap(Map<String, Object?> map) => ItemPedido(
    codauxiliar: map['codauxiliar']! as String,
    codfab: map['codfab']! as String,
    desc: map['desc']! as String,
    m: map['m']! as String,
    r: map['r']! as String,
    p: map['p']! as String,
    a: map['a']! as String,
    qtd: map['qtd']! as int,
  );
}

class Pedido {
  const Pedido({
    required this.id,
    required this.data,
    required this.codFornecFrete,
    required this.cliente,
    required this.itens,
    this.numComanda,
  });

  final String id;
  final String data;
  final int codFornecFrete;
  final String cliente;
  final List<ItemPedido> itens;
  final String? numComanda;

  Pedido copyWith({String? numComanda}) => Pedido(
    id: id,
    data: data,
    codFornecFrete: codFornecFrete,
    cliente: cliente,
    itens: itens,
    numComanda: numComanda ?? this.numComanda,
  );

  String get dataFormatada {
    final parts = data.split('-');
    if (parts.length != 3) return data;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

class TransportadoraInfo {
  const TransportadoraInfo({required this.prioridade, required this.nome});
  final int prioridade;
  final String nome;
}
