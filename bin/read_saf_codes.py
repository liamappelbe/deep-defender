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
# python read_saf_codes.py input.mp4
# python read_saf_codes.py input.png

# I ran this in Python 3.8 on Linux (WSL), with these pip packages:
#    ffmpeg-python
#    imageio
#    numpy
#    zbar-py

import base64
import ffmpeg
import imageio
import math
import numpy as np
import sys
import wave
import zbar

from Crypto.Hash import SHA256
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15

kAudioInputSampleRate = 16000

def isVideo(filename):
  try:
    return ffmpeg.probe(sys.argv[1])['streams'][0]['duration'] is not None
  except:
    return False

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

def decodeZbarData(data):
  # Zbar UTF-8 encodes even binary data, so we have to fiddle with it a bit.
  return [ord(c) for c in data.decode('utf-8', 'strict')]

class SAFCode:
  def __init__(self, data, start):
    self.data = data
    self.start = start
    self.end = start + 1  # Frame range is left-inclusive.

  def extendSpan(self, newEnd):
    self.end = newEnd + 1

  def report(self, frameRate):
    s = int(self.start * 1000 / frameRate) if frameRate is not None else 0
    e = int(self.end * 1000 / frameRate) if frameRate is not None else 0
    c = base64.urlsafe_b64encode(bytes(self.data))
    return '%d ms to %d ms: %s\n' % (s, e, c)

def hasSAFCodePrefix(data):
  return data[0] == 83 and data[1] == 65 and data[2] == 70

__scanner = zbar.Scanner()
def scanSAFCode(grayscaleFrame):
  results = __scanner.scan(grayscaleFrame)
  if len(results) == 0:
    return None
  result = results[0]
  if result.type != 'QR-Code':
    return None
  data = decodeZbarData(result.data)
  if not hasSAFCodePrefix(data):
    return None
  return data

def findAllSAFCodes(video):
  safCodes = []
  prev = None
  prevpcnt = 0
  for i in range(len(video)):
    pcnt = int(i * 100.0 / len(video))
    if pcnt != prevpcnt:
      print('%d%%' % pcnt)
      prevpcnt = pcnt
    frame = video[i]
    data = scanSAFCode(frame)
    if data is None:
      continue
    if prev is not None and data == prev.data:
      prev.extendSpan(i)
    else:
      prev = SAFCode(data, i)
      safCodes.append(prev)
  return safCodes

def writeReport(safCodes, outFile, frameRate):
  with open(outFile, 'w') as f:
    for saf in safCodes:
      f.write(saf.report(frameRate))

def toI16(x):
  return int(min(max(x * 32768, -32768), 32767))

def writeWav(name, o):
  with wave.open(name, "wb") as wo:
    wo.setnchannels(1)
    wo.setsampwidth(2)
    wo.setframerate(kAudioInputSampleRate)
    wo.writeframes(b"".join([
        toI16(i).to_bytes(2, byteorder='little', signed=True) for i in o]))

def readVideoSAFCodes(inFile, outFile, audioOutFile):
  print("=== LOADING VIDEO ===")
  audio, video, frameRate = readVideo(inFile)
  writeWav(audioOutFile, audio)
  print("\n=== SEARCHING FOR SAF CODES ===")
  safCodes = findAllSAFCodes(video)
  if len(safCodes) == 0:
    print('ERROR: No SAF codes found')
    return
  print("\n=== WRITING REPORT ===")
  writeReport(safCodes, outFile, frameRate)

def grayscale(im):
  return im[:, :, :3].mean(2).astype(np.uint8)

def readImageSAFCode(inFile):
  print("=== LOADING IMAGE ===")
  im = imageio.v3.imread(inFile)
  data = scanSAFCode(grayscale(im))
  if data is None:
    print("\n=== NO SAF CODE ===")
  else:
    print("\n=== FOUND SAF CODE ===")
    print(SAFCode(data, 0).report(None))

def readFile(filename):
  if isVideo(filename):
    readVideoSAFCodes(filename, filename + '.safcodes.txt', filename + '.wav')
  else:
    readImageSAFCode(filename)

readFile(sys.argv[1])
