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

import 'package:deep_defender/bucketer.dart';
import 'package:deep_defender/pipeline.dart';
import 'package:deep_defender/util.dart';
import 'package:test/test.dart';
import 'package:wav/wav.dart';

void expectClose(List<double> out, List<double> exp, [double delta = 1e-6]) {
  expect(out.length, exp.length);
  for (int i = 0; i < out.length; ++i) {
    expect(out[i], closeTo(exp[i], delta));
  }
}

void testBucketer(int chunkSize, int stftSize, int stftStride, int buckets,
    List<double> inp, List<List<double>> exp) {
  List<List<double>> out = [];
  bool ended = false;
  final bucketer = Bucketer(
    chunkSize,
    stftSize,
    stftStride,
    buckets,
    (powers) {
      expect(ended, isFalse);
      out.add(powers.sublist(0));
    },
    (timeMs) {
      expect(timeMs, 1234);
      ended = true;
    },
  );
  bucketer.onData(1234, Float64List.fromList(inp));
  expect(ended, isTrue);
  expect(out.length, exp.length);
  for (int i = 0; i < out.length; ++i) {
    expectClose(out[i], exp[i], 1e-6);
  }
}

Future<void> testPipeline(
    String filename,
    int chunkSize,
    int chunkStride,
    int samplesPerHash,
    int hashStride,
    int bitsPerHash,
    List<List<int>> expectedHashes) async {
  final wav = await Wav.readFile('test/$filename');
  final audio = wav.toMono();
  final data = Uint16List(audio.length);
  f64ToU16(audio, data);
  final actualHashes = <Uint64List>[];
  final pipeline = Pipeline(
    (int timeMs, Uint64List hashes) {
      // TODO: Test timeMs.
      actualHashes.add(hashes.sublist(0));
    },
    sampleRate: wav.samplesPerSecond,
    chunkSize: chunkSize,
    chunkStride: chunkStride,
    samplesPerHash: samplesPerHash,
    hashStride: hashStride,
    bitsPerHash: bitsPerHash,
  );
  pipeline.onData((data.length * 1000 / wav.samplesPerSecond).floor(), data);
  expect(actualHashes, expectedHashes);
}
