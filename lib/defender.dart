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

import 'package:permission_handler/permission_handler.dart';
import 'package:qr/qr.dart';

import 'const.dart';
import 'crypto.dart';
import 'metadata.dart';
import 'microphone.dart';
import 'pipeline.dart';
import 'saf_code_builder.dart';

/// Connects a Microphone to a SafCodeBuilder etc running in a separate Isolate.
///
/// UI isolate:    Microphone                                       Show in UI
///                      \                                          /
///                   AudioMessage                              QrMessage
///                       \                                       /
/// Defender isolate:   Chunker -> Bucketer -> Hasher -> SafCodeBuilder
///                      `----- aka Pipeline ------'
class Defender {
  final void Function(int, QrCode) _setQr;
  final Future<PrivateKey> _privateKey;
  final _recv = ReceivePort();
  late final Future<Microphone?> _microphone;
  late final Future<Isolate> _isolate;
  SendPort? _send;

  Defender(this._setQr, this._privateKey) {
    _recv.listen(_onMessage);
    _isolate = Isolate.spawn(defenderIsolateMain, _recv.sendPort);
    _microphone = Microphone.mic(_updateCode);
  }

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      _send = message as SendPort;
      _privateKey.then((pk) => _send?.send(pk));
    } else {
      final qrm = message as QrMessage;
      _setQr(qrm.timeMs, qrm.qr);
    }
  }

  void _updateCode(int timeMs, Uint16List audio) {
    _send?.send(AudioMessage(timeMs, audio));
  }
}

void defenderIsolateMain(SendPort port) {
  DefenderIsolate(port);
}

class AudioMessage {
  int timeMs;
  Uint16List audio;
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
  late final Pipeline _pipeline;
  SafCodeBuilder? _codeBuilder;

  DefenderIsolate(this._send) {
    _pipeline = Pipeline(
      _onHashes,
      sampleRate: kSampleRate,
      chunkSize: kChunkSize,
      chunkStride: kChunkStride,
      samplesPerHash: kSamplesPerHash,
      hashStride: kHashStride,
      bitsPerHash: kBitsPerHash,
    );
    _recv.listen(_onMessage);
    _send.send(_recv.sendPort);
  }

  void _onMessage(dynamic message) {
    if (message is PrivateKey) {
      _codeBuilder =
          SafCodeBuilder(Metadata(), (message as PrivateKey).signer());
    } else {
      final am = message as AudioMessage;
      _pipeline.onData(am.timeMs, am.audio);
    }
  }

  void _onHashes(int timeMs, Uint64List hashes) {
    if (_codeBuilder == null) return;
    final data = _codeBuilder!.generate(timeMs, hashes.buffer.asUint8List());
    final qr = QrCode.fromUint8List(
        data: data, errorCorrectLevel: QrErrorCorrectLevel.L);
    _send.send(QrMessage(timeMs, qr));
  }
}
