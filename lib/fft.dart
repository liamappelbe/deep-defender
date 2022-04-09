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

bool isPowerOf2(int x) => x & (x - 1) == 0;

/// Performs FFTs of a particular power-of-2 size.
class Fft {
  // Twiddle factors.
  final Float64List _twiddles;

  Fft(int powerOf2Size) : _twiddles = _calculateTwiddles(powerOf2Size);

  static Float64List _calculateTwiddles(int powerOf2Size) {
    if (!isPowerOf2(powerOf2Size)) {
      throw ArgumentError('FFT size must be a power of 2.', 'powerOf2Size');
    }
    final twiddles = new Float64List(powerOf2Size);
    if (powerOf2Size < 2) return twiddles;
    final step = -math.pi / powerOf2Size;
    for (var i = 0; i < powerOf2Size; i += 2) {
      final theta = step * i;
      twiddles[i] = math.cos(theta);
      twiddles[i + 1] = math.sin(theta);
    }
    return twiddles;
  }

  int _bitReverse(int i, int m) {
    var j = 0;
    var b = 1;
    while (m > 0) {
      m ~/= 2;
      if (i & m != 0) j |= b;
      b *= 2;
    }
    return j;
  }

  void _bitReversePermute(Float64List a) {
    final n = a.length ~/ 2;
    for (var i = 0; i < n; ++i) {
      final j = _bitReverse(i, n);
      if (j < i) {
        final ir = i * 2;
        final jr = j * 2;
        final tr = a[ir];
        a[ir] = a[jr];
        a[jr] = tr;
        final ii = ir + 1;
        final ji = jr + 1;
        final ti = a[ii];
        a[ii] = a[ji];
        a[ji] = ti;
      }
    }
  }

  /// In-place FFT.
  ///
  /// Performs an in-place FFT on [a], where [a] is a flat array of doubles,
  /// alternating between real and imaginary components:
  /// `[real, imag, real, imag, ...]`
  ///
  /// The result is stored back in a. No new arrays are allocated by this
  /// method.
  ///
  /// This is the most efficient FFT method, if your data is already in the
  /// correct format. Otherwise, you can use one of the other methods to handle
  /// the conversion for you.
  void inPlaceFft(Float64List a) {
    final n = _twiddles.length;
    final n2 = n * 2;
    if (a.length != n2) {
      throw ArgumentError('Input data is the wrong length.', 'a');
    }
    _bitReversePermute(a);
    for (var m = 1; m < n;) {
      final m2 = m * 2;
      final n_m = n ~/ m;
      for (var k = 0, t = 0; k < n2;) {
        final km = k + m2;
        final pr = a[k];
        final pi = a[k + 1];
        final or = a[km];
        final oi = a[km + 1];
        final wr = _twiddles[t];
        final wi = _twiddles[t + 1];
        final qr = or * wr - oi * wi;
        final qi = oi * wr + or * wi;
        a[k] = pr + qr;
        a[k + 1] = pi + qi;
        a[km] = pr - qr;
        a[km + 1] = pi - qi;
        k += 2;
        t += n_m;
        if (t >= n) {
          k += m2;
          t = 0;
        }
      }
      m = m2;
    }
  }

  /// Real-valued FFT.
  ///
  /// Performs an FFT on real-valued inputs. The output is a flat array of
  /// doubles, alternating between real and imaginary components:
  /// `[real, imag, real, imag, ...]`
  Float64List realFft(List<double> a) {
    final o = Float64List(a.length * 2);
    for (var i = 0; i < a.length; ++i) {
      o[i * 2] = a[i];
    }
    inPlaceFft(o);
    return o;
  }
}
