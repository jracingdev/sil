import 'item_pedido.dart';

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

  Map<String, Object?> toJson() => {
        'id': id,
        'data': data,
        'codFornecFrete': codFornecFrete,
        'cliente': cliente,
        'numComanda': numComanda,
        'itens': itens.map((e) => e.toJson()).toList(),
      };

  factory Pedido.fromJson(Map<String, Object?> json) => Pedido(
        id: json['id']! as String,
        data: json['data']! as String,
        codFornecFrete: json['codFornecFrete']! as int,
        cliente: json['cliente']! as String,
        numComanda: json['numComanda'] as String?,
        itens: (json['itens']! as List)
            .map((e) => ItemPedido.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
      );
}
