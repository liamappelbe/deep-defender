import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  Future<Defender> _defender;
  _DefenderState() { _defender = Defender.defend(_updateQr); }

  void _updateQr(QrCode qr, String debugInfo) {
    setState(() {
      _qr = qr;
      _text = debugInfo;
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
