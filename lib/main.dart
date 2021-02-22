import 'dart:typed_data';
import 'package:crypto_keys/crypto_keys.dart' show PrivateKey, KeyPair;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr/qr.dart';
import 'audio_hasher.dart';
import 'byte_signer.dart';
import 'code_builder.dart';
import 'metadata.dart';
import 'microphone.dart';
import 'tf_embedder.dart';

AudioHasher getAudioHasher() {
  return TfEmbedder();
}

PrivateKey getPrivateKey() {
  // TODO: Generate and store a key pair. Build a UI to share the public key.
  var keyPair = new KeyPair.fromJwk({
  "kty": "oct",
  "k": "AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75" +
      "aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow"
  });
  return keyPair.privateKey;
}

void main() {
  runApp(DeepDefenderApp(CodeBuilder(
      Metadata(), getAudioHasher(), ByteSigner(getPrivateKey()))));
}

class DeepDefenderApp extends StatelessWidget {
  final CodeBuilder _codeBuilder;
  DeepDefenderApp(this._codeBuilder) {}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deep Defender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: RunningPage(title: 'Deep Defender', codeBuilder: _codeBuilder),
    );
  }
}

class RunningPage extends StatefulWidget {
  final String title;
  final CodeBuilder codeBuilder;
  RunningPage({Key key, this.title, this.codeBuilder}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState(codeBuilder);
}

class _MyHomePageState extends State<RunningPage> {
  final CodeBuilder _codeBuilder;
  Uint8List _code;
  String _info = "Waiting to hear from the microphone...";
  Future<Microphone> _microphone;
  _MyHomePageState(this._codeBuilder) {
    _microphone = Microphone.mic(_updateCode);
  }

  void _updateCode(int timeMs, Float64List audio) {
    setState(() {
      _code = _codeBuilder.generate(timeMs, audio);
      int dt = DateTime.now().millisecondsSinceEpoch - timeMs;
      double cpu = dt / 1e3 / Microphone.kRefreshTime - 1;
      _info = "Latency: ${dt}ms\nCPU: ${(100 * cpu).toStringAsFixed(2)}%";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            if (_code != null) QrImage.withQr(
              qr: QrCode.fromUint8List(
                data: _code,
                errorCorrectLevel: QrErrorCorrectLevel.L,
              )..make(),
            ),
            Text(
              _info,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
