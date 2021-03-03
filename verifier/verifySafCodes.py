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

# Verifies the SAF codes in a video, and produces a report about each chunk. The
# report is saved as "${input}.report.txt".

# This tool uses ffmpeg, which must be installed separately and available in
# the PATH variable (ie, the commands `ffmpeg` and `ffprobe` alone must work).

# Usage:
# python verifySafCodes.py input.mp4 publicKey.json model.tflite

# I ran this in Python 3.8, with these pip packages:
#    ffmpeg-python
#    matplotlib
#    numpy
#    pycryptodome
#    tensorflow
#    tensorflow_io
#    zbar-py
# I wan't able to get some of these packages running on Windows. I ended up just
# running on WSL instead. Even if you don't have WSL installed yet, it would
# probably be easier to do a fresh install WSL and run there, rather than trying
# to get these packages to run on Windows :P

import base64
import ffmpeg
import json
import math
import numpy as np
import sys
import tensorflow as tf
import tensorflow.keras as kr
import tensorflow_io as tfio
import wave
import zbar

from Crypto.Hash import SHA256
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15

kAudioInputSampleRate = 16000
kAudioSampleRate = 4096
kChunkSize = 1
kChunkOverlap = 0.125
kMaxAllowedDesyncBroad = 0.5
kMaxAllowedDesyncFine = 0.1
kTargetRmsVolume = 0.1
kChunkSamples = int(kChunkSize * kAudioSampleRate)

def rmsNormalize(a):
  if len(a) == 0:
    return []
  squareSum = 0
  for x in a:
    squareSum += x * x
  m = 1
  if squareSum > 0:
    m = kTargetRmsVolume / math.sqrt(squareSum / len(a))
  return [x * m for x in a]

def getVideoInfo(filename):
  info = ffmpeg.probe(filename)
  for stream in info['streams']:
    if stream['codec_type'] == 'video':
      frn, frd = stream['avg_frame_rate'].split('/')
      return stream['width'], stream['height'], float(frn) / float(frd)

def readVideo(filename):
  width, height, frameRate = getVideoInfo(filename)

  rawAudio, _ = (ffmpeg
    .input(filename)
    .output('pipe:', format='s16le', acodec='pcm_s16le', ac=1,
        ar=str(kAudioInputSampleRate))
    .run(capture_stdout=True))
  audio = np.frombuffer(rawAudio, np.int16) / 0x8000

  rawVideo, _ = (ffmpeg
    .input(filename)
    .output('pipe:', format='rawvideo', pix_fmt='gray')
    .run(capture_stdout=True))
  video = np.frombuffer(rawVideo, np.uint8).reshape([-1, height, width])

  return audio, video, frameRate

def toI16(x):
  return int(min(max(x * 32768, -32768), 32767))

def writeWav(name, o):
  with wave.open(name, "wb") as wo:
    wo.setnchannels(1)
    wo.setsampwidth(2)
    wo.setframerate(kAudioSampleRate)
    wo.writeframes(b"".join([
        toI16(i).to_bytes(2, byteorder='little', signed=True) for i in o]))

def decodeBase64UrlUint(s):
  return int.from_bytes(base64.urlsafe_b64decode(s), byteorder='big')

def decodeZbarData(data):
  # Zbar UTF-8 encodes even binary data, so we have to fiddle with it a bit.
  return [ord(c) for c in data.decode('utf-8', 'strict')]

def getUint(data, i, w):
  x = 0
  for _ in range(w):
    x *= 0x100
    x += data[i]
    i += 1
  return x, i

