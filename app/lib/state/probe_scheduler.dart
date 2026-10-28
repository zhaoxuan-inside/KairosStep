import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/advice.dart';
import '../models/probe_binding.dart';
import '../models/probe_model.dart';
import 'app_store.dart' show UserProfile;

/// 主动探测调度器模块 (Proactive Probe Scheduler)
///
/// 架构职责：
/// 1. 负责收集与注册当前画像下所有建议应该有的主动探查内容（按分类归并索引）；
/// 2. 依据规则触发通知信号：
///    - 必须的信号（Mandatory Signal：急救、突发高危）立即通知；
///    - 非必须的常规信号（Routine Signal：活动情境、身体微体征、心情关怀）进行合并通知；
/// 3. 严格控制通知频率（防打扰冷却机制、每日上限、深夜免打扰），避免过度打扰用户。
class ProbeScheduler extends ChangeNotifier {
  ProbeScheduler() {
    _startTicker();
  }

  Timer? _ticker;

  // 内部注册的探查条目表（按类别归并）
  final Map<ProbeCategory, List<Advice>> _categoryAdvices = {};
  UserProfile? _currentProfile;

  // 频次控制与防打扰状态
  DateTime? _lastRoutineProbeTime;
  int _todayProbeCount = 0;
  String _lastRecordedDay = '';
  bool _dismissedForToday = false;
  DateTime? _snoozedUntil;

  // 频率控制常量（可配置）
  static const int maxDailyRoutineProbes = 3;
  static const int minCooldownMinutes = 90;
  static const int quietHoursStart = 23; // 23:00 开始免打扰
  static const int quietHoursEnd = 7; // 07:00 结束免打扰

  // 当前等待 UI 处理的探查通知数据包
  ProbePayload? _currentPayload;
  ProbePayload? get currentPayload => _currentPayload;

  int get registeredAdviceCount =>
      _categoryAdvices.values.fold(0, (acc, list) => acc + list.length);

