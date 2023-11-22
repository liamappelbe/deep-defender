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
import 'dart:math';
import 'dart:typed_data';
import 'package:wav/util.dart';

import 'bucketer.dart';
import 'hasher.dart';

import 'const.dart';
import 'crypto.dart';
import 'metadata.dart';
import 'pipeline.dart';

// TODO: These depend on the hash algorithm.
const double _minAllowedSpeed = 0.95;
const double _maxAllowedSpeed = 2 - _minAllowedSpeed;
const double _minDetectableSpeed = 0.55; // Just above 0.5.
const double _maxDetectableSpeed = 2 - _minDetectableSpeed;
const int _hashSampleRate = kSampleRate;
final int _chunkSize = kChunkSize;
final double _hashLengthSec = kChunkSize / kSampleRate;
final double _hashStrideSec = kChunkStride / kSampleRate;
final int _minTimeBetweenHashesMs =
    (1000 * _minDetectableSpeed * _hashStrideSec).floor();
final int _maxTimeBetweenHashesMs =
    (1000 * _maxDetectableSpeed * _hashStrideSec).ceil();

/// Verifies that a segment of audio matches a sequence of hashes.
class SafCodeVerifier {
  final Verifier _verifier;
  final void Function(VerifierResult) _onResult;

  // TODO(ZXCV): Switch to a queue to buffer only the audio we need.
  // int _audioSampleIndex = 0;
  // final _audio = ListQueue<double>();
  final _audio = <double>[];

  final _safCodes = ListQueue<Uint8List>();
  bool _flushing = false;

  final _timingEstimator = _TimingEstimator();

  SafCodeVerifier(PublicKey publicKey, this._onResult)
      : _verifier = publicKey.verifier();

  // TODO: If sample rate != _hashSampleRate, use FFT to resample the audio.
  Future<void> addAudio(Float64List audio) async {
    _audio.addAll(audio);
    await _flush();
  }

  Future<void> addSafCode(Uint8List safCode) async {
    _safCodes.add(safCode);
    await _flush();
  }

  // TODO: Add a flush method that pads the audio with zeros and flushes.

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
    // Decode the next SAF code.
    final header = SafCodeHeader.decode(safCode);
    if (header == null) {
      return VerifierResult(safCode, VerifierStatus.codeError, 0);
    }
    if (header.version != kVersion) {
      return VerifierResult(safCode, VerifierStatus.versionError, 0, header);
    }
    if (header.algorithm != kAlgorithmId) {
      return VerifierResult(safCode, VerifierStatus.algorithmError, 0, header);
    }

    // Check that the signature matches.
    final split = safCode.length - Signer.length;
    final headerAndHash = Uint8List.sublistView(safCode, 0, split);
    final sig = Uint8List.sublistView(safCode, split);
    if (!_verifier.verify(headerAndHash, sig)) {
      return VerifierResult(safCode, VerifierStatus.signatureError, 0, header);
    }

    // Check that the hash is in sequence. That is, we didn't get one from the
    // past or the future.
    // TODO: Should we be checking the timestamp vs the time that the SAF code
    // appeared in the video?
    final lastCodeTimeMs = _timingEstimator.lastCodeTimeMs;
    if (lastCodeTimeMs != null) {
      final deltaCodeTimeMs = header.timeMs - lastCodeTimeMs;
      if (deltaCodeTimeMs < _minTimeBetweenHashesMs ||
          deltaCodeTimeMs > _maxTimeBetweenHashesMs) {
        return VerifierResult(safCode, VerifierStatus.sequenceError, 0, header);
      }
    }

    // Get an estimate of the next audio time, and use it to inform the hash
    // checker.
    //print("Time: ${header.timeMs * 1e-3}");
    final est = _timingEstimator.estimateAudioTime(header.timeMs);

    // Run the hash checker with different latency values until we get a
    // match. If we have to change the latency by too much, give up.
    final hash = Uint8List.sublistView(safCode, SafCodeHeader.length, split);
    //print(hash);
    final possibleChunk =
        _audioSlice(est.minAudioTimeSec, est.maxAudioTimeSec + _hashLengthSec);
    final hashCheck = _HashCheck(hash, possibleChunk, est.minAudioTimeSec);
    final strategy = _CheckingStrategy(est);
    final searchResult = strategy(hashCheck);
    final audioTimeSec = searchResult.t;

    // Update the timing estimator.
    _timingEstimator.setTime(audioTimeSec, header.timeMs);

