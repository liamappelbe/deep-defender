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

# Trains the embedder and saves the model as a folder and a tflite file. Output
# name is "model-${accuracy}".

# Usage:
# python train.py

import matplotlib.pyplot as plt
import numpy as np
import os
import tensorflow as tf
import tensorflow.keras as kr
import tensorflow_io as tfio


##############
### CONFIG ###
##############

# Uncomment to run on CPU. Slower training, but nicer error messages.
# os.environ['CUDA_VISIBLE_DEVICES'] = '-1'

kInputFiles = "common-voice/*/*/*.clean.wav"
kModelOutPath = "model-%.6f"
kInputSampleRate = 16000
kWindowSize = 1
kUseSpectrograms = True
kTrainingSampleRate = 4096

kLearningRate = 0.0001
kDropout = 0.25
kBatchSize = 64
kShuffleBufferSize = 10000
kMiniShuffleBufferSize = 100
kEpochs = 100
kNumDatasetCopies = 1
kMaxTrainingFiles = float('inf')  # 10000

kMatchOutput = 0
kMismatchOutput = 1

kMinVolume = 0.3
kMaxNoise = 0.1
kMaxDesync = 0.01
# TODO: Filtering params.
# TODO: Malicious edit params.

kWindowSamples = int(kWindowSize * kTrainingSampleRate)
kMaxDesyncSamples = int(kMaxDesync * kTrainingSampleRate)
kWavSamples = int(kWindowSamples + kMaxDesyncSamples)
kInputWavSamples = int(kWavSamples * kInputSampleRate / kTrainingSampleRate)

kTotalLayers = 1
kLayerSizes = [1000, 300, 100]
kEmbeddingSize = 32

kUseOutputLayers = False
kNumConvLayers = 1

kLayerKernelSizes = [64, 32, 16]
kConvLayerSizes = [16, 16, 128]
kMaxPoolSizes = [2, 2, 2]
kInputLayerSize = [kWindowSamples, 1]
kResizeSpectrogram = False
kResizeUsingAveragePooling = True
kResizeUsingAveragePoolingWithConvLayer = True
kResizedSpectrogramSize = 16
kResizeAveragePoolingSize = 4

if kUseSpectrograms:
  kLayerKernelSizes = [3, 3, 3]
  kInputLayerSize = [63, 65, 1]
  kResizeSpectrogram = True

seed = 47
tf.random.set_seed(seed)
np.random.seed(seed)

kCache = "cached-dataset-" + str(seed) + ("-spec" if kUseSpectrograms else "")

for i in range(kNumConvLayers):
  kLayerSizes[i] = kConvLayerSizes[i]


#############
### UTILS ###
#############

def loadWav(filename):
  w, _ = tf.audio.decode_wav(tf.io.read_file(filename), 1, kInputWavSamples)
  w = tf.squeeze(w, axis=-1)
  if kInputSampleRate != kTrainingSampleRate:
    w = tfio.audio.resample(w, kInputSampleRate, kTrainingSampleRate)
  return w

def pseudoShuffle(size):
  a = list(range(size))
  for i in range(size):
    j = np.random.randint(
        (i + 1 if i < size - 1 else 0) if a[i] == i else i, size)
    x = a[i]
    a[i] = a[j]
    a[j] = x
  assert(not any([i == x for i, x in enumerate(a)]))
  t = tf.convert_to_tensor(a, dtype=tf.int64)
  return tf.data.Dataset.from_tensor_slices(t)

def constDS(size, value, name):
  return tf.data.Dataset.from_tensor_slices(
      tf.constant(value, shape=[size], name=name))

def randfDS(size, lo, hi, name):
  return tf.data.Dataset.from_tensor_slices(
      tf.random.uniform(shape=[size], minval=lo, maxval=hi, name=name))

def concatDS(datasets):
  ds = datasets[0]
  for d in datasets[1:]:
    ds = ds.concatenate(d)
  return ds

