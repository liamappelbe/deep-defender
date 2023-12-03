// Copyright 2021 The Deep Defender Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";
import "package:qr_flutter/qr_flutter.dart";

import "defender.dart";
import "key_store.dart";

void main() {
  runApp(const DeepDefenderApp());
}

class DeepDefenderApp extends StatelessWidget {
  const DeepDefenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      title: "Deep Defender",
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DefenderPage(title: "Deep Defender"),
    );
  }
}

final KeyStore _keyStore = KeyStore();

class DefenderPage extends StatefulWidget {
  final String title;
  const DefenderPage({super.key, required this.title});

  @override
  State<DefenderPage> createState() => _DefenderState();
}

class _DefenderState extends State<DefenderPage> {
  QrCode? _qr;
  String _text = "Waiting to hear from the microphone...";
  _DefenderState() {
    Defender(_setQr, _keyStore.privateKey());
  }

  void _setQr(int timeMs, QrCode qr) {
    setState(() {
      _qr = qr;
      final dt = DateTime.now().millisecondsSinceEpoch - timeMs;
      //final cpu = dt / 1e3 / Microphone.kRefreshTime;
      _text = "Latency: ${dt}ms"; // \nCPU: ${(100 * cpu).toStringAsFixed(2)}%
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          PopupMenuButton<void Function()>(
            onSelected: (void Function() value) => value(),
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<void Function()>>[
              PopupMenuItem<void Function()>(
                value: _sharePublicKey,
                child: const Text("Share public key"),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            if (_qr != null)
              QrImageView.withQr(qr: _qr!)
            else
              const AspectRatio(aspectRatio: 1),
            Text(
              _text,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _sharePublicKey() {
    _keyStore.publicKeyAsJwk().then((jwk) => Share.share(jwk));
  }
}
