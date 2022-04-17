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

import 'dart:async';
import 'dart:typed_data';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'const.dart';

// Calls the given callback every time a chunk of data is available from the
// microphone.
class Microphone {
  static Future<Microphone?> mic(
      void Function(int, Uint16List) callback) async {
    if (!(await Permission.microphone.request()).isGranted) {
      return null;
    }

    final stream = await MicStream.microphone(
        sampleRate: kSampleRate,
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT);
    if (stream == null) {
      return null;
    }
    // TODO: Handle other sample rates and bit depths by manually resampling.
    assert((await MicStream.sampleRate)?.toInt() == kSampleRate);
    assert((await MicStream.bitDepth) == 16);
    return Microphone._(stream, callback);
  }

  final Stream<Uint8List> _stream;
  final void Function(int, Uint16List) _callback;
  late StreamSubscription<Uint8List> _listener;
  Microphone._(this._stream, this._callback) {
    _listener = _stream.listen(_onData);
  }

  void _onData(Uint8List a) {
    _callback(DateTime.now().millisecondsSinceEpoch, a.buffer.asUint16List());
  }
}
