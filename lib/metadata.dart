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

import 'microphone.dart';
import 'const.dart';

// Generates SAF code metadata.
class Metadata {
  static const int kSize = kMagicString.length + 2 + 2 + 8;

  int size() {
    return kSize;
  }

  void fill(int timeMs, ByteData metadata) {
    // [magic string] [version (2)] [algorithm (2)] [time (8)]
    for (int i = 0; i < kMagicString.length; ++i) {
      metadata.setUint8(i, kMagicString.codeUnitAt(i));
    }

    metadata.setUint16(kMagicString.length, kVersion, Endian.big);
    metadata.setUint16(kMagicString.length + 2, kAlgorithmId, Endian.big);
    metadata.setUint64(kMagicString.length + 4, timeMs, Endian.big);
  }
}
