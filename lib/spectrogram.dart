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

import 'dart:typed_data';
import 'package:fft/fft.dart';
import 'microphone.dart';

// Generates the spectrogram of the given audio signal. The output buffer is
// overwritten each time, so don't rely on its values staying the same. If you
// need the data to persist, make a copy of it.
class Spectrogram {
  static const int kInputSize = Microphone.kChunkSize;
  static const int kFrame = 128;
  static const int kStep = 64;
  static const int kFftSize = kFrame ~/ 2  + 1;
  static const int kNumFrames = (kInputSize - kFrame) ~/ kStep + 1;
  static const int kOutputSize = kNumFrames * kFftSize;

  final _spec = Float32List(kOutputSize);
  final _fft = FFT();
  final _win = Window(WindowType.HANN);

  Float32List run(Float32List audio) {
    // Reproducing this Python TensorFlow code:
    // tf.abs(tf.signal.stft(wt, frame_length=128, frame_step=64))
    for (var i = 0, j = 0; ; i += kStep) {
      final ii = i + kFrame;
      if (ii > audio.length) {
        assert(ii == audio.length + kStep);
        assert(j == _spec.length);
        break;
      }
      final x = Float32List.sublistView(audio, i, ii);
      final f = _fft.Transform(_win.apply(x));
      assert(f.length == kFrame);
      // Since the input signal is real, the negative frequencies are the
      // complex conjugate of the positives. So they're redundant and we discard
      // them. Also, we only care about the amplitudes, not the phases.
      for (var k = 0; k < kFftSize; ++k) {
        // Note: f[0] is the constant offset of the signal, and should be real.
        // This check is also checking that case ;)
        assert((f[k].conjugate - f[(kFrame - k) % kFrame]).modulus < 1e-9);
        _spec[j++] = f[k].modulus;
      }
    }
    return _spec;
  }
}
