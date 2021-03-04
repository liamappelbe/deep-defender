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
# name is "model-${datetime}".

# Usage:
# python train.py

# I ran this in Python 3.8, with these pip packages:
#    matplotlib
#    numpy
#    tensorflow
#    tensorflow_io

import datetime
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
kModelOutPath = "model-%s"
kInputSampleRate = 16000
kWindowSize = 1
kUseSpectrograms = True
kTrainingSampleRate = 4096

kLearningRate = 0.0001
kDropout = 0.25
kBatchSize = 64
kShuffleBufferSize = 10000
kMiniShuffleBufferSize = 100
kEpochs = 1000
kNumDatasetCopies = 1
kMaxTrainingFiles = float('inf')  # 10000

kMatchOutput = 0
kMismatchOutput = 1

kMinVolume = 0.3
kMaxNoise = 0.1
kMaxDesync = 0.1
kMinEditSize = 0.1
kMaxEditSize = 0.5
# TODO: Filtering params.

kWindowSamples = int(kWindowSize * kTrainingSampleRate)
kMaxDesyncSamples = int(kMaxDesync * kTrainingSampleRate)
kMinEditSamples = int(kMinEditSize * kTrainingSampleRate)
kMaxEditSamples = int(kMaxEditSize * kTrainingSampleRate)

kTotalLayers = 4
kLayerSizes = [1000, 300, 100, 100]
kEmbeddingSize = 96

kUseOutputLayers = False
kNumConvLayers = 4

kLayerKernelSizes = [64, 32, 16, 8]
kConvLayerSizes = [48, 32, 24, 16]
kMaxPoolSizes = [2, 2, 2, 2]
kInputLayerSize = [kWindowSamples, 1]
kResizeSpectrogram = False
kResizeUsingAveragePooling = True
kResizeUsingAveragePoolingWithConvLayer = True
kResizedSpectrogramSize = 16
kResizeAveragePoolingSize = 4

if kUseSpectrograms:
  kLayerKernelSizes = [3, 3, 3, 3]
  kInputLayerSize = [63, 65, 1]
  kResizeSpectrogram = False

seed = 86
tf.random.set_seed(seed)
np.random.seed(seed)

kCache = "cached-dataset-" + str(seed) + ("-spec" if kUseSpectrograms else "")

for i in range(kNumConvLayers):
  kLayerSizes[i] = kConvLayerSizes[i]


#############
### UTILS ###
#############

def loadWav(filename):
  w, _ = tf.audio.decode_wav(tf.io.read_file(filename), 1)
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

def tweak(w, volume, noise, window, desync):
  size = tf.shape(w)[0]
  start = window * float(size - kMaxDesyncSamples - kWindowSamples) + desync
  ww = tf.slice(w, [int(start)], [kWindowSamples], name="windowed")
  n = tf.random.uniform(
      shape=[kWindowSamples], minval=-noise, maxval=noise, name="noise")
  wn = tf.math.add(ww, n, name="withNoise")
  return tf.math.scalar_mul(volume, wn, name="withVolume")

def spectrogram(w):
  return tf.abs(tf.signal.stft(w, frame_length=128, frame_step=64))

def maliciousEdit(w, size, pos1, pos2):
  # Swap the audio chunks at pos1 and pos2. Start by converting pos1 and pos2
  # into non-overlapping regions of size samples in w, with pos1 < pos2.
  index1 = int(pos1 * (kWindowSamples - 2 * size))
  index2 = int(pos2 * (kWindowSamples - 2 * size))
  n = int(size)
  if pos1 >= pos2:
    temp = index1
    index1 = index2
    index2 = index1
  index2 += n
  return tf.concat([
    tf.slice(w, [0], [index1], "editA"),
    tf.slice(w, [index2], [n], "editB"),
    tf.slice(w, [index1 + n], [index2 - (index1 + n)], "editC"),
    tf.slice(w, [index1], [n], "editD"),
    tf.slice(w, [index2 + n], [kWindowSamples - (index2 + n)], "editE"),
  ], 0, "maliciousEdited")

