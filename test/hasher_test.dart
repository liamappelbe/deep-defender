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

import "dart:typed_data";
import "package:test/test.dart";
import "package:deep_defender/hasher.dart";

main() {
  test("Hasher", () {
    final hasher = Hasher(8, 4, (timeMs, chunk, hashes) {
      expect(timeMs, 1234);
      expect(hashes.length, 36);
      expect(hashes[0], 0xFF);
      expect(hashes[1], 0xFF);
      expect(hashes[2], 0xFF);
      expect(hashes[3], 0x7F);
      expect(Uint64List.sublistView(hashes, 4), [0xAD, 0x52, 0x4E, 0xB1]);
    });
    hasher.onData(Float64List.fromList([0, 4, 1.5, 14, 100, 1, 93, 91, 28]));
    hasher.onData(Float64List.fromList([1, 10, 2.5, 64, 200, 2, 235, 12, 23]));
    hasher.onData(Float64List.fromList([0, 3, 3.5, 24, 150, 3, 34, 4, 12]));
    hasher.onData(Float64List.fromList([1, 0, 4.5, 74, 250, 4, 2, 6354, 24]));
    hasher.onData(Float64List.fromList([0, 2, 5.5, 1, 0, 5, 341, 23, 523]));
    hasher.endChunk(1234, Float64List.fromList([0.5]));
  });
}
