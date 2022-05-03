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

/// Chains together Chunker -> Bucketer -> Hasher, for use in the app, and for
/// integration testing.
class Pipeline {
  late final Chunker _chunker;
  late final Bucketer _bucketer;
  late final Hasher _hasher;

  Pipeline(Function(int, Uint64List) reportHashes) {
    _hasher = Hasher(kBitsPerHash, kHashesPerChunk, reportHashes);
    _bucketer = Bucketer(kChunkSize, kSamplesPerHash, kHashStride, kBitsPerHash + 1, _hasher.onData, _hasher.endChunk);
    _chunker = Chunker(kSampleRate, kChunkSize, kChunkStride, _bucketer.onData);
  }

  void onData(int timeMs, Uint16List data) => _chunker.onData(timeMs, data);
}
