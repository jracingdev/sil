import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Leitor por câmera usado somente em celulares sem scanner industrial.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, required this.title});

  final String title;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _reading = false;

  void _onDetect(BarcodeCapture capture) {
    if (_reading) return;
    if (capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    _reading = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: MobileScanner(
      onDetect: _onDetect,
      errorBuilder: (_, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Não foi possível abrir a câmera.\n${error.errorCode.name}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
