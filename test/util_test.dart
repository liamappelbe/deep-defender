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

import 'package:test/test.dart';
import 'package:deep_defender/util.dart';

main() {
  test('logItr', () {
    expect(logItr(100, 1), [100]);
    expect(logItr(100, 3), [4, 21, 100]);
    expect(logItr(100, 10), [1, 2, 3, 6, 10, 15, 25, 39, 63, 100]);
  });

  test('solve', () {
    double cube(double x) => x * x * x;
    expect(solve(cube, y: 0.5, dx: 1e-3), closeTo(0.7937, 1e-3));
    expect(solve(cube, y: 1000, dx: 1e-3), closeTo(10, 1e-3));
    expect(solve(cube, y: -1000, dx: 1e-3), closeTo(-10, 1e-3));
    double negcube(double x) => -x * x * x;
    expect(solve(negcube, y: 0.5, dx: 1e-3), closeTo(-0.7937, 1e-3));
    expect(solve(negcube, y: 1000, dx: 1e-3), closeTo(-10, 1e-3));
    expect(solve(negcube, y: -1000, dx: 1e-3), closeTo(10, 1e-3));
  });
}