def tweakDS(wavDS, size, windowDS = None, maliciouslyEdit = False):
  volumeDS = randfDS(size, kMinVolume, 1, "tweakVolume")
  noiseDS = randfDS(size, 0, kMaxNoise, "tweakNoise")
  if windowDS is None:
    windowDS = randfDS(size, 0, 1, "tweakWindow")
  desyncDS = randfDS(size, 0, kMaxDesyncSamples, "tweakDesync")
  zip1DS = tf.data.Dataset.zip((wavDS, volumeDS, noiseDS, windowDS, desyncDS))
  outDS = zip1DS.map(tweak, num_parallel_calls=tf.data.AUTOTUNE)
  if maliciouslyEdit:
    editSizeDS = randfDS(size, kMinEditSamples, kMaxEditSamples, "editSizeDS")
    editPos1DS = randfDS(size, 0, 1, "editPos1DS")
    editPos2DS = randfDS(size, 0, 1, "editPos2DS")
    zip2DS = tf.data.Dataset.zip((outDS, editSizeDS, editPos1DS, editPos2DS))
    outDS = zip2DS.map(maliciousEdit, num_parallel_calls=tf.data.AUTOTUNE)
  if kUseSpectrograms:
    outDS = outDS.map(spectrogram, num_parallel_calls=tf.data.AUTOTUNE)
  return outDS, windowDS

def createDataset(filenames, name):
  size = len(filenames)
  filesDS = tf.data.Dataset.from_tensor_slices(filenames)
  wavDS = filesDS.map(loadWav, num_parallel_calls=tf.data.AUTOTUNE)
  wavDS = wavDS.cache().prefetch(tf.data.AUTOTUNE)

  datasets = []
  for i in range(kNumDatasetCopies):
    # Matching data set
    matchLeft, matchWindow = tweakDS(wavDS, size)
    matchRight = tweakDS(wavDS, size, matchWindow)[0]
    datasets.append(tf.data.Dataset.zip((tf.data.Dataset.zip((
        matchLeft, matchRight)),
            constDS(size, kMatchOutput, "matchOutput" + str(i)))))

    # Mismatched data set
    mismatchLeftDS = tweakDS(wavDS, size)[0]
    # mismatchRightDS = tf.data.experimental.choose_from_datasets(
    #     tweakDS(wavDS, size), pseudoShuffle(size))
    mismatchRightDS = tweakDS(wavDS, size)[0].shuffle(kShuffleBufferSize)
    datasets.append(tf.data.Dataset.zip((tf.data.Dataset.zip((
        mismatchLeftDS, mismatchRightDS)),
            constDS(size, kMismatchOutput, "mismatchOutput" + str(i)))))

    # Another matching data set, to keep match & mismatch balanced.
    matchLeft2, matchWindow2 = tweakDS(wavDS, size)
    matchRight2 = tweakDS(wavDS, size, matchWindow2)[0]
    datasets.append(tf.data.Dataset.zip((tf.data.Dataset.zip((
        matchLeft2, matchRight2)),
            constDS(size, kMatchOutput, "matchOutput" + str(i) + "b"))))

    # Malicious edit dataset
    maliciousLeft, maliciousWindow = tweakDS(wavDS, size)
    maliciousRight = tweakDS(wavDS, size, maliciousWindow, True)[0]
    datasets.append(tf.data.Dataset.zip((tf.data.Dataset.zip((
        maliciousLeft, maliciousRight)),
            constDS(size, kMismatchOutput, "maliciousOutput" + str(i)))))

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
outName = kModelOutPath % datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
embedderModel.save(outName)

tfliteModel = tf.lite.TFLiteConverter.from_saved_model(outName).convert()
with open(outName + '.tflite', 'wb') as f:
  f.write(tfliteModel)

metrics = history.history
plt.plot(history.epoch, metrics["loss"], metrics["val_loss"])
plt.legend(["loss", "val_loss"])
plt.show()
