import 'dart:io';

import 'package:flutter/services.dart';

/// Aciona o leitor físico quando o Android informa que é um coletor industrial.
///
/// A leitura por keyboard wedge permanece independente deste serviço: o código
/// continua chegando normalmente ao TextField que estiver com foco.
class DeviceScannerService {
  DeviceScannerService._();

  static final instance = DeviceScannerService._();
  static const _channel = MethodChannel('br.com.rhm.rhm_coletor/scanner');

  Future<bool> get hasNativeScanner async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasNativeScanner') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Retorna `true` quando o comando de disparo foi enviado ao coletor.
  Future<bool> triggerLaser() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('triggerLaser') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
