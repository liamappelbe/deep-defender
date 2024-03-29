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

import "dart:async";
import "dart:math";
import "dart:typed_data";
import "package:deep_defender/const.dart";
import "package:deep_defender/crypto.dart";
import "package:deep_defender/metadata.dart";
import "package:deep_defender/pipeline.dart";
import "package:deep_defender/saf_code_builder.dart";
import "package:deep_defender/util.dart";
import "package:deep_defender/verifier.dart";
import "package:test/test.dart";
import "package:wav/wav.dart";

const kTestKey =
    '{"kty":"EC","alg":"ES256","use":"sig","crv":"P-256","x":"AJXCXc4kQBQm'
    'bMLi2MpwrklFJtQC01LYCwwF-cdodv_z","y":"cyV700E19jQVyGf9S0vdsfpjj-hkhx'
    'OhVMlzkB-9AJc=","d":"AK86ItzaEXq05gA5LhLSnAmP6aPLrSotlSqq67TvgvIx"}';

Future<Wav> getTestWav([String filename = "test/test.wav"]) async =>
    await Wav.readFile(filename);

class TimedFingerprint {
  int timeMs;
  Float64List chunk;
  Uint8List fingerprint;
  TimedFingerprint(this.timeMs, this.chunk, this.fingerprint);
}

