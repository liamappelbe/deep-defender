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

import 'const.dart';

// Returns x such that f(X) = y and abs(X - x) < dx
// That is, the solution of f(x) = y, to an accuracy of dx. Assumes f is:
//  - Monotonic
//  - Continuous
//  - Defined for all x
//  - Has some x where f(x) = y
double solve(double Function(double) f, {double y = 0, double dx = 1e-9}) {
  double x0 = 0;
  double x1 = 1;
  double y0 = f(x0);
  double y1 = f(x1);
  if (y0 >= y1) {
    final x2 = x0;
    x0 = x1;
    x1 = x2;
    final y2 = y0;
    y0 = y1;
    y1 = y2;
  }
  while (y0 >= y) {
    x0 = 2 * x0 - x1;
    y0 = f(x0);
  }
  while (y1 <= y) {
    x1 = 2 * x1 - x0;
    y1 = f(x1);
  }
  while ((x1 - x0).abs() >= dx) {
    final x2 = (x0 + x1) / 2;
    final y2 = f(x2);
    if (y2 > y) {
      x1 = x2;
      y1 = y2;
    } else {
      x0 = x2;
      y0 = y2;
    }
  }
  return (x0 + x1) / 2;
}

Uint64List logItr(int end, int steps) {
  final a = Uint64List(steps);
  for (int i = 1; i < steps; ++i) {
    a[i - 1] = math.pow(end, i * 1.0 / steps).toInt();
  }
  a[steps - 1] = end;
  return a;
}

Uint64List logLinItr(int end, int steps, {double grad0 = 1}) {
  double eqn(double w) => math.exp(w * steps) + (grad0 - w) * steps - 1;
  final w = solve(eqn, y: end.toDouble());
  final g = grad0 - w;
  final a = Uint64List(steps);
  for (int i = 1; i < steps; ++i) {
    a[i - 1] = (math.exp(w * i) + g * i - 1).toInt();
  }
  a[steps - 1] = end;
  return a;
}

double clamp(double x, double lo, double hi) => x < lo ? lo : x > hi ? hi : x;

void micDataToF64(MicData a, Float64List b) {
  assert(b.length == a.length);
  for (int i = 0; i < a.length; ++i) {
    b[i] = a[i];
  }
}

double rmsVolume(Float64List a) {
  double sum = 0;
  for (final x in a) {
    sum += x * x;
  }
  return math.sqrt(sum / a.length);
}
