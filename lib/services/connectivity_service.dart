import 'package:flutter/foundation.dart';

/// Alternância mock para demonstrar os pontos de bloqueio da operação online.
class ConnectivityService extends ChangeNotifier {
  bool _online = true;
  bool get online => _online;

  void toggle() {
    _online = !_online;
    notifyListeners();
  }
}
