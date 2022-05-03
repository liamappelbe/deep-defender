# Copyright 2022 The fftea authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generate bucketer_generated_test.dart:
#   python3 test/generate_bucketer_test.py

import numpy
import math
import random
import os

kNumsPerLine = 4
kU16sPerLine = 8
kOutFile = 'bucketer_generated_test.dart';

kPreamble = '''// Copyright 2022 The Deep Defender Authors
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

// GENERATED FILE. DO NOT EDIT. Generated with:
//   python3 test/generate_bucketer_test.py

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:deep_defender/bucketer.dart';
import 'test_util.dart';

main() {'''

random.seed(234875623)

def randReal(r):
  return random.uniform(-r, r)

def realBufStr(a):
  def impl(b):
    return ', '.join(['%.8f' % x for x in b])
  if len(a) <= kNumsPerLine:
    return impl(a)
  s = '\n'
  i = 0
  while i < len(a):
    j = min(i + kNumsPerLine, len(a))
    s += '        %s,' % impl(a[i:j])
    if j < len(a):
      s += ' //'
    s += '\n'
    i = j
  return s + '      '

def toU16(x):
  # [-1, 1] -> [0, 2**16)
  y = int((x + 1) * 0.5 * (2**16 - 1))
  return 0 if y < 0 else 2**16 - 1 if y >= 2**16 else y

def toReal(x):
  # [0, 2**16) -> [1, -1]
  return (x / (2**16 - 1)) * 2 - 1

def u16BufStr(a):
  def impl(b):
    return ', '.join(['0x%x' % x for x in b])
  if len(a) <= kU16sPerLine:
    return impl(a)
  s = '\n'
  i = 0
  while i < len(a):
    j = min(i + kU16sPerLine, len(a))
    s += '        %s,' % impl(a[i:j])
    if j < len(a):
      s += ' //'
    s += '\n'
    i = j
  return s + '      '

def cplxBufStr(a):
  b = []
  for z in a:
    b.append(numpy.real(z))
    b.append(numpy.imag(z))
  return realBufStr(b)

def logItr(f, n):
  for i in range(1, n):
    yield int(math.pow(f, i * 1.0 / n))
  yield f

def chunks(data, size, step):
  i = 0
  while True:
    e = i + size
    if e > len(data):
      break
    yield data[i:e]
    i += step

def windowedChunks(chunkItr):
  w = None
  for c in chunkItr:
    if w is None:
      k = 2.0 * math.pi / (len(c) - 1.0)
      w = [0.5 - 0.5 * math.cos(i * k) for i in range(len(c))]
    assert(len(c) == len(w))
    yield [c[i] * w[i] for i in range(len(c))]

def bandPowers(windowedChunkItr, numBands):
  for wc in windowedChunkItr:
    y = []
    f = numpy.fft.rfft(wc)
    i = 0
    for j in logItr(len(f), numBands):
      y.append(sum([numpy.absolute(f[k]) ** 2 for k in range(i, j)]))
      i = j
    yield y

def generate(f):
  def write(s):
    f.write('%s\n' % s)
  write(kPreamble)

  def makeBucketerCase(chunkSize, stftSize, stftStride, buckets):
    a = [toU16(randReal(1)) for i in range(chunkSize)]
    r = [toReal(x) for x in a]
    b = [p for p in
        bandPowers(windowedChunks(chunks(r, stftSize, stftStride)), buckets)]
    write('    testBucketer(')
    write('      %s,' % chunkSize)
    write('      %s,' % stftSize)
    write('      %s,' % stftStride)
    write('      %s,' % buckets)
    write('      [%s],' % u16BufStr(a))
    write('      [')
    for c in b:
      write('      [%s],' % realBufStr(c))
    write('      ],')
    write('    );')

  write("  test('Bucketer', () {")
  makeBucketerCase(128, 64, 32, 9)
  write('  });')

  write('}\n')

outFile = os.path.normpath(os.path.join(os.path.dirname(__file__), kOutFile))
print('Writing %s' % outFile)
with open(outFile, 'w') as f:
  generate(f)
print('Done :)')
