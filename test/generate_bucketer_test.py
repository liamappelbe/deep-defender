# Copyright 2023 The Deep Defender Authors
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

import os

from generator_utils import *

kNumsPerLine = 4
kOutFile = 'bucketer_generated_test.dart';

kPreamble = '''// Copyright 2023 The Deep Defender Authors
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
    for j in logLinItr(len(f), numBands, 3):
      y.append(sum([numpy.absolute(f[k]) ** 2 for k in range(i, j)]))
      i = j
    yield y

def generate(f):
  def write(s):
    f.write('%s\n' % s)
  write(kPreamble)

  def makeBucketerCase(chunkSize, stftSize, stftStride, buckets):
    a = [randReal(1) for i in range(chunkSize)]
    b = [p for p in
        bandPowers(windowedChunks(chunks(a, stftSize, stftStride)), buckets)]
    write('    testBucketer(')
    write('      %s,' % chunkSize)
    write('      %s,' % stftSize)
    write('      %s,' % stftStride)
    write('      %s,' % buckets)
    write('      [%s],' % realBufStr(a))
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
