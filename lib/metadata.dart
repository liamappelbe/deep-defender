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

import 'const.dart';
import 'util.dart';

// Generates SAF code metadata.
class Metadata {
  static const int length = kMagicString.length + 1 + 1 + 8;

  void fill(int timeMs, ByteData metadata) {
    // [magic string] [version (1)] [algorithm (1)] [time (8)]
    // TODO: Use varints for the version and algorithm ID.
    for (int i = 0; i < kMagicString.length; ++i) {
      metadata.setUint8(i, kMagicString.codeUnitAt(i));
    }

    metadata.setUint8(kMagicString.length, kVersion);
    metadata.setUint8(kMagicString.length + 1, kAlgorithmId);
    metadata.setUint64(kMagicString.length + 2, timeMs, Endian.big);
  }
}
