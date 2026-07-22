import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sil_api/sil_api.dart';

Future<void> main(List<String> args) async {
  final config = ApiConfig.fromMap(Platform.environment);
  final api = SilApi(config: config);

  final server = await shelf_io.serve(
    api.handler,
    config.host,
    config.port,
  );

  // ignore: avoid_print
  print(
    'S.I.L. API em http://${server.address.host}:${server.port} '
    '(winthor=${api.winthor.providerName})',
  );
}