class SafCode:
  def __init__(self, data, start, prev):
    self.data = data
    self.start = start
    self.end = start + 1  # Frame range is left-inclusive.
    self.prev = prev
    i = 3  # Skip magix string prefix.
    self.version, i = getUint(data, i, 2)
    self.algorithm, i = getUint(data, i, 2)
    self.timestamp, i = getUint(data, i, 8)
    self.timestamp /= 1000  # Convert timestamp from ms to s.
    self.fingerprint = []
    for j in range(32):
      x, i = getUint(data, i, 3)
      self.fingerprint.append(x / 0x1000000)
    self.signableData = bytearray(data[:i])
    self.signature = bytearray(data[i:])
    self.report = []
    self.fatalError = False
    self.calculatedFingerprint = None

  def extendSpan(self, newEnd):
    self.end = newEnd + 1

  def reportInvalidSignature(self):
    self.report.append('FATAL: Inavlid signature')
    # Separate category of error, due to severity. Disables all other checks.
    self.fatalError = True

  def reportBadTimestampBroad(self, error):
    # Negative values indicate too early. Positive indicate too late.
    if error < kChunkOverlap - kChunkSize:
      self.report.append(
          "CRITICAL: Out of order because it's %f seconds early" % (-error))
    elif error < 0:
      self.report.append('CRITICAL: %f seconds early' % (-error))
    else:
      self.report.append('CRITICAL: %f seconds late' % error)

  def reportBadTimestampFine(self, error):
    # Negative values indicate too early. Positive indicate too late.
    error *= 1000
    if error < 0:
      self.report.append('SEVERE: %f ms early' % (-error))
    else:
      self.report.append('SEVERE: %f ms late' % error)

  def reportTooEarlyToVerify(self, time):
    self.report.append('WARNING: This chunk started recording ' +
        '%s seconds before the video, so it cannot be verified' % (-time))

  def reportErrorValue(self, value):
    self.report.append('Error value: %.2f%%' % (value * 100))

def hasSAFCodePrefix(data):
  return data[0] == 83 and data[1] == 65 and data[2] == 70

def findAllSAFCodes(video):
  scanner = zbar.Scanner()
  safCodes = []
  prev = None
  for i in range(len(video)):
    frame = video[i]
    results = scanner.scan(frame)
    if len(results) == 0:
      continue
    result = results[0]
    if result.type != 'QR-Code':
      continue
    data = decodeZbarData(result.data)
    if len(data) != 367 or not hasSAFCodePrefix(data):
      continue
    if prev is not None and data == prev.data:
      prev.extendSpan(i)
    else:
      prev = SafCode(data, i, prev)
      safCodes.append(prev)
  return safCodes

def readKey(filename):
  with open(filename, mode='r') as f:
    jwk = json.loads(f.read())
    n = decodeBase64UrlUint(jwk['n'])
    e = decodeBase64UrlUint(jwk['e'])
    return RSA.construct([n, e])

def checkSignatures(safCodes, key):
  verifier = pkcs1_15.new(key)
  for saf in safCodes:
    h = SHA256.new()
    h.update(saf.signableData)
    try:
      verifier.verify(h, saf.signature)
    except ValueError:
      saf.reportInvalidSignature()

def calcOffset(saf, frameRate):
  # The SAF code's timestamp measures the start of its audio chunk. This is 1
  # second before the end frame of the previous SAF code. This is 2 different
  # measurements of the same moment, so we can use this to calculate the offset
  # between the frame numbers and the timestamps.
  chunkStartFrameTime = (saf.prev.end / frameRate) - kChunkSize
  return saf.timestamp - chunkStartFrameTime

def checkTimestampsBroad(safCodes):
  # Check that the SAF code timestamps increase by about the right amount.
  inc = kChunkSize - kChunkOverlap
  for saf in safCodes:
    if len(saf.report) == 0 and saf.prev is not None:
      expectedTimestamp = saf.prev.timestamp + inc
      error = saf.timestamp - expectedTimestamp
      if abs(error) > kMaxAllowedDesyncBroad:
        saf.reportBadTimestampBroad(error)

