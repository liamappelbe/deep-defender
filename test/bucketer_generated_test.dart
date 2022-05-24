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
import 'package:test/test.dart';
import 'package:deep_defender/bucketer.dart';
import 'test_util.dart';

main() {
  test('Bucketer', () {
    testBucketer(
      128,
      64,
      32,
      9,
      [
        0xa5eb, 0x2ca9, 0xafb2, 0x562, 0xd2e3, 0x6786, 0xb2fe, 0x164b, //
        0xcbb3, 0x2a56, 0x231a, 0x5791, 0x1d47, 0x3e1e, 0x62b0, 0x5f43, //
        0x687d, 0x257e, 0xd126, 0x85ba, 0x698, 0xd80d, 0x1416, 0xdfef, //
        0x780a, 0xb2b0, 0xbd3d, 0xaa8f, 0x408c, 0xe9b7, 0xdc44, 0x51e9, //
        0xd877, 0x6996, 0xf98c, 0x5058, 0xbf30, 0x10bd, 0x8236, 0x85ea, //
        0x2f56, 0x2d9b, 0x15b8, 0xbbfd, 0xe0b4, 0xd0d9, 0x3114, 0xc165, //
        0xe1c7, 0x6c54, 0xef52, 0xe5a5, 0x6606, 0x9d15, 0x3f52, 0x64c8, //
        0x22c, 0x662e, 0x2036, 0xffa, 0xc6ab, 0xfb0d, 0xd140, 0xe219, //
        0xef5f, 0x296, 0xe33b, 0xa0f5, 0x3273, 0xb08e, 0xd2d8, 0x579a, //
        0x39ea, 0x91da, 0x2152, 0xa8f5, 0xbbb5, 0xe242, 0x2072, 0xd015, //
        0xd52d, 0x4ea6, 0xa96a, 0xfba1, 0xd32d, 0xac80, 0xe285, 0x2cfd, //
        0x49a8, 0xf56c, 0xe4ca, 0x793, 0x5bf9, 0x4403, 0x1700, 0x2999, //
        0xc63c, 0xabe5, 0xea78, 0xa442, 0x28a8, 0x229d, 0xe8ef, 0xcac2, //
        0x7bc4, 0xc7d, 0x1f97, 0xbabf, 0x265e, 0x745c, 0x2bb, 0xc9a4, //
        0xf4a3, 0x70d9, 0x2b56, 0x546c, 0x381d, 0xaae4, 0x99ca, 0x3fe, //
        0x9e9f, 0x491b, 0x3e26, 0xf422, 0x3fb2, 0x3c08, 0x37fc, 0xdaf5,
      ],
      [
        [
          1.68972464, 5.91174195, 12.18866958, 22.44143344, //
          13.10573662, 7.97099176, 28.61170460, 37.92032786, //
          137.93759121,
        ],
        [
          10.10709548, 2.33415051, 0.47235310, 17.03636267, //
          63.93610397, 48.70752500, 23.04619547, 99.95151933, //
          62.33251518,
        ],
        [
          0.00608045, 8.81652507, 3.26082779, 8.56417450, //
          29.95480906, 46.10637922, 103.80201623, 89.10732013, //
          34.46369334,
        ],
      ],
    );
  });
}
