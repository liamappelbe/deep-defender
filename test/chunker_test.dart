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
import 'package:deep_defender/chunker.dart';

Float64List makeList(int from, int to) {
  final a = <double>[];
  for (int i = from; i < to; ++i) {
    a.add(i.toDouble());
  }
  return Float64List.fromList(a);
}

main() {
  test('Chunker', () {
    // 0ms               30ms                60ms
    // [0  1  2  3  4  5  6  7]
    //                   [6  7  8  9  10  11  12  13]
    //                                       [12  13  ...
    var times = <int>[];
    var out = <Float64List>[];
    final c = Chunker(200, 8, 6, (int timeMs, Float64List data) {
      times.add(timeMs);
      out.add(Float64List.fromList(data));
    });

    c.onData(50, makeList(0, 10));
    expect(times, [40]);
    expect(out, [makeList(0, 8)]);

    times = [];
    out = [];
    c.onData(60, makeList(10, 12));
    expect(times, []);
    expect(out, []);

    times = [];
    out = [];
    c.onData(115, makeList(12, 23));
    expect(times, [70, 100]);
    expect(out, [makeList(6, 14), makeList(12, 20)]);

    times = [];
    out = [];
    c.flush(150);
    expect(times, [150]);
    expect(out, [
      [18, 19, 20, 21, 22, 0, 0, 0]
    ]);
  });
}
