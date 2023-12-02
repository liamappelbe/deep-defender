# Deep Defender

[![Build Status](https://github.com/liamappelbe/deep-defender/workflows/CI/badge.svg)](https://github.com/liamappelbe/deep-defender/actions?query=workflow%3ACI+branch%3Amain)
[![Coverage Status](https://coveralls.io/repos/github/liamappelbe/deep-defender/badge.svg?branch=main)](https://coveralls.io/github/liamappelbe/deep-defender?branch=main)

Real-time defense against deep fakes and malicious editing.

This is an experimental proof of concept app. No one should rely on this yet. I
think the core idea is sound, but I would not be surprised if this particular
implementation is possible to circumvent, since the audio fingerprinting
algorithm I'm using is pretty weak and the app itself is hacked together. I
would welcome any input from security and ML experts to make the app more
robust.

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

## SAF code format

```
[        signable data       ] [signature]
[metadata] [audio fingerprint] [signature]

[metadata] = [magic string] [version] [algorithm] [time]
magic string = "SAF"
version = Varint
algorithm = Varint
timestamp = Uint64 (big endian), ms since unix epoch
```

At the moment the version and algorithm IDs are hard-coded to 1. The signature
algorithm is ECDSA-sha256.

The fingerprint currently includes a [robust audio hash](
https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=7615c9e0df48b1353ac67d483e349abb60f3635a),
and the RMS volume of the chunk, totalling 100 bytes.

For more details, check out the [blog post](
https://medium.com/@liamappelbe/saf-codes-fighting-deep-fakes-with-crypto-2b93d41dc7be).

## Building

Use the flutter tool to build and run in the usual way:

```bash
flutter pub get
flutter run
```

And run the tests like this:

```bash
flutter test
```

## Running the verifier

The verifier has two stages. The first stage extracts all the SAF codes from the
video, and also extracts the audio track. The second stage verifies all the SAF
codes by comparing them to the audio.

The reason these stage are separate is that I couldn't find a good QR code
reading library for Dart. So the first stage is a python script. This script
depends on the pip packages ffmpeg-python, numpy, and zbar-py, so install those
first. Then run:

```bash
python3 bin/read_saf_codes.py your_video_file.mp4
```

This will output two files: `your_video_file.mp4.wav` and
`your_video_file.mp4.safcodes.txt`. Pass these to the second stage, along with
the target's public key:

```bash
dart run bin/run_verifier.dart your_video_file.mp4.wav \
    your_video_file.mp4.safcodes.txt public_key.json
```

The public key file is encoded in JWK (JSON Web Key) format, which is the same
format exported by the "Share public key" button in the app.

`run_verifier.dart` will print the validity of each SAF code, but it's currently
a very bare bones script. It needs to be updated to print a richer report.
