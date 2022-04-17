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
  final a = Uint64List(steps);;
  for (int i = 1; i < steps; ++i)
    a[i - 1] = math.pow(end, i * 1.0 / steps).toInt();
  a[steps - 1] = end;
  return a;
}
