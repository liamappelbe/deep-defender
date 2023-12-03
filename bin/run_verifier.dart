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

import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";
import "package:logging/logging.dart";
import "package:deep_defender/const.dart";
import "package:deep_defender/crypto.dart";
import "package:deep_defender/verifier.dart";
import "package:wav/wav.dart";

final _log = Logger("run_verifier");

class TimedSafCode {
  int timeMs;
  Uint8List safCode;
  TimedSafCode(this.timeMs, this.safCode);
}

final regex = RegExp(r"([0-9]+) ms to ([0-9]+) ms: b'([^']+)'");

TimedSafCode? parseSafCode(String line) {
  final match = regex.firstMatch(line);
  if (match == null) return null;
  final timeMs = int.parse(match.group(1)!);
  final safCode = base64Url.decode(match.group(3)!);
  return TimedSafCode(timeMs, safCode);
}

List<TimedSafCode> parseSafCodes(String safCodes) {
  final a = <TimedSafCode>[];
  for (final line in safCodes.split("\n")) {
    final saf = parseSafCode(line.trim());
    if (saf != null) {
      a.add(saf);
    }
  }
  return a;
}

debugWav(Float64List audio, [String name = "debug"]) {
  Wav([audio.sublist(0)], kSampleRate).writeFile("$name.wav");
}

main(List<String> args) async {
  if (args.length != 3) {
    _log.severe("Wrong number of args. Usage:");
    _log.severe("  dart run run_verifier.dart input.wav safCodes.txt key.json");
    return;
  }

  final wav = await Wav.readFile(args[0]);
  assert(wav.samplesPerSecond == kSampleRate);
  final audio = wav.toMono();
  _log.info(
      "Wav is ${(audio.length / kSampleRate).toStringAsFixed(2)} sec long");

  final safCodes = parseSafCodes(await File(args[1]).readAsString());
  _log.info("Loaded ${safCodes.length} SAF codes");
  final firstCodeTimeSec = safCodes[0].timeMs / 1000.0;
  final audioStartTimeSec = max(0, firstCodeTimeSec - 2);
  final audioStartSample = (audioStartTimeSec * kSampleRate).toInt();
  final truncatedAudio = Float64List.sublistView(audio, audioStartSample);

  final publicKey = PublicKey.fromJwk(await File(args[2]).readAsString());

  final verifier = SafCodeVerifier(publicKey, (VerifierResult result) {
    _log.info("${result.error}\t${result.score}\t${result.header?.time}");
    //final volume = Hasher.u32ToVol(
    //    ByteData.sublistView(result.safCode).getUint32(
    //        Metadata.length, Endian.big));
    //_log.info("${volume},${result.score}");
    //if (result.audio != null) {
    //  debugWav(result.audio!.matchedAudio, 'chunk ${result.audio!.audioTime}');
    //}
  });
  await verifier.addAudio(truncatedAudio);
  for (final tsc in safCodes) {
    await verifier.addSafCode(tsc.safCode);
  }
  _log.info("Done");
}
