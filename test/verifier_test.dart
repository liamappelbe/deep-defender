// Copyright 2023 The Deep Defender Authors
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
import 'package:deep_defender/const.dart';
import 'package:deep_defender/crypto.dart';
import 'package:deep_defender/metadata.dart';
import 'package:deep_defender/pipeline.dart';
import 'package:deep_defender/saf_code_builder.dart';
import 'package:deep_defender/verifier.dart';
import 'package:test/test.dart';
import 'package:wav/wav.dart';

const kTestKey =
    '{"kty":"EC","alg":"ES256","use":"sig","crv":"P-256","x":"AJXCXc4kQBQm'
    'bMLi2MpwrklFJtQC01LYCwwF-cdodv_z","y":"cyV700E19jQVyGf9S0vdsfpjj-hkhx'
    'OhVMlzkB-9AJc=","d":"AK86ItzaEXq05gA5LhLSnAmP6aPLrSotlSqq67TvgvIx"}';

Future<Wav> getTestWav() async => await Wav.readFile('test/test.wav');

class TimedFingerprint {
  int timeMs;
  Uint8List fingerprint;
  TimedFingerprint(this.timeMs, this.fingerprint);
}

List<TimedFingerprint> getHashes(Float64List audio) {
  final allHashes = <TimedFingerprint>[];
  void onHashes(int t, Uint64List h) {
    allHashes
        .add(TimedFingerprint(t, Uint8List.fromList(Uint8List.sublistView(h))));
  }

  ;
  final pipeline = Pipeline(
    onHashes,
    sampleRate: kSampleRate,
    chunkSize: kChunkSize,
    chunkStride: kChunkStride,
    samplesPerHash: kSamplesPerHash,
    hashStride: kHashStride,
    bitsPerHash: kBitsPerHash,
  );
  pipeline.onDataF64(0, audio);
  final flushTimeMs =
      ((kChunkStride - (audio.length % kChunkStride)) * 1000 / kSampleRate)
          .ceil();
  pipeline.flush(flushTimeMs);
  return allHashes;
}

List<Uint8List> getSafCodes(List<TimedFingerprint> h, Signer s) {
  final scb = SafCodeBuilder(Metadata(), s);
  return h
      .map((th) => Uint8List.fromList(scb.generate(th.timeMs, th.fingerprint)))
      .toList();
}

main() async {
  test('Verifier ok', () async {
    final wav = await getTestWav();
    final audio = wav.toMono();
    expect(wav.samplesPerSecond, kSampleRate);

    final keyPair = KeyPair.fromJwk(kTestKey);
    final signer = keyPair.privateKey.signer();
    final allSafCodes = getSafCodes(getHashes(audio), signer);

    final results = <VerifierResult>[];
    void onResult(VerifierResult result) {
      results.add(result);
    }

    final verifier =
        SafCodeVerifier(keyPair.publicKey, wav.samplesPerSecond, onResult);
    await verifier.addAudio(wav.toMono());
    for (final code in allSafCodes) await verifier.addSafCode(code);

    final audioLenMs = (wav.duration * 1000).toInt();
    expect(results.length, allSafCodes.length);
    for (int i = 0; i < results.length; ++i) {
      final result = results[i];
      expect(result.error, VerifierStatus.ok);
      expect(result.header!.version, kVersion);
      expect(result.header!.algorithm, kAlgorithmId);
      expect(
          result.header!.timeMs,
          (-audioLenMs +
                  ((i * kChunkStride + kChunkSize) * 1000.0 / kSampleRate))
              .toInt());
    }
  });

  // Tests that should return ok:
  //  - no changes to input
  //  - change in volume
  //  - some noise
  //  - random filtering
  //  - clipping
  //  - positive time offset
  //  - negative time offset
  //  - small speed up
  //  - small slow down
  //  - small pitch up
  //  - small pitch down
  //  - test streaming sematics

  // Tests that should return an error:
  //  - malformed saf code (too short)
  //  - malformed saf code (no magic string)
  //  - bad version code
  //  - bad algorithm code
  //  - signature doesn't match
  //  - sequence error (from the past)
  //  - sequence error (too close to previous one)
  //  - sequence error (too far in future)
  //  - hash doesn't match (different audio clip)
  //  - hash doesn't match (same audio clip, but shuffled)
  //  - hash doesn't match (same audio clip, but a part is silenced)
  //  - speed error (too fast)
  //  - speed error (too slow)
}
