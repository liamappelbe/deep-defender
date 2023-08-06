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

import 'dart:collection';
import 'dart:typed_data';

import 'const.dart';
import 'crypto.dart';
import 'metadata.dart';
import 'pipeline.dart';

// TODO: These depend on the hash algorithm.
const double _hashLengthSec = kChunkSize / kSampleRate;
const double _hashStrideSec = kChunkStride / kSampleRate;
const int _minTimeBetweenHashesMs = (900 * _hashStrideSec).floor();
const int _maxTimeBetweenHashesMs = (1100 * _hashStrideSec).ceil();

/// Verifies that a segment of audio matches a sequence of hashes.
class Verifier {
  final Pipeline _pipeline;
  final Verifier _verifier;
  final int _sampleRate;
  final void Function(VerifierResult) _onResult;

  // TODO(ZXCV): Switch to a queue to buffer only the audio we need.
  // int _audioSampleIndex = 0;
  // final _audio = ListQueue<double>();
  final _audio = <double>[];

  final _safCodes = ListQueue<Uint8List>();
  bool _flushing = false;

  final _timingEstimator = _TimingEstimator();

  Verifier(this._pipeline, PublicKey publicKey, this._sampleRate, this._onResult) : _verifier = publicKey.verifier();

  void addAudio(Float64List audio) {
    _audio.addAll(audio);
    _flush();
  }

  void addSafCode(Uint8List safCode) {
    _safCodes.add(safCode);
    _flush();
  }

  Future<void> _flush() async {
    if (_flushing) return;
    // TODO: This is a hack. Switch to a stream API.
    _flushing = true;
    while (_audio.length >= _minAudioCodeSize && _safCodes.length > 0) {
      this._onResult(await _verify(_safCodes.removeFirst()));
    }
    _flushing = false;
  }

  Future<VerifierResult> _verify(Uint8List safCode) async {
    // TODO: Remember to take into account the fact that the chunk stride is
    // shorter than a full chunk.

    // Decode the next SAF code.
    final header = SafCodeHeader.decode(safCode);
    if (header == null) {
      return VerifierResult(safCode, VerifierStatus.codeError);
    }
    if (header.version != kVersion) {
      return VerifierResult(safCode, VerifierStatus.versionError, header);
    }
    if (header.algorithm != kAlgorithmId) {
      return VerifierResult(safCode, VerifierStatus.algorithmError, header);
    }

    // Check that the signature matches.
    final split = safCode.length - Signer.length;
    final hash = Uint8List.sublistView(safCode, SafCodeHeader.length, split);
    final sig = Uint8List.sublistView(safCode, split);
    if (!_verifier.verify(hash, sig)) {
      return VerifierResult(safCode, VerifierStatus.signatureError, header);
    }

    // Check that the hash is in sequence. That is, we didn't get one from the
    // past or the future.
    final lastCodeTimeMs = _timingEstimator.lastCodeTimeMs;
    if (lastCodeTimeMs != null) {
      final deltaCodeTimeMs = header.timeMs - lastCodeTimeMs;
      if (deltaCodeTimeMs < _minTimeBetweenHashesMs || deltaCodeTimeMs > _maxTimeBetweenHashesMs) {
        return VerifierResult(safCode, VerifierStatus.sequenceError, header);
      }
    }

    // Get an estimate of the next audio time, and use it to inform the hash
    // checker.
    final estAudioTimeSec = _timingEstimator.estimateAudioTime(header.timeMs);

    // Run the hash checker with different latency values until we get a
    // match. If we have to change the latency by too much, give up.
    final hashCheck = _HashCheck(
        largest possible audio chunk that might be relevent,
        0,  // TODO(ZXCV): Audio time of the start of the audio.
    );
    final strategy = _CheckingStrategy();
    final result = strategy.run(hashCheck, estAudioTimeSec);

    if (result.error == VarifierStatus.hashError) {
      return VerifierResult(safCode, VerifierStatus.hashError, header);
    }
    final matchedAudio;  // TODO.
    final relativeLatency = result.audioTimeSec - estAudioTimeSec;
    final speed = _timingEstimator.estimateSpeed;
    final audioMatch = AudioMatch(matchedAudio, relativeLatency, speed);

    // Update the timing estimator.
    _timingEstimator.setTime(result.audioTimeSec, header.timeMs);

    // Check for speed errors.
    if (speed < 0.9 || speed > 1.1) {
      return VerifierResult(safCode, VerifierStatus.speedError, header);
    }

    // TODO(ZXCV): Drop data from the audio buffer and update the audio index.

    // Report result.
    return result;
  }

