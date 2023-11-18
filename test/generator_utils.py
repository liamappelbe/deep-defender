# Copyright 2023 The Deep Defender Authors
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

import numpy
import math
import random
import wave

kNumsPerLine = 4
kU64sPerLine = 3
kU8sPerLine = 11

random.seed(234875623)

def randReal(r):
  return random.uniform(-r, r)

def cplxBufStr(a):
  b = []
  for z in a:
    b.append(numpy.real(z))
    b.append(numpy.imag(z))
  return realBufStr(b)

def realBufStr(a):
  def impl(b):
    return ', '.join(['%.8f' % x for x in b])
  if len(a) <= kNumsPerLine:
    return impl(a)
  s = '\n'
  i = 0
  while i < len(a):
    j = min(i + kNumsPerLine, len(a))
    s += '        %s,' % impl(a[i:j])
    if j < len(a):
      s += ' //'
    s += '\n'
    i = j
  return s + '      '

def u64BufStr(a):
  return uintBufStr(a, kU64sPerLine)

def u8BufStr(a):
  return uintBufStr(a, kU8sPerLine)

def uintBufStr(a, perLine):
  def impl(b):
    return ', '.join(['0x%x' % x for x in b])
  if len(a) <= perLine:
    return impl(a)
  s = '\n'
  i = 0
  while i < len(a):
    j = min(i + perLine, len(a))
    s += '        %s,' % impl(a[i:j])
    if j < len(a):
      s += ' //'
    s += '\n'
    i = j
  return s + '      '

def solve(f, y, dx = 1e-9):
  x0 = 0
  x1 = 1
  y0 = f(x0)
  y1 = f(x1)
  if y0 >= y1:
    x2 = x0
    x0 = x1
    x1 = x2
    y2 = y0
    y0 = y1
    y1 = y2
  while y0 >= y:
    x0 = 2 * x0 - x1
    y0 = f(x0)
  while y1 <= y:
    x1 = 2 * x1 - x0
    y1 = f(x1)
  while abs(x1 - x0) >= dx:
    x2 = (x0 + x1) / 2
    y2 = f(x2)
    if y2 > y:
      x1 = x2
      y1 = y2
    else:
      x0 = x2
      y0 = y2
  return (x0 + x1) / 2

def logLinItr(f, n, grad0):
  def eqn(w):
    return math.exp(w * n) + (grad0 - w) * n - 1
  w = solve(eqn, f)
  g = grad0 - w
  a = []
  for i in range(1, n):
    a.append(int(math.exp(w * i) + g * i - 1))
  a.append(f)
  return a

def readMonoWav(filename, outputSampleRate):
  print("Reading " + filename)
  with wave.open(filename, "rb") as w:
    print(w.getparams())
    if w.getframerate() != outputSampleRate:
      raise "Invalid sample rate (must be %s): %s" % (
          outputSampleRate, w.getframerate())
    if w.getnchannels() < 1 or w.getnchannels() > 2:
      raise "Invalid number of channels (must be 1 or 2): %s" % w.getnchannels()
    mono = w.getnchannels() == 1
    width = w.getsampwidth()
    if width < 1 or width > 4:
      raise "Invalid bit width (must be 8, 16, 24, or 32): %s" % (width * 8)
    shift = 1 << (width * 8 - 1)
    div = shift - 0.5
    conv1 = (
        (lambda b: (int.from_bytes(b, byteorder="little") / div) - 1.0)
            if width == 1 else
        (lambda b: ((int.from_bytes(
            b, byteorder="little", signed=True) + shift) / div) - 1.0))
    conv = (conv1 if mono else
        (lambda b: 0.5 * (conv1(b[:len(b) // 2]) + conv1(b[len(b) // 2:]))))
    a = []
    wb = w.readframes(w.getnframes())
    step = w.getnchannels() * w.getsampwidth()
    for i in range(0, len(wb), step):
      a.append(conv(wb[i : i + step]))
    return a
