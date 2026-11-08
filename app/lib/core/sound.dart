import 'package:audioplayers/audioplayers.dart';

/// 应用内音效类型。
enum Sfx { check, success, stamp }

/// 应用内音效：三个本地合成短音（tools/gen_sfx.dart 产出，随包分发，不依赖网络）。
///
/// 开关由「我的-设置-音效」控制：AppStore 持久化 kSoundEffects 并同步到
/// [SoundFx.enabled]；播放失败（无音频设备/测试环境）一律静默降级。
class SoundFx {
  SoundFx._();

  static bool enabled = true;

  // 每种音效独立播放器，避免连续触发时互相截断
  static final AudioPlayer _check = AudioPlayer();
  static final AudioPlayer _success = AudioPlayer();
  static final AudioPlayer _stamp = AudioPlayer();

  static Future<void> play(Sfx type) async {
    if (!enabled) return;
    try {
      switch (type) {
        case Sfx.check:
          await _check.stop();
          await _check.play(AssetSource('sounds/check.wav'));
        case Sfx.success:
          await _success.stop();
          await _success.play(AssetSource('sounds/success.wav'));
        case Sfx.stamp:
          await _stamp.stop();
          await _stamp.play(AssetSource('sounds/stamp.wav'));
      }
    } catch (_) {
      // 音频设备不可用时静默降级，绝不影响主流程
    }
  }
}