  int get _minAudioCodeSize {
    // TODO: Handle the case where the audio sample rate is different to the
    // SAF code's audio sample rate.
    return (1.5 * _pipeline.chunkSize).toInt();
  }
}

class _CheckingStrategy {
  VerifierStatus run(_HashCheck check) {
    // Increase and decrease the offset by about 10 ms until we get a match, or
    // maximise the score. Give up if we go too far.

  }
}

class StrategyResult {
  VerifierStatus error;
  double audioTimeSec;
}

class _HashCheck {
  double check(double offset) {
    // Run the Pipeline and check the hash. Return a score based on how close
    // the match is.
  }
}

class SafCodeHeader {
  final int version;
  final int algorithm;
  final int timeMs;

  SafCodeHeader(this.version, this.algorithm, this.timeMs);

  static const int length = Metadata.length;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timeMs, isUtc: true);

  static SafCodeHeader? decode(Uint8List code) {
    if (code.length < Metadata.size()) return null;

    for (int i = 0; i < kMagicString.length; ++i) {
      if (code[i] != kMagicString.codeUnitAt(i)) return null;
    }

    final bytes = code.buffer.asByteData();
    final version = bytes.getUint16(kMagicString.length, Endian.big);
    final algorithm = bytes.getUint16(kMagicString.length + 2, Endian.big);
    final timeMs = bytes.getUint16(kMagicString.length + 4, Endian.big);
    return SafCodeHeader(version, algorithm, timeMs);
  }
}

class AudioMatch {
  final Float64List matchedAudio;
  final double relativeLatency;
  final double speed;
}

class VerifierResult {
  final Uint8List safCode;

  final VerifierStatus error;

  // Present for any error except codeError.
  final SafCodeHeader? header;

  // Present only if error is ok or speedError
  final AudioMatch? audio;

  VerifierResult(this.safCode, this.error, [this.header, this.audio]);
}

enum VerifierStatus {
  // The SAF code matches the audio.
  ok,

  // Not a valid SAF code.
  codeError,

  // Unknown version. Do you need to update the verifier?
  versionError,

  // Unknown algorithm. Do you need to update the verifier?
  algorithmError,

  // The cryptographic signature of the SAF code doesn't match the public key.
  signatureError,

  // The hash was out of sequence. Check VerifierResult.header.time. May
  // indicate a valid edit point. TODO: Should we check the audio hash?
  sequenceError,

  // The hash doesn't match the audio, or is malformed.
  hashError,

  // The audio is too slow or too fast. Check VerifierResult.audio.speed.
  speedError,
}

class _TimingEstimator {
  int _lastCodeTimeMs?;
  double _lastAudioTimeSec = 0;
  double _currentSpeed = 1;  // > 1 means audio is fast.

  const double _speedSmoothingFactor = 0.3;

  int? get lastCodeTimeMs => _lastCodeTimeMs;

  double estimateAudioTime(int codeTimeMs) {
    final lastCodeTime = _lastCodeTimeMs;
    if (lastCodeTime == null) return 0;
    final codeDt = codeTimeMs - lastCodeTime;
    return codeDt * _currentSpeed;
  }

  void setTime(double audioTimeSec, int codeTimeMs) {
    final lastCodeTime = _lastCodeTimeMs;
    if (lastCodeTime) return;
    final audioDtSec = audioTimeSec - _lastAudioTimeSec;
    final codeDtSec = (codeTimeMs - lastCodeTime) / 1000.0;
    final speed = audioDtSec / codeDtSec;
    if (_lastCodeTimeMs) {
      _currentSpeed = speed;
    } else {
      _currentSpeed += _speedSmoothingFactor * (speed - _currentSpeed);
    }
    _lastCodeTimeMs = codeTimeMs;
    _lastAudioTimeSec = audioTimeSec;
  }

  double get estimateSpeed => _currentSpeed;
}
