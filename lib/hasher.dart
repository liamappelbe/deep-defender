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

import 'const.dart';
import 'util.dart';

// Receives a stream frequency buckets. Yields a stream of hashes.
//
// As soon as the chunk callback is finished, the hash buffer that was sent will
// be overwritten, so the callback should copy any data it needs.
class Hasher {
  // Fingerprint is [volume (4)][hash 0 (8)][hash 1 (8)]...[hash N (8)]
  // _fingerprint owns the entire fingerprint.
  // _volume is just the volume element.
  // _hashes is a view into _fingerprint that doesn't include the volume.
  final int _size;
  late final Uint8List _fingerprint;
  late final Uint32List _volume;
  late final Uint64List _hashes;

  final Float64List _prevPow_dF;
  final Function(int, Float64List, Uint8List) _reportFingerprint;

  static const kReset = -1;
  int _k = kReset;

  static bool debug = false;

  Hasher(int bitsPerHash, int hashesPerChunk, this._reportFingerprint)
      : _size = 8 * hashesPerChunk + 4,
        _prevPow_dF = Float64List(bitsPerHash) {
    // We want the _hashes array to be 8-byte aligned, even to the volume prefix
    // is 4 bytes. So allocate an array with an additional 4 byte prefix.
    final bufSize = _size + 4;
    final buf = Uint8List(bufSize);
    _fingerprint = Uint8List.sublistView(buf, 4, bufSize);
    _volume = Uint32List.sublistView(_fingerprint);
    _hashes = Uint64List.sublistView(_fingerprint, 4);
  }

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

  void endChunk(int timeMs, Float64List audio) {
    assert(_k == _hashes.length);
    _volume[0] = volToU32(rmsVolume(audio));
    _reportFingerprint(timeMs, audio, _fingerprint);
    _k = kReset;
  }

  static const int U32MAX = (1 << 32) - 1;
  static int volToU32(double volume) => (clamp(volume, 0, 1) * U32MAX).toInt();
  static double u32ToVol(int u32) => u32.toDouble() / U32MAX;
}
