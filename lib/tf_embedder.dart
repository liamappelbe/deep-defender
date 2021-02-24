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

// AudioHasher implementation using an embedder network running in TensorFlow.
class TfEmbedder implements AudioHasher {
  static const int kEmbeddingSize = 32;
  static const int kSize = 3 * kEmbeddingSize;
  static const int kAlgorithmId = 0;

  @override
  int size() { return kSize; }

  @override
  int algorithmId() { return kAlgorithmId; }

  @override
  void fill(Float64List audio, Uint8List hash) {
    // TODO: Implement using tensorflow.
    hash.buffer.asFloat64List().setRange(0, kSize ~/ 8, audio);
  }
}
