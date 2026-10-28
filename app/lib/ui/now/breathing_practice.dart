import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// A short, optional breathing break, independent of advice completion.
class BreathingPractice extends StatefulWidget {
  const BreathingPractice({super.key});

  @override
  State<BreathingPractice> createState() => _BreathingPracticeState();
}

class _BreathingPracticeState extends State<BreathingPractice> {
  Timer? _ticker;
  int _remaining = 60;
  bool _running = false;

  void _start() {
    _ticker?.cancel();
    setState(() {
      _remaining = 60;
      _running = true;
    });
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      } else {
        setState(() => _remaining--);
        SystemSound.play(SystemSoundType.click);
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final elapsed = 60 - _remaining;
    final guidance = _remaining == 0
        ? '结束了。留意一下身体现在的感觉。'
        : !_running
        ? '坐稳，放松肩膀。开始后跟着节奏慢慢呼吸。'
        : elapsed % 10 < 4
        ? '吸气 · 轻轻数到 4'
        : '呼气 · 慢慢数到 6';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: elapsed / 60,
                  backgroundColor: p.pillBg,
                  color: p.indigo,
                ),
                Text(
                  '$_remaining',
                  style: TextStyle(fontSize: 15, color: p.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '一分钟呼吸',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(guidance, style: TextStyle(fontSize: 11, color: p.inkSub)),
              ],
            ),
          ),
          TextButton(
            onPressed: _running ? _pause : _start,
            child: Text(
              _running
                  ? '暂停'
                  : _remaining == 60
                  ? '开始'
                  : '重来',
            ),
          ),
        ],
      ),
    );
  }
}