def joinLayers(layers, i):
  for l in layers:
    i = l(i)
  return i

def getShape(ds):
  for d, _ in ds.take(1):
    return d.shape


###############
### DATASET ###
###############

def tweak(w, volume, noise, desync):
  n = tf.random.uniform(
      shape=[kWindowSamples], minval=-noise, maxval=noise, name="noise")
  ww = tf.slice(w, [int(desync)], [kWindowSamples], name="windowed")
  wn = tf.math.add(ww, n, name="withNoise")
  wt = tf.math.scalar_mul(volume, wn, name="withVolume")
  if kUseSpectrograms:
    return tf.abs(tf.signal.stft(wt, frame_length=128, frame_step=64))
  else:
    return wt

def tweakDS(wavDS, size, windowDS = None):
  volumeDS = randfDS(size, kMinVolume, 1, "tweakVolume")
  noiseDS = randfDS(size, 0, kMaxNoise, "tweakNoise")
  desyncDS = randfDS(size, 0, kMaxDesyncSamples, "tweakDesync")
  zipDS = tf.data.Dataset.zip((wavDS, volumeDS, noiseDS, desyncDS))
  return zipDS.map(tweak, num_parallel_calls=tf.data.AUTOTUNE)

def createDataset(filenames, name):
  size = len(filenames)
  filesDS = tf.data.Dataset.from_tensor_slices(filenames)
  wavDS = filesDS.map(loadWav, num_parallel_calls=tf.data.AUTOTUNE)
  wavDS = wavDS.cache().prefetch(tf.data.AUTOTUNE)

  datasets = []
  for i in range(kNumDatasetCopies):
    datasets.append(tf.data.Dataset.zip((tf.data.Dataset.zip((
        tweakDS(wavDS, size), tweakDS(wavDS, size))),
            constDS(size, kMatchOutput, "matchOutput" + str(i)))))

    mismatchLeftDS = tweakDS(wavDS, size)
    # mismatchRightDS = tf.data.experimental.choose_from_datasets(
    #     tweakDS(wavDS, size), pseudoShuffle(size))
    mismatchRightDS = tweakDS(wavDS, size).shuffle(kShuffleBufferSize)
    datasets.append(tf.data.Dataset.zip((tf.data.Dataset.zip((
        mismatchLeftDS, mismatchRightDS)),
            constDS(size, kMismatchOutput, "mismatchOutput" + str(i)))))

    # TODO: Malicious edit dataset

  ds = concatDS(datasets).batch(kBatchSize)
  ds = ds.cache(kCache + "-" + name).prefetch(tf.data.AUTOTUNE)
  ds = ds.shuffle(kShuffleBufferSize, reshuffle_each_iteration = False).cache()
  return ds.shuffle(kMiniShuffleBufferSize)


#############
### MODEL ###
#############

def buildModel():
  layers = []
  if kResizeSpectrogram:
    if kResizeUsingAveragePooling:
      if kResizeUsingAveragePoolingWithConvLayer:
        layers.append(kr.layers.Conv2D(
            1, 1 + kResizeAveragePoolingSize, activation="relu"))
      layers.append(kr.layers.AveragePooling2D(
          pool_size=kResizeAveragePoolingSize))
    else:
      layers.append(kr.layers.experimental.preprocessing.Resizing(
          kResizedSpectrogramSize, kResizedSpectrogramSize))
  for i in range(kTotalLayers):
    if i < kNumConvLayers:
      if kUseSpectrograms:
        layers.append(kr.layers.Conv2D(
            kLayerSizes[i], kLayerKernelSizes[i], activation="relu"))
      else:
        layers.append(kr.layers.Conv1D(
            kLayerSizes[i], kLayerKernelSizes[i], activation="relu"))
      layers.append(kr.layers.MaxPooling2D(pool_size=kMaxPoolSizes[i]))
    else:
      layers.append(kr.layers.Dense(kLayerSizes[i], activation="relu"))
    if kNumConvLayers > 0 and i == kNumConvLayers - 1:
      layers.append(kr.layers.Flatten())
    layers.append(kr.layers.Dropout(kDropout))
  layers.append(kr.layers.Dense(kEmbeddingSize, activation="sigmoid"))
  ins = []
  embs = []
  for _ in range(2):
    i = kr.Input(shape=kInputLayerSize)
    ins.append(i)
    embs.append(joinLayers(layers, i))
  out = None
  if kUseOutputLayers:
    finalLayer = kr.layers.Dense(1)
    out = finalLayer(kr.layers.concatenate(embs))
  else:
    sub = kr.layers.subtract(embs)
    clamp = kr.layers.ReLU(max_value=1.0)
    out = clamp(kr.layers.dot([sub, sub], axes=1))
  return kr.models.Model(inputs=ins, outputs=out)