    if (searchResult.score < hashCheck.minAllowedScore()) {
      return VerifierResult(safCode, VerifierStatus.hashError, searchResult.score, header);
    }
    final matchedAudio = hashCheck.getAudioSlice(searchResult.t)!;
    final relativeLatency = audioTimeSec - (est.estAudioTimeSec ?? 0);
    final speed = _timingEstimator.estimateSpeed;
    final audioMatch = AudioMatch(
        matchedAudio, audioTimeSec, relativeLatency, speed);

    // Check for speed errors.
    if (speed < _minAllowedSpeed || speed > _maxAllowedSpeed) {
      //print("Speed error: $speed");
      return VerifierResult(safCode, VerifierStatus.speedError, searchResult.score, header);
    }

    // TODO(ZXCV): Drop data from the audio buffer and update the audio index.

    // Report result.
    return VerifierResult(safCode, VerifierStatus.ok, searchResult.score, header, audioMatch);
  }

  int get _minAudioCodeSize {
    return (1.5 * _chunkSize).toInt();
  }

  Float64List _audioSlice(double t0, double t1) {
    final i0 = (t0 * _hashSampleRate).round(); // TODO(ZXCV): _audioSampleIndex
    final i1 = (t1 * _hashSampleRate).round();
    final slice = Float64List(i1 - i0);
    for (int i = i0; i < i1; ++i) {
      slice[i - i0] = i < _audio.length ? _audio[i] : 0;
    }
    return slice;
  }
}

class _CheckingStrategy {
  final _TimingEstimate _est;
  _CheckingStrategy(this._est) {
    //print(_est);
  }

  SearchResult call(_HashCheck check) {
    final targT = _est.targetAudioTimeSec;
    double range = (_est.maxAudioTimeSec - _est.minAudioTimeSec) / 2;
    double t = (_est.maxAudioTimeSec + _est.minAudioTimeSec) / 2;
    double finalScore = -1;
    const n = 10;
    while (range > 0.005) {
      double bestT = 0;
      double bestScore = -1;
      double bestHashScore = -1;
      for (int i = -n; i <= n; ++i) {
        final t2 = t + i * range / (n);
        final hashScore = check(t2);
        double score = hashScore;
        if (targT != null) {
          final dt = t2 - targT;
          score *= 1 - 0.1 * dt * dt;
        }
        if (score > bestScore) {
          bestScore = score;
          bestHashScore = hashScore;
          bestT = t2;
        }
      }
      range /= n;
      t = bestT;
      finalScore = bestHashScore;
    }
    //print('    $t -> $finalScore');
    //Bucketer.debug = true;Hasher.debug = true;
    //check(t);
    //Bucketer.debug = false;Hasher.debug = false;
    return SearchResult(finalScore, t);
  }
}

class SearchResult {
  double score;
  double t;
  SearchResult(this.score, this.t);
}

class _HashCheck {
  static const double _minAllowedScore = 0.8;
  double minAllowedScore() => _minAllowedScore;

  Uint8List _target;
  Float64List _possibleChunk;
  double _chunkStartTimeSec;

  _HashCheck(this._target, this._possibleChunk, this._chunkStartTimeSec);

  static double _adjustScore(double score, double thresh) =>
      1.0 - pow(1 - score, log(1 - _minAllowedScore) / log(1 - thresh));
  static double _volToThresh(double volume) => min(0.4 + 10 * volume, 0.8);
  static double _adjustScoreByVol(double score, double volume) =>
      _adjustScore(score, _volToThresh(volume));

  double call(double t) {
    // Run the Pipeline and check the hash. Return a score based on how close
    // the match is.
    // TODO: Avoid rebuilding this every time. It's pretty inefficient, but atm
    // we don't have a mechanism to reset it, and the chunker is stateful.
    Uint8List? hashes;
    void onHashes(int t, Float64List a, Uint8List h) {
      assert(hashes == null);
      hashes = h;
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
    final slice = getAudioSlice(t);
    if (slice == null) return -1;
    pipeline.onDataF64((t * 1000).toInt(), slice);

    //if (hashes == null) return -1;
    final score = _calculateScore(_target, hashes!);
    //print('$t,$score');
    return score;
  }

  static double _calculateScore(Uint8List a, Uint8List b) {
    // TODO: Verify the volume.
    //if (a.length != b.length) return -1;
    assert(a.length == b.length);
    final volume = Hasher.u32ToVol(
        ByteData.sublistView(a).getUint32(0, Endian.big));
    int sum = 0;
    for (int i = 4; i < a.length; ++i) {
      sum += _bitCountUint8(0xFF & ~(a[i] ^ b[i]));
    }
    final score = sum / (8.0 * a.length);
    return _adjustScoreByVol(score, volume);
  }

  static int _bitCountUint8(int x) {
    x = x - ((x >> 1) & 0x55);
    x = (x & 0x33) + ((x >> 2) & 0x33);
    return (x + (x >> 4)) & 0x0F;
  }

  Float64List? getAudioSlice(double t) {
    final firstSample = ((t - _chunkStartTimeSec) * _hashSampleRate).toInt();
    if (firstSample < 0) return null;
    final lastSample = firstSample + _chunkSize;
    if (lastSample > _possibleChunk.length) return null;
    return Float64List.sublistView(_possibleChunk, firstSample, lastSample);
  }
}

class SafCodeHeader {
  // TODO: Merge this with the Metadata class.
  final int version;
  final int algorithm;
  final int timeMs;

