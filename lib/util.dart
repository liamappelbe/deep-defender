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

import 'dart:math' as math;
import 'dart:typed_data';

Uint64List logItr(int end, int steps) {
  final a = Uint64List(steps);
  for (int i = 1; i < steps; ++i) {
    a[i - 1] = math.pow(end, i * 1.0 / steps).toInt();
  }
  a[steps - 1] = end;
  return a;
}

// TODO: Test this.
void u16ToF64(Uint16List a, Float64List b) {
  assert(b.length == a.length);
  for (int i = 0; i < a.length; ++i) {
    b[i] = (a[i].toDouble() * 2.0 / 0xFFFF) - 1.0;
  }
}

// TODO: Test this.
void f64ToU16(Float64List a, Uint16List b) {
  assert(b.length == a.length);
  final scale = 1 << 15;
  final limit = (1 << 16) - 1;
  for (int i = 0; i < a.length; ++i) {
    final x = ((a[i] + 1) * scale).floor();
    b[i] = x < 0 ? 0 : x > limit ? limit : x;
  }
}
