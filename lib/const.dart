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

const String kMagicString = "SAF";
const int kVersion = 0;
const int kAlgorithmId = 0;

const int kSampleRate = 16000;
const double kChunkOverlapFrac = 0.5;
const int kHashesPerChunk = 12;
const int kBitsPerHash = 64;
const double kHashOverlapFrac = 0.5;
const int kSamplesPerHash = 4096; // Must be a power of two.

final int kHashStride = (kSamplesPerHash * (1 - kHashOverlapFrac)).floor();
final int kChunkSize = kHashesPerChunk * kHashStride + kSamplesPerHash;
final int kChunkStride = (kChunkSize * (1 - kChunkOverlapFrac)).floor();
