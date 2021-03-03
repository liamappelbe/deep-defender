# Copyright 2021 The Deep Defender Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Creates test data to verify that the spectrograms and embeddings calculated by
# the Flutter app are the same as the TensorFlow results.

# Usage:
# python testData.py savedModelFolder

# I ran this in Python 3.8, with these pip packages:
#    tensorflow
#    tensorflow_io

import sys
import tensorflow as tf
import tensorflow.keras as kr
import tensorflow_io as tfio

kInputFiles = "common-voice/*/*/*.clean.wav"
kSpectrogramFile = "spectrograms.txt"
kEmbeddingFile = "embeddings.txt"
kInputSampleRate = 16000
kTrainingSampleRate = 4096
kWindowSize = 1
kMaxDesync = 0.01
kWindowSamples = int(kWindowSize * kTrainingSampleRate)
kMaxDesyncSamples = int(kMaxDesync * kTrainingSampleRate)
kWavSamples = int(kWindowSamples + kMaxDesyncSamples)
kInputWavSamples = int(kWavSamples * kInputSampleRate / kTrainingSampleRate)
kNumExamples = 10

def spectrogram(filename):
  w, _ = tf.audio.decode_wav(tf.io.read_file(filename), 1, kInputWavSamples)
  w = tf.squeeze(w, axis=-1)
  if kInputSampleRate != kTrainingSampleRate:
    w = tfio.audio.resample(w, kInputSampleRate, kTrainingSampleRate)
  size = tf.shape(w)[0]
  if size < kTrainingSampleRate:
    w = tf.pad(w, [[0, 0], [kTrainingSampleRate - size, 0]])
  elif size > kTrainingSampleRate:
    w = tf.slice(w, [0], [kTrainingSampleRate])
  s = tf.abs(tf.signal.stft(w, frame_length=128, frame_step=64))
  return w, s

filenames = tf.random.shuffle(tf.io.gfile.glob(kInputFiles))[:kNumExamples]
filesDS = tf.data.Dataset.from_tensor_slices(filenames)
specDS = filesDS.map(spectrogram, num_parallel_calls=tf.data.AUTOTUNE)

with open(kSpectrogramFile, "w") as f:
  for w, s in specDS:
    lw = list(w.numpy())
    ls = list(tf.reshape(s, [-1]).numpy())
    assert(len(lw) == kTrainingSampleRate)
    assert(len(ls) == 63 * 65)
    f.write("  [Float32List.fromList(%r), Float32List.fromList(%r)],\n" % (
        lw, ls))

model = kr.models.load_model(sys.argv[1])

with open(kEmbeddingFile, "w") as f:
  for w, s in specDS:
    e = model.predict(tf.reshape(s, [1, 63, 65, 1]))
    ls = list(tf.reshape(s, [-1]).numpy())
    le = list(e.flat)
    assert(len(le) == 32)
    f.write("  {{%s}, {%s}},\n" % (
        ", ".join(["%rf" %x for x in ls]), ", ".join(["%rf" %x for x in le])))
