// 本地合成音效生成器：离线产出 assets/sounds/ 下的三个短 WAV。
// 运行：dart run tools/gen_sfx.dart（在 app/ 目录下执行）
//
// 音色设计（全部 44.1kHz 单声道 16bit PCM，指数衰减包络，3ms 起音防爆破）：
// - check.wav   70ms  高频短促「嗒」——今日待办勾选
// - success.wav 320ms E5→A5 双音上行铃——完成建议打卡
// - stamp.wav   200ms 低频「咚」+ 起音噪声——卡内基落印完成
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 44100;

void main() {
  final dir = Directory('assets/sounds');
  dir.createSync(recursive: true);
  writeWav('assets/sounds/check.wav', synthCheck());
  writeWav('assets/sounds/success.wav', synthSuccess());
  writeWav('assets/sounds/stamp.wav', synthStamp());
  stdout.writeln('生成完成：assets/sounds/{check,success,stamp}.wav');
}

List<double> tone({
  required double freq,
  required int ms,
  required double decay,
  required double amp,
  int startMs = 0,
  double harmonic = 0,
}) {
  final totalMs = startMs + ms;
  final n = (totalMs / 1000 * sampleRate).round();
  final out = List<double>.filled(n, 0);
  for (var i = (startMs / 1000 * sampleRate).round(); i < n; i++) {
    final t = i / sampleRate;
    final local = t - startMs / 1000;
    var env = exp(-local * decay) * min(1, local / 0.003);
    final s = sin(2 * pi * freq * local) +
        harmonic * sin(2 * pi * freq * 2 * local);
    out[i] = s * env * amp;
  }
  return out;
}

List<double> noise({required int ms, required double decay, required double amp}) {
  final n = (ms / 1000 * sampleRate).round();
  final rng = Random(7);
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    out[i] = (rng.nextDouble() * 2 - 1) * exp(-t * decay) * amp;
  }
  return out;
}

List<double> mix(List<double> a, List<double> b) {
  final n = max(a.length, b.length);
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final s = (i < a.length ? a[i] : 0) + (i < b.length ? b[i] : 0);
    out[i] = s.clamp(-1.0, 1.0).toDouble();
  }
  return out;
}

List<double> synthCheck() => tone(freq: 1050, ms: 70, decay: 18, amp: 0.5);

List<double> synthSuccess() {
  final low = tone(freq: 659, ms: 160, decay: 11, amp: 0.4, harmonic: 0.25);
  final high = tone(freq: 880, ms: 240, decay: 8, amp: 0.46, startMs: 90, harmonic: 0.3);
  return mix(low, high);
}

List<double> synthStamp() => mix(
      tone(freq: 150, ms: 200, decay: 13, amp: 0.85),
      noise(ms: 25, decay: 70, amp: 0.3),
    );

void writeWav(String path, List<double> samples) {
  final dataLen = samples.length * 2;
  final bytes = BytesBuilder();
  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  u32(36 + dataLen);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(sampleRate);
  u32(sampleRate * 2);
  u16(2);
  u16(16);
  ascii('data');
  u32(dataLen);
  final pcm = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    pcm[i] = (samples[i] * 32767).round().clamp(-32768, 32767);
  }
  bytes.add(pcm.buffer.asUint8List());
  File(path).writeAsBytesSync(bytes.takeBytes());
}
