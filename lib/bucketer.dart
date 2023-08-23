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

// Receives a stream of timestamped audio data, in fixed sized chunks, runs
// STFT, and calculates power levels of coarser buckets of frequencies.
//
// reportPowers is called to report the power buckets of an STFT result. As soon
// as the reportPowers callback is finished, the hash buffer that was sent will
// be overwritten, so the callback should copy any data it needs. endChunk is
// called when all the buckets for a chunk have been reported, with the
// timestamp of the chunk.
class Bucketer {
  final STFT _stft;
  final int _stftStride;
  final Float64List _powers;
  final Uint64List _itr;
  final Function(Float64List) _reportPowers;
  final Function(int) _endChunk;

  Bucketer(int chunkSize, int stftSize, this._stftStride, int buckets,
      this._reportPowers, this._endChunk)
      : _stft = STFT(stftSize, Window.hanning(stftSize)),
        _powers = Float64List(buckets),
        _itr = logItr(1 + stftSize ~/ 2, buckets);

  // Note: The log iterator only goes up to stftSize/2 because the input signal
  // is real, so we only care about the first half of the spectrum, because it's
  // conjugate symmetric.

  void onData(int timeMs, Float64List chunk) {
    int j = 0;
    _stft.run(chunk, (Float64x2List freq) {
      int k = 0;
      final a = freq.discardConjugates();
      assert(a.length == _itr.last);
      for (int ki = 0; ki < _itr.length; ++ki) {
        int kk = _itr[ki];
        _powers[ki] = 0;
        for (; k < kk; ++k) {
          final z = a[k];
          _powers[ki] += z.x * z.x + z.y * z.y;
        }
      }
      _reportPowers(_powers);
    }, _stftStride);
    _endChunk(timeMs);
  }
}
