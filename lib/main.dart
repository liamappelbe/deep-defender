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

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'microphone.dart';
import 'defender.dart';

void main() {
  runApp(DeepDefenderApp());
}

class DeepDefenderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deep Defender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: DefenderPage(title: 'Deep Defender'),
    );
  }
}

class DefenderPage extends StatefulWidget {
  final String title;
  DefenderPage({Key key, this.title}) : super(key: key);

  @override
  _DefenderState createState() => _DefenderState();
}

class _DefenderState extends State<DefenderPage> {
  QrCode _qr;
  String _text = "Waiting to hear from the microphone...";
  Defender _defender;
  _DefenderState() {
    _defender = Defender(_setQr, _clearQr);
  }

  void _setQr(int timeMs, QrCode qr) {
    setState(() {
      _qr = qr;
      final dt = DateTime.now().millisecondsSinceEpoch - timeMs;
      final cpu = dt / 1e3 / Microphone.kRefreshTime - 1;
      _text = "Latency: ${dt}ms\nCPU: ${(100 * cpu).toStringAsFixed(2)}%";
    });
  }

  void _clearQr() {
    setState(() {
      _qr = null;
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
            if (_qr != null) QrImage.withQr(qr: _qr),
            Text(
              _text,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
