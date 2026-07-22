import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Beeps curtos para feedback de bipagem no coletor.
class BeepService {
  BeepService._();
  static final instance = BeepService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> enderecoOk() => _play('sounds/beep_endereco.wav');

  Future<void> produtoOk() => _play('sounds/beep_scan.wav');

  /// Tom diferente (três notas) ao finalizar a separação com sucesso.
  Future<void> separacaoConcluida() => _play('sounds/beep_sucesso.wav');

  Future<void> erro() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
  }

  Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> dispose() => _player.dispose();
}
