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
import 'audio_hasher.dart';
import 'byte_signer.dart';
import 'metadata.dart';

// Combines the audio hash, signature, and metadata into a SAF code.
class SafCodeBuilder {
  final AudioHasher _hasher;
  final ByteSigner _signer;
  final Metadata _metadata;
  final Uint8List _buf;
  SafCodeBuilder(this._metadata, this._hasher, this._signer) :
      _buf = Uint8List(_metadata.size() + _hasher.size() + _signer.size()) {}

  Uint8List generate(int timeMs, Float64List audio) {
    // [metadata] [audio hash] [signature]
    // [    signable data    ] [signature]
    _metadata.fill(timeMs, _hasher.algorithmId(), _buf);
    _hasher.fill(audio, Uint8List.sublistView(_buf, _metadata.size()));
    final dataSize = _metadata.size() + _hasher.size();
    _signer.fill(
        Uint8List.sublistView(_buf, 0, dataSize),
        Uint8List.sublistView(_buf, dataSize));
    return _buf;
  }
}
