import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/pedido.dart';
import 'screens/conferencia_screen.dart';
import 'screens/filial_screen.dart';
import 'screens/login_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/pedidos_screen.dart';
import 'screens/separacao_screen.dart';
import 'services/connectivity_service.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

class SilApp extends StatelessWidget {
  const SilApp({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SessionService()),
      ChangeNotifierProvider(create: (_) => ConnectivityService()),
    ],
    child: MaterialApp(
      title: 'S.I.L. — Sistema Integrado Logístico',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/filial': (_) => const FilialScreen(),
        '/menu': (_) => const MenuScreen(),
        '/pedidos': (_) => const PedidosScreen(),
        '/conferencia': (_) => const ConferenciaScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/separacao' && settings.arguments is Pedido) {
          return MaterialPageRoute(
            builder: (_) =>
                SeparacaoScreen(pedido: settings.arguments! as Pedido),
          );
        }
        return null;
      },
    ),
  );
}
