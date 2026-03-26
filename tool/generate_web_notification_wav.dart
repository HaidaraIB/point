// dart run tool/generate_web_notification_wav.dart
// يولّد WAV PCM 16-bit mono — متوافق مع كل متصفحات الويب.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 22050;
  const durationMs = 120;
  final numSamples = sampleRate * durationMs ~/ 1000;
  final dataSize = numSamples * 2;

  final out = BytesBuilder();
  void addU16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  void addI16(int v) {
    final b = ByteData(2)..setInt16(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  void addU32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  void addStr(String s) => out.add(s.codeUnits);

  addStr('RIFF');
  addU32(36 + dataSize);
  addStr('WAVE');
  addStr('fmt ');
  addU32(16);
  addU16(1);
  addU16(1);
  addU32(sampleRate);
  addU32(sampleRate * 2);
  addU16(2);
  addU16(16);
  addStr('data');
  addU32(dataSize);

  for (var i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final env = exp(-t * 18);
    final s = sin(2 * pi * 880 * t) * env * 0.4;
    var v = (s * 32767).round().clamp(-32768, 32767);
    addI16(v);
  }

  final path = 'assets/sounds/notification_web.wav';
  File(path).writeAsBytesSync(out.toBytes(), flush: true);
  // ignore: avoid_print
  print('Wrote $path (${dataSize + 44} bytes)');
}