def cutEmbedderOutOfModel(model):
  noInputLayer = True
  inputShape = None
  layers = []
  for layer in model.layers:
    if isinstance(layer, kr.layers.Dropout):
      # Skip any dropout layers.
      continue
    elif isinstance(layer, kr.layers.experimental.preprocessing.Resizing):
      # If there is a resizing layer, assume it's the first
      # Skip any resizing layers, because they're not supported by tflite. We'll
      # have to manually resize the inputs on the device. Add an input layer
      # instead of the resize layer.
      assert(len(layers) == 1)
      assert(isinstance(layers[0], kr.layers.InputLayer))
      layers = [kr.Input(shape=layer.output_shape[1:])]
      continue
    elif isinstance(layer, kr.layers.InputLayer):
      # Skip any input layers. Since we're removing the resizing layer, the
      # input size is wrong. It's ok though, because sequential models don't
      # need explicit input layers.
      assert(len(layers) <= 1)
      if len(layers) == 0:
        layers.append(layer)
      continue
    elif isinstance(layer, kr.layers.Subtract):
      # Subtraction layer comes right after the embedder, so stop.
      break
    layers.append(layer)
  return kr.Sequential(layers)


###########
### GO! ###
###########

filenames = tf.random.shuffle(tf.io.gfile.glob(kInputFiles))
if len(filenames) > kMaxTrainingFiles:
  filenames = filenames[:kMaxTrainingFiles]
print("Total examples:", len(filenames))

numTest = int(0.1 * len(filenames))
testFiles = filenames[:numTest]
valFiles = filenames[numTest:2*numTest]
trainFiles = filenames[2*numTest:]
print("Training set size:", len(trainFiles))
print("Validation set size:", len(valFiles))
print("Test set size:", len(testFiles))

trainDS = createDataset(trainFiles, "train")
valDS = createDataset(valFiles, "val")
testDS = createDataset(testFiles, "test")

model = buildModel()
model.summary()
model.compile(
    optimizer=kr.optimizers.Adam(kLearningRate),
    loss=kr.losses.BinaryCrossentropy(),
    metrics=["accuracy"])
history = model.fit(
    trainDS,
    validation_data=valDS,
    epochs=kEpochs,
    callbacks=kr.callbacks.EarlyStopping(
        verbose=1, patience=10, restore_best_weights=True),
)
_, testAccuracy = model.evaluate(testDS)
print("Accuracy on the test set: %.6f" % testAccuracy)

embedderModel = cutEmbedderOutOfModel(model)
embedderModel.summary()
outName = kModelOutPath % testAccuracy
embedderModel.save(outName)

tfliteModel = tf.lite.TFLiteConverter.from_saved_model(outName).convert()
with open(outName + '.tflite', 'wb') as f:
  f.write(tfliteModel)

metrics = history.history
plt.plot(history.epoch, metrics["loss"], metrics["val_loss"])
plt.legend(["loss", "val_loss"])
plt.show()
