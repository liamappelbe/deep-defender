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

import 'bucketer.dart';
import 'chunker.dart';
import 'const.dart';
import 'hasher.dart';
import 'util.dart';

/// Chains together Chunker -> Bucketer -> Hasher, for use in the app, and for
/// integration testing.
class Pipeline {
  late final Chunker _chunker;
  late final Bucketer _bucketer;
  late final Hasher _hasher;

  final int sampleRate;
  final int chunkSize;
  final int chunkStride;
  final int samplesPerHash;
  final int hashStride;
  final int bitsPerHash;

  Float64List? _buffer;

  Pipeline(
    Function(int, Uint64List) reportHashes, {
    required this.sampleRate,
    required this.chunkSize,
    required this.chunkStride,
    required this.samplesPerHash,
    required this.hashStride,
    required this.bitsPerHash,
  }) {
    _hasher = Hasher(bitsPerHash, kHashesPerChunk, reportHashes);
    _bucketer = Bucketer(chunkSize, samplesPerHash, hashStride, bitsPerHash + 1,
        _hasher.onData, _hasher.endChunk);
    _chunker = Chunker(sampleRate, chunkSize, chunkStride, _bucketer.onData);
  }

  void onData(int timeMs, Uint16List data) {
    if ((_buffer?.length ?? 0) < data.length) {
      _buffer = Float64List(2 * data.length);
    }
    final buffer = Float64List.view(_buffer!.buffer, data.length);
    u16ToF64(data, buffer);
    onDataF64(timeMs, buffer);
  }

  void onDataF64(int timeMs, Float64List data) => _chunker.onData(timeMs, data);

  void flush(int timeMs) => _chunker.flush(timeMs);
}
