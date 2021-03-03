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

package com.github.liamappelbe.deep_defender;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.os.AsyncTask;
import android.util.Log;
import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.plugin.common.MethodChannel.Result;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import org.tensorflow.lite.DataType;
import org.tensorflow.lite.Interpreter;
import org.tensorflow.lite.Tensor;

// Audio fingerprinting using an embedder network running in TensorFlow.
public class TfEmbedder {
  private static final String kModelAsset = "assets/embedder.tflite";
  public static final int kInputSize = 63 * 65;
  public static final int kOutputSize = 32;
  public static final int kElementSize = 4;  // Float32

  private Interpreter model;

  TfEmbedder(Context context) throws IOException {
    FlutterLoader loader = FlutterInjector.instance().flutterLoader();
    AssetFileDescriptor fd = context.getAssets().openFd(
        loader.getLookupKeyForAsset(kModelAsset));
    FileChannel fc = (new FileInputStream(fd.getFileDescriptor())).getChannel();
    MappedByteBuffer buffer = fc.map(
        FileChannel.MapMode.READ_ONLY,
        fd.getStartOffset(), fd.getDeclaredLength());
    model = new Interpreter(buffer, new Interpreter.Options());
    assert(model.getInputTensorCount() == 1);
    assert(model.getInputTensor(0).numElements() == kInputSize);
    assert(model.getOutputTensorCount() == 1);
    assert(model.getOutputTensor(0).numElements() == kOutputSize);
  }

  public void run(byte[] inputs, Result result) {
    assert(inputs.length == kElementSize * kInputSize);
    new TfEmbedderTask(inputs, result).execute();
  }

  private class TfEmbedderTask extends AsyncTask<Void, Void, Void> {
    private Result result;
    private ByteBuffer inputs;
    private FloatBuffer outputs;

    TfEmbedderTask(byte[] inputs, Result result) {
      this.result = result;
      this.outputs = FloatBuffer.allocate(TfEmbedder.kOutputSize);
      this.inputs = ByteBuffer.wrap(inputs);
    }

    protected Void doInBackground(Void... unused) {
      model.run(inputs, outputs);
      return null;
    }

    protected void onPostExecute(Void unused) {
      ByteBuffer rawOut =
          ByteBuffer.allocate(TfEmbedder.kOutputSize * TfEmbedder.kElementSize);
      for (int i = 0; i < TfEmbedder.kOutputSize; ++i) {
        rawOut.putFloat(outputs.get(i));
      }
      result.success(rawOut.array());
    }
  }
}
