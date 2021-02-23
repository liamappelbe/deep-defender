// Copyright 2021 The Deep Defender Authors
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

import 'dart:async';
import 'dart:typed_data';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';

// Calls the given callback every time a chunk of data is available from the
// microphone. The Float64List is overwritten each time, so don't rely on its
// values staying the same. If you need the data to persist, make a copy of it.
class Microphone {
  static const int kSampleRate = 4096;
  static const int kChunkSize = 1 * kSampleRate;
  static const int kOverlapSize = kSampleRate ~/ 8;
  static const double kRefreshTime = (kChunkSize - kOverlapSize) / kSampleRate;

  static Future<Microphone> mic(
      void Function(int, Float64List) callback) async {
    if (!(await Permission.microphone.request()).isGranted) {
      return null;
    }

    final stream = await MicStream.microphone(
        sampleRate: kSampleRate,
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT);
    // TODO: Handle other sample rates and bit depths by manually resampling.
    assert((await MicStream.sampleRate).toInt() == kSampleRate);
    assert((await MicStream.bitDepth) == 16);
    return Microphone._(stream, callback);
  }

  final Stream<Uint8List> _stream;
  StreamSubscription<Uint8List> _listener;
  final void Function(int, Float64List) _callback;
  final Float64List _chunk;
  int _index = 0;
  Microphone._(this._stream, this._callback)
      : _chunk = Float64List(kChunkSize) {
    _listener = _stream.listen(_onData);
  }

  void _onData(Uint8List a) {
    final b = a.buffer.asUint16List();
    for (var i = 0; i < b.length; ++i) {
      _chunk[_index] = (b[i].toDouble() * 2.0 / 0xFFFF) - 1.0;
      ++_index;
      if (_index == kChunkSize) {
        _index = kOverlapSize;
        int timeMs = DateTime.now().millisecondsSinceEpoch;
        timeMs -= (kRefreshTime * 1e3).toInt();
        _callback(timeMs, _chunk);
        _chunk.setRange(0, kOverlapSize, _chunk, kChunkSize - kOverlapSize);
      }
    }
  }

  // This version of _onData pins the timer to the number of samples received
  // from the microphone. In a sense this is more technically accurate, but for
  // some reason it falls out of sync with DateTime.now() pretty quickly.
  /*void _onData(Uint8List a) {
    final b = a.buffer.asUint16List();
    final dt = b.length.toDouble() / kSampleRate;
    if (_time == 0) {
      _time = DateTime.now().millisecondsSinceEpoch / 1e3 - dt;
    }
    for (var i = 0; i < b.length; ++i) {
      _chunk[_index] = (b[i].toDouble() * 2.0 / 0xFFFF) - 1.0;
      ++_index;
      if (_index == kChunkSize) {
        _index = kOverlapSize;
        double t = _time + (i - kChunkSize).toDouble() / kSampleRate;
        _callback((t * 1e3).toInt(), _chunk);
        _chunk.setRange(0, kOverlapSize, _chunk, kChunkSize - kOverlapSize);
      }
    }
    _time += dt;
  }*/
}
