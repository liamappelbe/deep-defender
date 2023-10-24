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

kSampleRate = 16000
kChunkOverlapFrac = 0.5
kHashesPerChunk = 12
kBitsPerHash = 64
kHashOverlapFrac = 0.5
kSamplesPerHash = 4096
kHashStride = int(kSamplesPerHash * (1 - kHashOverlapFrac))
kChunkSize = kHashesPerChunk * kHashStride + kSamplesPerHash
kChunkStride = int(kSamplesPerHash * (1 - kChunkOverlapFrac))

kOutFile = 'pipeline_generated_test.dart';
kInputWav = 'test.wav';

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
//   python3 test/generate_pipeline_test.py

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:deep_defender/pipeline.dart';
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

def buckets(chunkItr, stftSize, stftStride, bitsPerHash):
  k = 2.0 * math.pi / (stftSize - 1.0)
  w = [0.5 - 0.5 * math.cos(i * k) for i in range(stftSize)]
  for a in chunkItr:
    b = []
    i = 0
    while True:
      e = i + stftSize
      if e > len(a):
        break
      c = [a[i + j] * w[j] for j in range(stftSize)]
      f = numpy.fft.rfft(c)
      y = []
      j1 = 0
      for j2 in logLinItr(len(f), bitsPerHash + 1, 3):
        y.append(sum([numpy.absolute(f[j]) ** 2 for j in range(j1, j2)]))
        j1 = j2
      b.append(y)
      i += stftStride
    yield b

def hashes(bucketItr):
  for b in bucketItr:
    ydf_ = None
    h = []
    for y in b:
      ydf = [y[i] - y[i - 1] for i in range(1, len(y))]
      if ydf_ is not None:
        h.append(sum([
            1 << i if ydf[i] - ydf_[i] > 0 else 0 for i in range(len(ydf))]))
      ydf_ = ydf
    yield h

def generate(f):
  def write(s):
    f.write('%s\n' % s)
  write(kPreamble)

  def makePipelineCase(
      inFile, chunkSize, chunkStride, stftSize, stftStride, bitsPerHash):
    inf = os.path.normpath(os.path.join(os.path.dirname(__file__), inFile))
    audio = readMonoWav(inf, kSampleRate)
    chunkItr = chunks(audio, chunkSize, kChunkStride)
    bucketItr = buckets(
        chunkItr, stftSize, stftStride, bitsPerHash)
    h = [x for x in hashes(bucketItr)]
    write('    await testPipeline(')
    write('      "%s",' % inFile)
    write('      %s,' % chunkSize)
    write('      %s,' % chunkStride)
    write('      %s,' % stftSize)
    write('      %s,' % stftStride)
    write('      %s,' % bitsPerHash)
    write('      [')
    for hh in h:
      write('      [%s],' % u64BufStr(hh))
    write('      ],')
    write('    );')

  write("  test('Pipeline', () async {")
  makePipelineCase(kInputWav, kChunkSize, kChunkStride, kSamplesPerHash,
      kHashStride, kBitsPerHash)
  write('  });')

  write('}\n')

outFile = os.path.normpath(os.path.join(os.path.dirname(__file__), kOutFile))
print('Writing %s' % outFile)
with open(outFile, 'w') as f:
  generate(f)
print('Done :)')
