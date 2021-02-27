# Deep Defender
Real-time defense against deep fakes and malicious editing.

This is an experimental proof of concept app. No one should rely on this yet. I
think the core idea is sound, but I would not be surprised if this particular
implementation is possible to circumvent, since I hacked it together in a few
weeks. I would welcome any input from security and ML experts to make the app
more robust.

## How it works

To use the app, just run it on your phone while you're being filmed, and make
sure the screen is visible to the camera. You could prop it up on the desk in
front of you, or maybe put it in your shirt pocket.

As you speak, the app listens to what you're saying, and every second or so it
generates a fingerprint of what it hears. Then it cryptographically signs the
fingerprint with your private key and displays it as a QR code. This is called a
Signed Audio Fingerprint (SAF code).

Anyone can analyze the video to generate the audio fingerprint, and verify that
it matches the fingerprint in the SAF code. They can also verify the signature
using your public key.

## Details

The audio chunks overlap slightly to prevent attackers from inserting small bits
of audio in between the chunks. The SAF code also contains a timestamp, so sped
up or slowed down video can also be detected.

Syncing the verifier is non-trivial. To help with this, the fingerprint is
robust to small amounts of desync. Also, if you run the app you will notice
that the SAF code disappears for a short time before the next code appears (ie
there's a brief flash of white). This is designed to help syncing. The SAF code
updates happen like this:
1. A new audio segment is received, and the current time is recorded.
2. The previous SAF code is cleared.
3. The new SAF code is calculated, which takes some time.
4. The new SAF code is displayed.
The timestamp in the SAF code is the one recorded in step 1 (minus 1 second), so
since the time between step 1 and 2 should be short, the dissapearence time of
the previous SAF code can be assumed to be the same as the timestamp in the next
SAF code.

Most of the techical complexity is in generating the fingerprint. I'm using a
convolutional neural net to generate a 32 parameter embedding of the
spectrogram, but there are other possible approaches that might work:
- Auto-encoder neural net. If it worked, this would have the advantage that the
  original audio could be reconstructed for human verification.
- Use an ultra low bitrate voice compressor such as Codec 2 to store the entire
  audio chunk in the SAF code. This would also let us reconstruct the original
  audio for human verification.
- Hash of a quantized FFT. This has the advantage of being simple.
- Use longer audio segments and a speech-to-text algorithm, and store the text
  directly in the SAF code. Probably also need an embedding of the intonation,
  otherwise a malicious editor could change the tone to sound sarcastic without
  altering the SAF code.

The SAF code contains an algortihm ID, so in theory this app could support all
of the above algorithms.

An alternative approach would be to bake the SAF code into the video, assuming
you or someone you trust is doing the editing.

The app is Android only at the moment. The current state of TensorFlow support
on Flutter is very patchy, so I ended up having to roll my own integration with
the platform specific TfLite API, and I've only done this for Android. I would
welcome help to get iOS support working, as I don't own an iOS device.

## Building

Use the flutter tool to build and run in the usual way:

```
flutter pub get
flutter run
```

## SAF code format

```
[        signable data       ] [signature]
[metadata] [audio fingerprint] [signature]

[metadata] = [magic string] [version] [algorithm] [time]
magic string = "SAF"
version = Uint16
algorithm = Uint16
timestamp = Uint64

[audio fingerprint] = variable length, depending on the algorithm

[signature] = RSA/SHA-256
```

The current version is 0. At the moment there's only one fingerprinting
algorithm, with ID 0. It outputs 32 floats in the range [0, 1], so these are
quantized to 24-bit uints, yielding a 96 byte audio fingerprint. The timestamp
is ms since epoch, and marks the start of the 1 second chunk of audio that was
fingerprinted.

## ML notes
- Data set: https://www.kaggle.com/mozillaorg/common-voice
- Retrieved on 15/02/2021
- The data set was preprocessed by running embedder/clean.py on every wav file
- Then the model was trained using embedder/train.py
The embedder's task was to decide if 2 audio chunks were the same based on the
pythagorean distance between their 2 embeddings. It achieved 99.5% accuracy at
this task, but more experimentation is needed to determine how this translates
to the strength of the defense against malicious editing.
