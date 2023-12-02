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

import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'const.dart';
import 'util.dart';

class Microphone {
  static Future<Microphone?> mic(void Function(int, MicData) callback) async {
    if (!(await Permission.microphone.request()).isGranted) {
      return null;
    }

    return Microphone._(callback).._start();
  }

  final _captor = FlutterAudioCapture();
  final void Function(int, MicData) _callback;
  Microphone._(this._callback);

  Future<void> _start() => _captor.start(
        _onData,
        print,
        sampleRate: kSampleRate,
        bufferSize: 2000,
        firstDataTimeout: Duration(minutes: 1),
        waitForFirstDataOnAndroid: false,
      );

  void _onData(dynamic a) {
    _callback(DateTime.now().millisecondsSinceEpoch, a);
  }
}
