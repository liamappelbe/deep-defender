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

// Receives a stream of timestamped audio data, in chunks of any size, and
// yields chunks of audio data of a fixed size, with adjusted timestamps. The
// output chunks may overlap, by setting the stride to be less than the size.
//
// As soon as the chunk callback is finished, the data buffer that was sent will
// be overwritten, so the callback should copy any data it needs.

import "dart:typed_data";

class Chunker {
  final double _sampleRateMs;
  final int _chunkSize;
  final int _chunkStride;
  final int _chunkKeep;
  final Float64List _chunk;
  int _i = 0;
  final void Function(int, Float64List) _callback;

  Chunker(int sampleRate, this._chunkSize, this._chunkStride, this._callback)
      : _sampleRateMs = 1e-3 * sampleRate,
        _chunkKeep = _chunkSize - _chunkStride,
        _chunk = Float64List(_chunkSize) {
    assert(_chunkStride > 0 && _chunkStride <= _chunkSize);
  }

  void onData(int timeMs, Float64List data) {
    for (int j = 0; j < data.length; ++j) {
      _chunk[_i] = data[j];
      ++_i;
      if (_i >= _chunkSize) {
        // timeMs is the timestamp of the end of data. So however far back from
        // the end we are (divided by the sample rate) is our adjustment.
        final adjustedTimeMs = timeMs - ((data.length - 1 - j) / _sampleRateMs);
        _callback(adjustedTimeMs.toInt(), _chunk);

        // Copy any data we're keeping from the previous chunk to the start of
        // the new chunk.
        for (int k = 0; k < _chunkKeep; ++k) {
          _chunk[k] = _chunk[_chunkStride + k];
        }
        _i = _chunkKeep;
      }
    }
  }

  void flush(int timeMs) {
    // Fill the rest of the buffer with 0s and send it to the callback.
    for (; _i < _chunkSize; ++_i) {
      _chunk[_i] = 0;
    }
    _callback(timeMs, _chunk);
    _i = 0;
  }
}
