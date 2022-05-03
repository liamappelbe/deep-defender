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

import 'byte_signer.dart';
import 'metadata.dart';

// Combines the audio fingerprint, signature, and metadata into a SAF code.
class SafCodeBuilder {
  final ByteSigner _signer;
  final Metadata _metadata;
  Uint8List _buf;
  ByteData _bytes;
  SafCodeBuilder(this._metadata, this._signer) {}

  Uint8List generate(int timeMs, Uint8List fingerprint) {
    // [metadata] [audio fingerprint] [signature]
    // [        signable data       ] [signature]
    if (_buf == null) {
      _buf = Uint8List(_metadata.size() + fingerprint.length + _signer.size());
      _bytes = _buf.buffer.asByteData();
    }
    _metadata.fill(timeMs, _bytes);
    for (var i = 0; i < fingerprint.length; ++i) {
      _bytes.setUint8(i + _metadata.size(), fingerprint[i]);
    }
    final dataSize = _metadata.size() + fingerprint.length;
    _signer.fill(_bytes, dataSize);
    return _buf;
  }
}