  void _startTicker() {
    _ticker?.cancel();
    // 每 15 秒心跳检测一次
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      checkScheduledProbes(DateTime.now());
    });
  }

  /// 注册当前活跃建议及其主动探查方式
  void registerAdvices(List<Advice> activeAdvices, UserProfile profile) {
    _currentProfile = profile;
    _categoryAdvices.clear();

    for (final a in activeAdvices) {
      final spec = AdviceProbeBindingEngine.specFor(a);
      _categoryAdvices.putIfAbsent(spec.category, () => []).add(a);
    }
  }

  /// 周期性心跳检查调度规则
  void checkScheduledProbes(DateTime now) {
    if (_currentPayload != null) return; // 已有待处理探查，不覆盖

    final todayStr = '${now.year}-${now.month}-${now.day}';
    if (_lastRecordedDay != todayStr) {
      _lastRecordedDay = todayStr;
      _todayProbeCount = 0;
      _dismissedForToday = false;
    }

    if (_dismissedForToday) return;

    // 检查稍后提醒延迟
    if (_snoozedUntil != null && now.isBefore(_snoozedUntil!)) {
      return;
    }

    // 1. 检查是否有必须立即通知的高危紧急信号（无视免打扰与限频）
    final mandatoryPayload = _checkMandatorySignals(now);
    if (mandatoryPayload != null) {
      _currentPayload = mandatoryPayload;
      notifyListeners();
      return;
    }

    // 2. 检查非必须常规信号（必须严格检查免打扰、每日上限与冷却时间）
    if (_shouldSuppressRoutine(now)) {
      return;
    }

    // 3. 按照时段生成合并探查通知
    final routinePayload = _generateRoutineProbeIfDue(now);
    if (routinePayload != null) {
      _currentPayload = routinePayload;
      _lastRoutineProbeTime = now;
      _todayProbeCount++;
      notifyListeners();
    }
  }

  /// 检查必须立即通知的紧急信号
  ProbePayload? _checkMandatorySignals(DateTime now) {
    // 检查是否有突发紧急条目在当前处于高危急救状态
    final urgentAdvices = _categoryAdvices[ProbeCategory.urgent] ?? const [];
    if (urgentAdvices.isEmpty) return null;

    // 只有在特定紧急探查被显式触发时抛出（日常默认不随意弹出紧急急救）
    return null;
  }

  /// 触发必须立即通知的紧急信号（例如通过手动测试、紧急按钮或传感器触发）
  void triggerMandatoryEmergencySignal(Advice urgentAdvice) {
    final spec = AdviceProbeBindingEngine.specFor(urgentAdvice);
    _currentPayload = ProbePayload(
      id: 'mandatory_${urgentAdvice.id}_${DateTime.now().millisecondsSinceEpoch}',
      signalLevel: ProbeSignalLevel.mandatory,
      categories: [ProbeCategory.urgent],
      title: '🚨 紧急生命安全防线预警',
      description: urgentAdvice.title,
      questions: [
        ProbeQuestion(
          id: 'q_urgent_${urgentAdvice.id}',
          category: ProbeCategory.urgent,
          title: spec.promptQuestion,
          options: [
            ProbeOption(
              key: 'urgent_confirm',
              label: '立即查看黄金急救指南',
              emoji: '⚠️',
              description: spec.responseGuidance,
              associatedAdviceIds: [urgentAdvice.id],
            ),
            ProbeOption(
              key: 'urgent_call',
              label: '紧急呼救 120 / 110',
              emoji: '📞',
              associatedAdviceIds: [urgentAdvice.id],
            ),
          ],
        ),
      ],
      boundAdvices: [urgentAdvice],
      createdAt: DateTime.now(),
      isMerged: false,
    );
    notifyListeners();
  }

  /// 判断是否需要抑制常规非必须探查
  bool _shouldSuppressRoutine(DateTime now) {
    // 规则 A: 深夜免打扰 (23:00 ~ 07:00)
    final hour = now.hour;
    if (hour >= quietHoursStart || hour < quietHoursEnd) {
      return true;
    }

    // 规则 B: 每日最大主动探查频次控制
    if (_todayProbeCount >= maxDailyRoutineProbes) {
      return true;
    }

    // 规则 C: 冷却时间控制 (两次非紧急探查至少间隔 minCooldownMinutes 分钟)
    if (_lastRoutineProbeTime != null) {
      final elapsed = now.difference(_lastRoutineProbeTime!).inMinutes;
      if (elapsed < minCooldownMinutes) {
        return true;
      }
    }

    return false;
  }

  /// 按时段聚合与合并生成非必须常规探查
  ProbePayload? _generateRoutineProbeIfDue(DateTime now) {
    final hour = now.hour;
    final minute = now.minute;

    // 探查时机窗口 1: 上午 09:30 ~ 10:00 (工作/学业情境探查)
    final isMorningSlot = (hour == 9 && minute >= 30) || (hour == 10 && minute <= 15);
    // 探查时机窗口 2: 下午 14:15 ~ 15:00 (午后身体微体征与用眼疲劳合并探查)
    final isAfternoonSlot = (hour == 14 && minute >= 15) || (hour == 15 && minute <= 0);
    // 探查时机窗口 3: 傍晚/晚间 18:30 ~ 19:30 (下班心情关照与运动/减重合并探查)
    final isEveningSlot = (hour == 18 && minute >= 30) || (hour == 19 && minute <= 30);

    if (isMorningSlot) {
      return createMorningContextProbe(now);
    } else if (isAfternoonSlot) {
      return createAfternoonBodyProbe(now);
    } else if (isEveningSlot) {
      return createEveningMoodAndActivityProbe(now);
    }

    return null;
  }

  /// 上午：合并当前活动情境探查（上班？上课？运动？）
  ProbePayload createMorningContextProbe(DateTime now) {
    final questions = <ProbeQuestion>[
      ProbeQuestion(
        id: 'q_activity_context',
        category: ProbeCategory.activity,
        title: '你现在正在做什么？',
        subtitle: 'KairosStep 会根据你的实时动作智能校准当下防线',
        options: [
          const ProbeOption(
            key: 'working',
            label: '上班办公 / 业务处理',
            emoji: '💼',
            description: '久坐提醒、颈椎腰椎减压、工位补水',
            associatedAdviceIds: [264, 401],
          ),
          const ProbeOption(
            key: 'studying',
            label: '课堂学习 / 备考自习',
            emoji: '📚',
            description: '20-20-20 视疲劳缓解、高效专注间隔',
            associatedAdviceIds: [401],
          ),
          const ProbeOption(
            key: 'exercising',
            label: '健身锻炼 / 户外运动',
            emoji: '🏃',
            description: '热身防拉伤、动态补水、手环虚高心率警惕',
            associatedAdviceIds: [474, 568],
          ),
          const ProbeOption(
            key: 'resting',
            label: '居家休息 / 调养状态',
            emoji: '🏠',
            description: '居室通风、规律作息、从容生活',
            associatedAdviceIds: [113],
          ),
          const ProbeOption(
            key: 'commuting',
            label: '通勤出行 / 在路上',
            emoji: '🚇',
            description: '注意乘车防跌撞、盲区避让',
            associatedAdviceIds: [],
          ),
        ],
      ),
    ];

    return ProbePayload(
      id: 'probe_morning_${now.millisecondsSinceEpoch}',
      signalLevel: ProbeSignalLevel.routine,
      categories: [ProbeCategory.activity],
      title: '上午情境与状态探查',
      description: '确认你当前的核心活动，让建议精准适配当下情境',
      questions: questions,
      boundAdvices: _getAdvicesForCategories([ProbeCategory.activity]),
      createdAt: now,
      isMerged: false,
    );
  }

  /// 下午：合并身体微体征与疲劳状态探查（反酸？头痛吃药？低血糖？）
  ProbePayload createAfternoonBodyProbe(DateTime now) {
    final questions = <ProbeQuestion>[
      ProbeQuestion(
        id: 'q_body_symptom',
        category: ProbeCategory.body,
        title: '今天身体感觉如何？有无以下微不适？',
        subtitle: '提早识别身体微症状，避免错误用药或延误调理',
        options: [
          const ProbeOption(
            key: 'fine',
            label: '精力充沛，状态良好',
            emoji: '✨',
            description: '保持当前良好节奏，适时起身活动',
            associatedAdviceIds: [],
          ),
          const ProbeOption(
            key: 'acid_reflux',
            label: '反酸烧心 / 胃部灼热痛',
            emoji: '🔥',
            description: '反酸烧心自买奥美拉唑需严控指征，避免掩盖器质性病变',
            associatedAdviceIds: [44],
          ),
          const ProbeOption(
            key: 'headache_pain',
            label: '头痛颈肩痛 / 想吃止痛药',
            emoji: '🤕',
            description: '止痛药每月勿超 15 天，防药物过量性头痛与胃粘膜损伤',
            associatedAdviceIds: [401],
          ),
          const ProbeOption(
            key: 'dizzy_shaky',
            label: '头晕心慌 / 疑似低血糖',
            emoji: '🌀',
            description: '立即坐下平卧，迅速补充 15~20g 糖分防摔倒跌伤',
            associatedAdviceIds: [402],
          ),
          const ProbeOption(
            key: 'eye_neck_tired',
            label: '用眼干涩 / 颈椎僵硬',
            emoji: '💻',
            description: '远眺 20 秒，做颈部后仰等长收缩抗阻放松',
            associatedAdviceIds: [],
          ),
        ],
      ),
    ];

    return ProbePayload(
      id: 'probe_afternoon_${now.millisecondsSinceEpoch}',
      signalLevel: ProbeSignalLevel.routine,
      categories: [ProbeCategory.body],
      title: '午后身体与疲劳度探查',
      description: '关照午后身体体征，守住健康安全底线',
      questions: questions,
      boundAdvices: _getAdvicesForCategories([ProbeCategory.body]),
      createdAt: now,
      isMerged: false,
    );
  }

  /// 傍晚/晚间：合并探查（心情关照 + 角色追问 + 减重/体形咨询）
  ProbePayload createEveningMoodAndActivityProbe(DateTime now) {
    final profile = _currentProfile;
    final isWorker = profile?.roles.contains('上班族') ?? true;
    final isStudent = profile?.roles.contains('学生') ?? false;

    String roleQTitle = '今日工作生活感受怎么样？';
    List<ProbeOption> roleOptions = [
      const ProbeOption(key: 'smooth', label: '推进顺畅，充实从容', emoji: '😊'),
      const ProbeOption(key: 'tired', label: '略显疲劳，有点透支', emoji: '🥱'),
      const ProbeOption(key: 'exhausted', label: '加班心累，严重内耗', emoji: '😫', associatedAdviceIds: [568, 113]),
      const ProbeOption(key: 'depressed', label: '情绪低落，提不起劲', emoji: '🌧️', associatedAdviceIds: [568, 113, 680]),
    ];

    if (isWorker) {
      roleQTitle = '下班前盘点：今日上班感受与人际如何？';
      roleOptions = [
        const ProbeOption(key: 'w_good', label: '工作高效，同事融洽', emoji: '👍'),
        const ProbeOption(key: 'w_tired', label: '会议琐碎，略有心累', emoji: '💼'),
        const ProbeOption(key: 'w_burnout', label: '严重内耗/被刁难摩擦', emoji: '🌧️', associatedAdviceIds: [568, 680]),
      ];
    } else if (isStudent) {
      roleQTitle = '晚修自习：今日学业压力与相处如何？';
      roleOptions = [
        const ProbeOption(key: 's_good', label: '学业适中，跟上节奏', emoji: '📖'),
        const ProbeOption(key: 's_stressed', label: '备考吃力，焦虑紧绷', emoji: '⚡', associatedAdviceIds: [113]),
        const ProbeOption(key: 's_lonely', label: '室友同学摩擦/略感孤单', emoji: '🌧️', associatedAdviceIds: [680]),
      ];
    }

    final questions = <ProbeQuestion>[
      ProbeQuestion(
        id: 'q_evening_mood',
        category: ProbeCategory.mood,
        title: roleQTitle,
        subtitle: '倾听内心真实感受，及时给予针对性疏导',
        options: roleOptions,
      ),
      ProbeQuestion(
        id: 'q_evening_activity',
        category: ProbeCategory.weight,
        title: '今晚是否有锻炼减重或形体管理打算？',
        subtitle: '科学看待热量消耗，避免过度量化焦虑',
        options: [
          const ProbeOption(
            key: 'rest_tonight',
            label: '今晚好好休息早点睡',
            emoji: '🛌',
            associatedAdviceIds: [113],
          ),
          const ProbeOption(
            key: 'run_workout',
            label: '去慢跑/健身减压',
            emoji: '🏃',
            description: '运动抗抑郁效应显著；别迷信手环卡路里虚高量化',
            associatedAdviceIds: [568, 474],
          ),
          const ProbeOption(
            key: 'weight_query',
            label: '有减重困惑/咨询减肥药针剂',
            emoji: '⚖️',
            description: '严格画像门禁，避免非适应症使用处方药',
            associatedAdviceIds: [333, 335, 474],
          ),
        ],
      ),
    ];

    return ProbePayload(
      id: 'probe_evening_${now.millisecondsSinceEpoch}',
      signalLevel: ProbeSignalLevel.routine,
      categories: [ProbeCategory.mood, ProbeCategory.weight],
      title: '晚间状态与心理韧性探查 (合并)',
      description: '合并关照今日心理负荷、人际感受与晚间生活安排',
      questions: questions,
      boundAdvices: _getAdvicesForCategories([ProbeCategory.mood, ProbeCategory.weight]),
      createdAt: now,
      isMerged: true,
    );
  }

  /// 用户在界面主动点击“立即探查”时，生成当前最适宜的综合探查包
  void triggerManualOnDemandProbe(DateTime now) {
    final hour = now.hour;
    ProbePayload payload;
    if (hour >= 12 && hour < 17) {
      payload = createAfternoonBodyProbe(now);
    } else if (hour >= 17) {
      payload = createEveningMoodAndActivityProbe(now);
    } else {
      payload = createMorningContextProbe(now);
    }

    _currentPayload = payload;
    notifyListeners();
  }

  List<Advice> _getAdvicesForCategories(List<ProbeCategory> categories) {
    final result = <Advice>[];
    for (final c in categories) {
      final list = _categoryAdvices[c] ?? const [];
      result.addAll(list);
    }
    return result;
  }

  /// 关闭当前探查弹窗
  void dismissCurrentPayload() {
    _currentPayload = null;
    notifyListeners();
  }

  /// 稍后提醒（推迟指定分钟数）
  void snoozeCurrentPayload({int minutes = 20}) {
    _snoozedUntil = DateTime.now().add(Duration(minutes: minutes));
    _currentPayload = null;
    notifyListeners();
  }

  /// 今日不再主动探查（用户主动选择）
  void dismissForToday() {
    _dismissedForToday = true;
    _currentPayload = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