List<TimedFingerprint> getHashes(Float64List audio) {
  final allHashes = <TimedFingerprint>[];
  void onHashes(int t, Float64List chunk, Uint8List h) {
    allHashes.add(TimedFingerprint(t, chunk, Uint8List.fromList(h)));
  }

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

runTest({
  FutureOr<Float64List>? Function(Float64List)? tweakAudio,
  List<Uint8List>? Function(List<Uint8List>)? tweakSafCodes,
  Function(Wav, List<VerifierResult>)? verifyResults,
}) async {
  final wav = await getTestWav();
  final rawaudio = wav.toMono();
  expect(wav.samplesPerSecond, kSampleRate);

  final keyPair = KeyPair.fromJwk(kTestKey);
  final signer = keyPair.privateKey.signer();
  final rawSafCodes = getSafCodes(getHashes(rawaudio), signer);
  final allSafCodes = tweakSafCodes?.call(rawSafCodes) ?? rawSafCodes;

  final results = <VerifierResult>[];
  void onResult(VerifierResult result) {
    results.add(result);
  }

  final verifier = SafCodeVerifier(keyPair.publicKey, onResult);
  final audio = (await tweakAudio?.call(rawaudio)) ?? rawaudio;
  //debugWav(audio);
  await verifier.addAudio(audio);
  for (final code in allSafCodes) {
    await verifier.addSafCode(code);
  }

  expect(results.length, allSafCodes.length);
  verifyResults?.call(wav, results);
}

debugWav(Float64List audio) {
  Wav([audio], kSampleRate).writeFile("debug.wav");
}

main() async {
  test("Verifier ok when no change", () async {
    await runTest(
      verifyResults: (Wav wav, List<VerifierResult> results) {
        final audioLenMs = (wav.duration * 1000).toInt();
        for (int i = 0; i < results.length; ++i) {
          final result = results[i];
          expect(result.error, VerifierStatus.ok);
          expect(result.header!.version, kVersion);
          expect(result.header!.algorithm, kAlgorithmId);
          final j = i * kChunkStride + kChunkSize;
          expect(result.header!.timeMs,
              (-audioLenMs + (j * 1000.0 / kSampleRate)).toInt());
        }
      },
    );
  });

  test("Verifier ok when volume decreases", () async {
    await runTest(
      tweakAudio: (Float64List audio) {
        for (int i = 0; i < audio.length; ++i) {
          audio[i] *= 0.1;
        }
        return audio;
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  test("Verifier ok when volume increases", () async {
    await runTest(
      tweakAudio: (Float64List audio) {
        for (int i = 0; i < audio.length; ++i) {
          audio[i] *= 10;
        }
        return audio;
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  test("Verifier ok when volume increases and clips", () async {
    await runTest(
      tweakAudio: (Float64List audio) {
        for (int i = 0; i < audio.length; ++i) {
          // Increasing this to 3 breaks the hash, even though it's still audibly
          // pretty much the same. The hash is too sensitive to this distortion.
          audio[i] *= 2.5;
          if (audio[i] < -1) audio[i] = -1;
          if (audio[i] > 1) audio[i] = 1;
        }
        return audio;
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  test("Verifier ok when some noise", () async {
    await runTest(
      tweakAudio: (Float64List audio) {
        final rand = Random();
        final noiseAmplitude = 0.03 * rmsVolume(audio);
        for (int i = 0; i < audio.length; ++i) {
          audio[i] += (rand.nextDouble() - 0.5) * noiseAmplitude;
        }
        return audio;
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  test("Verifier ok when low pass filtered", () async {
    await runTest(
      tweakAudio: (Float64List audio) {
        double x = 0;
        for (int i = 0; i < audio.length; ++i) {
          x += 0.1 * (audio[i] - x);
          audio[i] = 2 * x;
        }
        return audio;
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  test("Verifier ok when high pass filtered", () async {
    await runTest(
      tweakAudio: (Float64List audio) {
        final out = Float64List(audio.length);
        for (int i = 1; i < audio.length; ++i) {
          out[i] = 0.1 * (out[i - 1] + audio[i] - audio[i - 1]);
        }
        for (int i = 0; i < out.length; ++i) {
          out[i] *= 30;
        }
        return out;
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  test("Verifier ok when audio is delayed", () async {
    await runTest(
      tweakAudio: (Float64List audio) {
        final offset = (kSampleRate * 0.8).toInt();
        final out = Float64List(audio.length + offset);
        for (int i = 0; i < audio.length; ++i) {
          out[i + offset] = audio[i];
        }
        return out;
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  //test('Verifier misses first saf code when audio is early', () async {
  //  await runTest(
  //    tweakAudio: (Float64List audio) {
  //      final offset = (kSampleRate * 0.8).toInt();
  //      final out = Float64List(audio.length - offset);
  //      for (int i = 0; i < out.length; ++i) {
  //        out[i] = audio[i + offset];
  //      }
  //      return out;
  //    },
  //    verifyResults: (_, List<VerifierResult> results) {
  //      for (int i = 0; i < results.length; ++i) {
  //        final result = results[i];
  //        if (i == 0) {
  //          expect(result.error, VerifierStatus.hashError);
  //        } else {
  //          expect(result.error, VerifierStatus.ok);
  //        }
  //      }
  //    },
  //  );
  //});

  test("Verifier ok when audio has been compressed", () async {
    await runTest(
      // test_compressed.wav was created by converting to a 32kbps MP3 and back.
      tweakAudio: (_) async {
        return (await getTestWav("test/test_compressed.wav")).toMono();
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  // The hashes can't handle even a 1% speed change.
  // TODO(#11): Can the verifier be modified to handle this?
  /*test('Verifier ok when audio is slightly fast', () async {
    await runTest(
      tweakAudio: (_) async {
        return (await getTestWav('test/test_slightly_fast.wav')).toMono();
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });

  test('Verifier ok when audio is slightly slow', () async {
    await runTest(
      tweakAudio: (_) async {
        return (await getTestWav('test/test_slightly_slow.wav')).toMono();
      },
      verifyResults: (_, List<VerifierResult> results) {
        for (final result in results) {
          expect(result.error, VerifierStatus.ok);
        }
      },
    );
  });*/

  // Tests that should return ok:
  //  ✓ no changes to input
  //  ✓ change in volume
  //  ✓ clipping
  //  ✓ some noise
  //  ✓ low pass filter
  //  ✓ high pass filter
  //  ✓ positive time offset
  //  ✓ negative time offset
  //  X small speed up
  //  X small slow down
  //  ✓ compression
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
