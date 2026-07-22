import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/pedido.dart';

/// Persistência local do pedido já reservado: a bipagem não depende de rede.
class PedidoStore {
  PedidoStore._();
  static final instance = PedidoStore._();
  Database? _db;

  Future<void> init() async {
    final path = join(await getDatabasesPath(), 'sil_coletor.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE pedido_local (id TEXT PRIMARY KEY, payload TEXT NOT NULL, separacao TEXT NOT NULL)',
        );
      },
    );
  }

  Future<void> salvar(Pedido pedido) async {
    final db = _db!;
    await db.insert('pedido_local', {
      'id': pedido.id,
      'payload': jsonEncode({
        'id': pedido.id,
        'data': pedido.data,
        'frete': pedido.codFornecFrete,
        'cliente': pedido.cliente,
        'comanda': pedido.numComanda,
        'itens': pedido.itens.map((item) => item.toMap()).toList(),
      }),
      'separacao': '{}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, int>> carregarSeparacao(String pedidoId) async {
    final rows = await _db!.query(
      'pedido_local',
      columns: ['separacao'],
      where: 'id = ?',
      whereArgs: [pedidoId],
    );
    if (rows.isEmpty) return {};
    final json =
        jsonDecode(rows.single['separacao']! as String) as Map<String, dynamic>;
    return json.map((key, value) => MapEntry(key, value as int));
  }

  Future<void> salvarSeparacao(String pedidoId, Map<String, int> valores) =>
      _db!.update(
        'pedido_local',
        {'separacao': jsonEncode(valores)},
        where: 'id = ?',
        whereArgs: [pedidoId],
      );

  Future<void> remover(String pedidoId) =>
      _db!.delete('pedido_local', where: 'id = ?', whereArgs: [pedidoId]);
}
