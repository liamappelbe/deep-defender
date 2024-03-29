// Copyright 2023 The Deep Defender Authors
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

// GENERATED FILE. DO NOT EDIT. Generated with:
//   python3 test/generate_bucketer_test.py

import "package:test/test.dart";
import "test_util.dart";

main() {
  test("Bucketer", () {
    testBucketer(
      128,
      64,
      32,
      9,
      [
        0.29628010, -0.65105734, 0.37266053, -0.95791714, //
        0.64758272, -0.19119592, 0.39842510, -0.82582754, //
        0.59143438, -0.66922571, -0.72575227, -0.31586133, //
        -0.77125190, -0.51467964, -0.22897815, -0.25575214, //
        -0.18365595, -0.70706760, 0.63400779, 0.04477469, //
        -0.94847286, 0.68793588, -0.84306543, 0.74951445, //
        -0.06217569, 0.39603396, 0.47847364, 0.33251280, //
        -0.49570173, 0.82594250, 0.72085275, -0.36004950, //
        0.69115877, -0.17507664, 0.94962854, -0.37229209, //
        0.49368396, -0.86919995, 0.01730581, 0.04622377, //
        -0.63016658, -0.64368358, -0.83031526, 0.46869160, //
        0.75553768, 0.63165858, -0.61655216, 0.51093613, //
        0.76391243, -0.15366881, 0.86972082, 0.79414334, //
        -0.20291615, 0.22722275, -0.50530163, -0.21260552, //
        -0.98300816, -0.20170278, -0.74832549, -0.87516519, //
        0.55214181, 0.96139221, 0.63480086, 0.76642654, //
        0.87012798, -0.97978378, 0.77526557, 0.25750218, //
        -0.60585272, 0.37938058, 0.64724537, -0.31558376, //
        -0.54752676, 0.13948379, -0.73967822, 0.31999839, //
        0.46651135, 0.76768468, -0.74650825, 0.62567744, //
        0.66548233, -0.38554422, 0.32357816, 0.96588671, //
        0.64986468, 0.34767832, 0.76971488, -0.64852338, //
        -0.42453358, 0.91741613, 0.78744744, -0.94081699, //
        -0.28145020, -0.46864775, -0.82029084, -0.67500791, //
        0.54874177, 0.34294808, 0.83182821, 0.28328626, //
        -0.68236529, -0.72954917, 0.81985159, 0.58407981, //
        -0.03305557, -0.90241805, -0.75317074, 0.45900135, //
        -0.70022896, -0.09091853, -0.97864759, 0.57536450, //
        0.91127806, -0.11834907, -0.66142978, -0.34043068, //
        -0.56158452, 0.33511291, 0.20151918, -0.96878198, //
        0.23925880, -0.42885416, -0.51443881, 0.90733027, //
        -0.50235313, -0.53097209, -0.56260402, 0.71063414,
      ],
      [
        [
          19.79210579, 35.54684897, 5.92285711, 6.42675653, //
          32.86247219, 15.88914199, 26.10588608, 30.87768475, //
          94.35398134,
        ],
        [
          12.91652117, 80.97193665, 39.38178567, 20.05597414, //
          13.19007356, 2.45857786, 100.28537293, 22.90328806, //
          35.76309512,
        ],
        [
          12.08307150, 38.51887195, 12.49768965, 72.82077911, //
          82.03301845, 8.35980679, 64.88365338, 10.53696756, //
          22.34874580,
        ],
      ],
    );
  });
}