  SafCodeHeader(this.version, this.algorithm, this.timeMs);

  static const int length = Metadata.length;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timeMs, isUtc: true);

  static SafCodeHeader? decode(Uint8List code) {
    if (code.length < Metadata.length) return null;

    for (int i = 0; i < kMagicString.length; ++i) {
      if (code[i] != kMagicString.codeUnitAt(i)) return null;
    }

    final bytes = ByteData.sublistView(code);
    final version = bytes.getUint8(kMagicString.length);
    final algorithm = bytes.getUint8(kMagicString.length + 1);
    final timeMs = bytes.getUint64(kMagicString.length + 2, Endian.big);
    return SafCodeHeader(version, algorithm, timeMs);
  }
}

class AudioMatch {
  final Float64List matchedAudio;
  final double audioTime;
  final double relativeLatency;
  final double speed;
  AudioMatch(
      this.matchedAudio, this.audioTime, this.relativeLatency, this.speed);
}

class VerifierResult {
  final Uint8List safCode;
  final VerifierStatus error;
  final double score;

  // Present for any error except codeError.
  final SafCodeHeader? header;

  // Present only if error is ok or speedError
  final AudioMatch? audio;

  VerifierResult(this.safCode, this.error, this.score, [this.header, this.audio]);

  String toString() => error.toString();
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
  // indicate a valid edit point.
  // TODO: Should we check the audio hash anyway?
  sequenceError,

  // The hash doesn't match the audio, or is malformed.
  hashError,

  // The audio is too slow or too fast. Check VerifierResult.audio.speed.
  speedError,
}

class _TimingEstimate {
  double minAudioTimeSec;
  double? estAudioTimeSec;
  double? targetAudioTimeSec;
  double maxAudioTimeSec;
  _TimingEstimate(
      this.minAudioTimeSec, this.estAudioTimeSec,
      this.targetAudioTimeSec, this.maxAudioTimeSec);
  String toString() => '{$minAudioTimeSec, $estAudioTimeSec, $maxAudioTimeSec}';
}

class _TimingEstimator {
  int? _lastCodeTimeMs;
  double _lastAudioTimeSec = 0;
  double _currentSpeed = 1; // > 1 means audio is fast.

  static const double _speedSmoothingFactor = 0.3;

  int? get lastCodeTimeMs => _lastCodeTimeMs;

  _TimingEstimate estimateAudioTime(int codeTimeMs) {
    final lastCodeTime = _lastCodeTimeMs;
    if (lastCodeTime == null) return _TimingEstimate(0, null, null, 1);
    final codeDtSec = (codeTimeMs - lastCodeTime) / 1000.0;
    return _TimingEstimate(
      _lastAudioTimeSec + codeDtSec * _minDetectableSpeed,
      _lastAudioTimeSec + codeDtSec * _currentSpeed,
      _lastAudioTimeSec + codeDtSec,
      _lastAudioTimeSec + codeDtSec * _maxDetectableSpeed,
    );
  }

  void setTime(double audioTimeSec, int codeTimeMs) {
    final lastCodeTime = _lastCodeTimeMs;
    if (lastCodeTime != null) {
      final audioDtSec = audioTimeSec - _lastAudioTimeSec;
      final codeDtSec = (codeTimeMs - lastCodeTime) / 1000.0;
      final speed = audioDtSec / codeDtSec;
      _currentSpeed += _speedSmoothingFactor * (speed - _currentSpeed);
    }
    _lastCodeTimeMs = codeTimeMs;
    _lastAudioTimeSec = audioTimeSec;
  }

  double get estimateSpeed => _currentSpeed;
}
