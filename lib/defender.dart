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

import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto_keys/crypto_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr/qr.dart';
import 'audio_hasher.dart';
import 'byte_signer.dart';
import 'metadata.dart';
import 'microphone.dart';
import 'saf_code_builder.dart';
import 'tf_embedder.dart';

// Connects a Microphone to a SafCodeBuilder running in a separate Isolate.
class Defender {
  final void Function(int, QrCode) _setQr;
  final void Function() _clearQr;
  final _recv = ReceivePort();
  Future<Microphone> _microphone;
  Future<Isolate> _isolate;
  SendPort _send;

  Defender(this._setQr, this._clearQr) {
    _recv.listen(_onMessage);
    _isolate = Isolate.spawn(defenderIsolateEntry, _recv.sendPort);
    _microphone = Microphone.mic(_updateCode);
  }

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      _send = message as SendPort;
    } else {
      final qrm = message as QrMessage;
      _setQr(qrm.timeMs, qrm.qr);
    }
  }

  void _updateCode(int timeMs, Float64List audio) {
    _clearQr();
    if (_send != null) _send.send(AudioMessage(timeMs, audio));
  }
}

void defenderIsolateEntry(SendPort port) {
  DefenderIsolate(port);
}

class AudioMessage {
  int timeMs;
  Float64List audio;
  AudioMessage(this.timeMs, this.audio);
}

class QrMessage {
  int timeMs;
  QrCode qr;
  QrMessage(this.timeMs, this.qr);
}

class DefenderIsolate {
  final SendPort _send;
  final _recv = ReceivePort();
  final SafCodeBuilder _codeBuilder;
  DefenderIsolate(this._send) : _codeBuilder = SafCodeBuilder(
      Metadata(), TfEmbedder(), ByteSigner(getPrivateKey())) {
    _recv.listen(_onMessage);
    _send.send(_recv.sendPort);
  }

  static PrivateKey getPrivateKey() {
    // TODO: Store the key pair. Build a UI to share the public key.
    final keyPair = KeyPair.generateRsa();
    return keyPair.privateKey;
  }

  void _onMessage(dynamic message) {
    final am = message as AudioMessage;
    final qr = QrCode.fromUint8List(
                data: _codeBuilder.generate(am.timeMs, am.audio),
                errorCorrectLevel: QrErrorCorrectLevel.L)..make();
    _send.send(QrMessage(am.timeMs, qr));
  }
}
