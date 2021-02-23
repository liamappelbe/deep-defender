// Copyright 2021 The Deep Defender Authors

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     https://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:typed_data';
import 'package:crypto_keys/crypto_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:qr/qr.dart';
import 'audio_hasher.dart';
import 'byte_signer.dart';
import 'code_builder.dart';
import 'metadata.dart';
import 'microphone.dart';
import 'tf_embedder.dart';

KeyPair generateRsa(Null) {
  //return KeyPair.generateRsa();
  return KeyPair.fromJwk({
  "kty": "oct",
  "k": "AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75" +
      "aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow"
  });
}

class Defender {
  final void Function(QrCode, String) _callback;
  final CodeBuilder _codeBuilder;
  Microphone _microphone;

  Defender._(this._callback, this._codeBuilder) {}

  static Future<PrivateKey> getPrivateKey() async {
    // TODO: Store the key pair. Build a UI to share the public key.
    final keyPair = await compute(generateRsa, null);
    return keyPair.privateKey;
  }

  void _updateCode(int timeMs, Float64List audio) {
    final qr = QrCode.fromUint8List(
                data: _codeBuilder.generate(timeMs, audio),
                errorCorrectLevel: QrErrorCorrectLevel.L,
              )..make();
    final dt = DateTime.now().millisecondsSinceEpoch - timeMs;
    final cpu = dt / 1e3 / Microphone.kRefreshTime - 1;
    final info = "Latency: ${dt}ms\nCPU: ${(100 * cpu).toStringAsFixed(2)}%";
    _callback(qr, info);
  }

  static Future<Defender> defend(void Function(QrCode, String) callback) async {
    final defender = Defender._(callback, CodeBuilder(
      Metadata(), TfEmbedder(), ByteSigner(await getPrivateKey())));
    defender._microphone = await Microphone.mic(defender._updateCode);
    return defender;
  }
}
