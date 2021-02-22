import math
import numpy
import random
import sys
import warnings
import wave

warnings.filterwarnings('ignore')

kSampleRate = 16000
kTargetRmsVolume = 0.1
kSilenceWindow = 0.1
kSilenceThreshold = 0.01

kWindowSize = 1
kMaxDesync = 0.01
kWindowSamples = kWindowSize * kSampleRate
kMaxDesyncSamples = kMaxDesync * kSampleRate
kWavSamples = kWindowSamples + kMaxDesyncSamples

def toI16(x):
  return int(min(max(x * 32768, -32768), 32767))

def writeWav(name, o, sampRate):
  with wave.open(name, "wb") as wo:
    wo.setnchannels(1)
    wo.setsampwidth(2)
    wo.setframerate(sampRate)
    wo.writeframes(b"".join([
        toI16(i).to_bytes(2, byteorder='little', signed=True) for i in o]))

def readWav(name):
  with wave.open(name, "rb") as w:
    assert(w.getnchannels() == 1)
    assert(w.getsampwidth() == 2)
    a = []
    wb = w.readframes(w.getnframes())
    for i in range(0, len(wb), 2):
      a.append(int.from_bytes(wb[i : i + 2], byteorder="little", signed=True))
    return a, w.getframerate()

def sq(x):
  return x * x

def rmsNormalize(a, targetRmsVolume):
  if len(a) == 0:
    return []
  squareSum = 0
  for x in a:
    squareSum += sq(x)
  m = 1
  if squareSum > 0:
    m = targetRmsVolume / math.sqrt(squareSum / len(a))
  return [x * m for x in a]

def trimSilence(a, w, t):
  tt = sq(t)
  b = []
  s = 0
  for i in range(w):
    s += sq(a[i])
  n = w
  for i in range(len(a)):
    j = i - w
    if j > 0:
      s -= sq(a[j])
      n -= 1
    j = i + w
    if j < len(a):
      s += sq(a[j])
      n += 1
    if s / n > tt:
      b.append(a[i])
  return b

def sliceRandomWindow(a, n):
  if len(a) < n:
    return a
  i = random.randrange(len(a) - n)
  return a[int(i) : int(i + n)]

inFile = sys.argv[1]
okOutFile = inFile + ".clean.wav"
badOutFile = inFile + ".weird.wav"

a, sr = readWav(inFile)
assert(sr == kSampleRate)
assert(len(a) > 100)

ok = True
oldLen = len(a)
a = trimSilence(a, int(kSilenceWindow * kSampleRate), kSilenceThreshold)
a = sliceRandomWindow(a, kWavSamples)
if len(a) != kWavSamples:
  ok = False
else:
  a = rmsNormalize(a, kTargetRmsVolume)
newLen = len(a)
removed = (oldLen - newLen) / oldLen

outFile = okOutFile if ok else badOutFile

writeWav(outFile, a, kSampleRate)
# print(inFile, " => ", outFile, "removed %.2f%%" % (100 * removed))
