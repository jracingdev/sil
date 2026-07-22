import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/local/pedido_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PedidoStore.instance.init();
  runApp(const SilApp());
}
