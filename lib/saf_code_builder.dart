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

import 'crypto.dart';
import 'metadata.dart';

// Combines the audio fingerprint, signature, and metadata into a SAF code.
class SafCodeBuilder {
  final Signer _signer;
  final Metadata _metadata;
  bool init = false;
  late Uint8List _buf;
  late ByteData _bytes;
  SafCodeBuilder(this._metadata, this._signer) {}

  Uint8List generate(int timeMs, double volume, Uint8List fingerprint) {
    // [metadata] [audio fingerprint] [signature]
    // [        signable data       ] [signature]
    if (!init) {
      init = true;
      _buf = Uint8List(Metadata.length + fingerprint.length + Signer.length);
      _bytes = _buf.buffer.asByteData();
    }
    _metadata.fill(timeMs, volume, _bytes);
    for (int i = 0; i < fingerprint.length; ++i) {
      _bytes.setUint8(i + Metadata.length, fingerprint[i]);
    }
    final dataSize = Metadata.length + fingerprint.length;
    _signer.signInline(_buf, dataSize);
    return _buf;
  }
}
