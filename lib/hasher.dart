// Copyright 2022 The Deep Defender Authors
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

import 'package:fftea/fftea.dart';

import 'util.dart';

// Receives a stream frequency buckets. Yields a stream of hashes.
//
// As soon as the chunk callback is finished, the hash buffer that was sent will
// be overwritten, so the callback should copy any data it needs.
class Hasher {
  final Uint64List _hashes;
  final Float64List _prevPow_dF;
  final Function(int, Uint64List) _reportHashes;

  static const kReset = -1;
  int _k = kReset;

  Hasher(int bitsPerHash, int hashesPerChunk, this._reportHashes)
      : _hashes = Uint64List(hashesPerChunk),
        _prevPow_dF = Float64List(bitsPerHash);

  void onData(Float64List powers) {
    assert(powers.length == _prevPow_dF.length + 1);
    int h = 0;
    for (int i = 0; i < _prevPow_dF.length; ++i) {
      final pow_dF = powers[i + 1] - powers[i];
      if (_k >= 0) {
        if (pow_dF - _prevPow_dF[i] > 0) {
          h |= 1 << i;
        }
      }
      _prevPow_dF[i] = pow_dF;
    }
    if (_k >= 0) {
      _hashes[_k] = h;
    }
    ++_k;
  }

  void endChunk(int timeMs) {
    assert(_k == _hashes.length);
    _reportHashes(timeMs, _hashes);
    _k = kReset;
  }
}
