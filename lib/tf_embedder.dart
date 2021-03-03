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

import 'dart:typed_data';
import 'package:flutter/services.dart';

// Audio fingerprinting using an embedder network running in TensorFlow.
class TfEmbedder {
  static const int kEmbeddingSize = 32;
  static const int kSize = 3 * kEmbeddingSize;
  static const _channel =
      const MethodChannel('com.github.liamappelbe.deep_defender/embedder');

  final _temp = ByteData(4);

  int size() { return kSize; }

  void fillQuantizedUint24(ByteData b, int i, double x) {
    const int kMax = 0x1000000;
    final y = (x * kMax.toDouble()).toInt();
    _temp.setUint32(0, y < 0 ? 0 : y >= kMax ? kMax - 1 : y, Endian.big);
    assert(_temp.getUint8(0) == 0);
    for (var j = 0; j < 3; ++j) {
      b.setUint8(3 * i + j, _temp.getUint8(j + 1));
    }
  }

  Future<Uint8List> run(Uint8List input) async {
    final fingerprint = Uint8List(kSize);
    final bytes = fingerprint.buffer.asByteData();
    final Uint8List raw = await _channel.invokeMethod('runEmbedder', input);
    final o = raw.buffer.asFloat32List();
    assert(o.length == kEmbeddingSize);
    for (var i = 0; i < o.length; ++i) fillQuantizedUint24(bytes, i, o[i]);
    return fingerprint;
  }
}