def checkTimestampsFine(safCodes, frameRate):
  # There are 2 timing systems:
  #   - The timestamps in the SAF codes
  #   - The frame numbers
  # If everything is ok, these should line up, just with some constant offset.
  # Calculate that offset for each SAF code, and report any SAF codes whose
  # offset differs too much from the others. Return the average offset.
  # Note: We're ignoring any SAF codes that are already reported, and also
  # ignoring the first one.
  offsets = { saf: calcOffset(saf, frameRate) for saf in safCodes
      if len(saf.report) == 0 and saf.prev is not None }
  averageOffset = safCodes[0].timestamp
  while offsets:
    averageOffset = sum(offsets.values()) / len(offsets)
    allGood = True
    for saf, offset in offsets.items():
      error = offset - averageOffset
      if abs(error) > kMaxAllowedDesyncFine:
        saf.reportBadTimestampFine(error)
        del offsets[saf]
        allGood = False
    if allGood:
      break
  return averageOffset

model = tf.lite.Interpreter(model_path=sys.argv[3])
model.allocate_tensors()
def calculateFingerprint(audioChunk):
  s = tf.abs(tf.signal.stft(audioChunk, frame_length=128, frame_step=64))
  model.set_tensor(
      model.get_input_details()[0]['index'], tf.reshape(s, [1, 63, 65, 1]))
  model.invoke()
  e = model.get_tensor(model.get_output_details()[0]['index'])
  return list(e.flat)

def calculateAllFingerprints(audio, safCodes, averageOffset):
  # Get the corresponding audio chunk for each SAF code.
  a = tfio.audio.resample(tf.convert_to_tensor(audio, dtype=tf.float32),
      kAudioInputSampleRate, kAudioSampleRate)
  i = 0
  for saf in safCodes:
    i += 1
    if not saf.fatalError:
      startFrameTime = saf.timestamp - averageOffset
      if startFrameTime < 0:
        saf.reportTooEarlyToVerify(startFrameTime)
        continue
      startSample = int(startFrameTime * kAudioSampleRate)
      endSample = int(startSample + kChunkSamples)
      # We shouldn't have a SAF code for audio chunks that end after the video.
      if endSample >= len(a):
        continue
      # writeWav(str(i) + ".wav", a[startSample:endSample])
      saf.calculatedFingerprint = calculateFingerprint(
          a[startSample:endSample])

def checkFingerprints(safCodes):
  m, n = 0, 0
  for saf in safCodes:
    if saf.calculatedFingerprint is not None:
      assert(len(saf.calculatedFingerprint) == len(saf.fingerprint))
      s = 0
      for i in range(len(saf.fingerprint)):
        d = saf.fingerprint[i] - saf.calculatedFingerprint[i]
        s += d * d
      s /= len(saf.fingerprint)
      saf.reportErrorValue(s)
      n += 1
      m += s
  return m / n if n > 0 else 0

def writeReport(safCodes, outFile, averageOffset):
  with open(outFile, 'w') as f:
    for saf in safCodes:
      start = saf.timestamp - averageOffset
      end = start + kChunkSize
      f.write('Chunk from %.2f to %.2f: %s\n' % (
          start, end, '\t'.join(saf.report)))

def verify(inFile, keyFile, outFile):
  audio, video, frameRate = readVideo(inFile)
  safCodes = findAllSAFCodes(video)
  if len(safCodes) == 0:
    print('ERROR: No SAF codes found')
    return
  checkSignatures(safCodes, readKey(keyFile))
  checkTimestampsBroad(safCodes)
  averageOffset = checkTimestampsFine(safCodes, frameRate)
  calculateAllFingerprints(audio, safCodes, averageOffset)
  meanError = checkFingerprints(safCodes)
  # print(meanError)
  # for i in range(100):
  #   doff = 3 * (i / 100 - 0.5) * kMaxAllowedDesyncFine
  #   calculateAllFingerprints(audio, safCodes, averageOffset + doff)
  #   meanError = checkFingerprints(safCodes)
  #   print(doff, meanError)
  # print([saf.report for saf in safCodes])
  writeReport(safCodes, outFile, averageOffset)

verify(sys.argv[1], sys.argv[2], sys.argv[1] + '.report.txt')
