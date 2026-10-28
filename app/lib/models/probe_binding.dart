import 'advice.dart';
import 'probe_model.dart';

/// 建议与主动探查方式绑定引擎
class AdviceProbeBindingEngine {
  const AdviceProbeBindingEngine._();

  /// 获取指定建议的主动探查方式规范
  static AdviceProbeSpec specFor(Advice advice) {
    // 1. 优先查核心重点建议显式表
    final explicit = _explicitBindings[advice.id];
    if (explicit != null) return explicit;

    // 2. 检查是否为突发急救或生命底线 -> urgent (mandatory)
    if (advice.isEmergencyOrIncident) {
      return AdviceProbeSpec(
        category: ProbeCategory.urgent,
        signalLevel: ProbeSignalLevel.mandatory,
        promptQuestion: '检测到突发意外或紧急求救信号，是否需要自救互救指引？',
        matchingOption: '突发紧急求救',
        targetPeriods: const ['morning', 'focus', 'afternoon', 'evening', 'night'],
        responseGuidance: '严格遵照黄金急救指引，必要时立即拨打 120/110。',
      );
    }

    // 3. 全库自动化语义归并与推断规则
    final rawText = '${advice.title} ${advice.coreAction} ${advice.facets.tags.join(" ")} ${advice.chapter}';

    // 情绪心理类
    if (advice.chapter.contains('心理') ||
        advice.chapter.contains('情绪') ||
        advice.facets.any(const ['心理', '抑郁', '焦虑', '情绪', '压力'])) {
      return AdviceProbeSpec(
        category: ProbeCategory.mood,
        signalLevel: ProbeSignalLevel.routine,
        promptQuestion: '你今天的心情与心理压力感受如何？',
        matchingOption: '压力紧绷或情绪消沉',
        targetPeriods: const ['afternoon', 'evening', 'night'],
        responseGuidance: '接纳情绪波动，通过运动、日照与倾诉打破内耗恶性循环。',
      );
    }

    // 睡眠精力类
    if (advice.facets.any(const ['睡眠', '失眠', '早睡', '熬夜', '午休', '褪黑素']) ||
        rawText.contains('睡眠') ||
        rawText.contains('失眠')) {
      return AdviceProbeSpec(
        category: ProbeCategory.sleep,
        signalLevel: ProbeSignalLevel.routine,
        promptQuestion: '今晚或近日的睡眠节律与精力状态如何？',
        matchingOption: '睡眠欠佳或作息紊乱',
        targetPeriods: const ['morning', 'evening', 'night'],
        responseGuidance: '优化卧室避光、控制午休时长、睡前远离蓝光屏幕。',
      );
    }

    // 体形体重与健身量化类
    if (advice.facets.any(const ['减重', '减肥', '体重', '体脂', '肥胖', '司美格鲁肽']) ||
        rawText.contains('减重') ||
        rawText.contains('减肥')) {
      return AdviceProbeSpec(
        category: ProbeCategory.weight,
        signalLevel: ProbeSignalLevel.routine,
        promptQuestion: '近期是否有减重、形体管理或用药辅助疑问？',
        matchingOption: '减重与身体形态管理',
        targetPeriods: const ['focus', 'afternoon', 'evening'],
        responseGuidance: '坚持热量赤字本质，警惕运动设备虚高量化与减肥药物盲目滥用。',
      );
    }

    // 活动情境：健身运动
    if (advice.facets.any(const ['运动', '健身', '跑步', '力量', '热身', '拉伸']) ||
        rawText.contains('跑步') ||
        rawText.contains('力量训练')) {
      return AdviceProbeSpec(
        category: ProbeCategory.activity,
        signalLevel: ProbeSignalLevel.routine,
        promptQuestion: '你现在是否正准备进行或处于健身运动中？',
        matchingOption: '正在健身运动',
        targetPeriods: const ['focus', 'afternoon', 'evening'],
        responseGuidance: '做好运动前后拉伸，规律补水并监测运动心率。',
      );
    }

    // 活动情境：上班办公
    if (advice.facets.any(const ['办公', '久坐', '工作', '工位', '程序员', '职场', '下班']) ||
        rawText.contains('久坐') ||
        rawText.contains('工位')) {
      return AdviceProbeSpec(
        category: ProbeCategory.activity,
        signalLevel: ProbeSignalLevel.routine,
        promptQuestion: '当前是否处于长时间伏案工作或写代码状态？',
        matchingOption: '正在上班办公',
        targetPeriods: const ['focus', 'afternoon'],
        responseGuidance: '定时站立活动，预防颈椎腰椎疲劳与腕管综合征。',
      );
    }

    // 活动情境：上课学习
    if (advice.facets.any(const ['学生', '学业', '上课', '考试', '用眼', '近视']) ||
        rawText.contains('学生') ||
        rawText.contains('上课')) {
      return AdviceProbeSpec(
        category: ProbeCategory.activity,
        signalLevel: ProbeSignalLevel.routine,
        promptQuestion: '当前是否正在上课、自习或长时间用眼备考？',
        matchingOption: '正在上课学习',
        targetPeriods: const ['morning', 'focus', 'afternoon'],
        responseGuidance: '践行 20-20-20 用眼法则，适度远眺缓解视疲劳。',
      );
    }

    // 身体微症状与日常医疗
    if (advice.chapter.contains('就医') ||
        advice.chapter.contains('病痛') ||
        advice.facets.any(const ['用药', '就医', '疼痛', '肠胃', '反酸', '牙痛', '体检'])) {
      return AdviceProbeSpec(
        category: ProbeCategory.body,
        signalLevel: ProbeSignalLevel.routine,
        promptQuestion: '今日身体是否有不适、酸痛、反酸或其他微症状？',
        matchingOption: '身体不适或用药疑问',
        targetPeriods: const ['morning', 'afternoon', 'evening'],
        responseGuidance: '遵从医嘱与药品说明书，避免滥用抗生素与超频使用止痛药。',
      );
    }

    // 默认为常规生活习惯
    return AdviceProbeSpec(
      category: ProbeCategory.lifestyle,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '日常习惯与生活底线守护检查。',
      matchingOption: '日常常规生活',
      targetPeriods: const ['morning', 'evening'],
      responseGuidance: '稳步推进习惯打卡，巩固生活确定性。',
    );
  }

  /// 核心典型建议的精准显式映射表
  static final Map<int, AdviceProbeSpec> _explicitBindings = {
    // 1. 身体症状类
    44: const AdviceProbeSpec(
      category: ProbeCategory.body,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '近期是否有反酸、烧心或胃部灼痛感？',
      matchingOption: '反酸烧心/胃部灼痛',
      targetPeriods: ['morning', 'afternoon', 'evening'],
      responseGuidance: '反酸烧心自买奥美拉唑需注意严格指征，警惕盲目长期抑酸掩盖器质性病变。',
    ),
    401: const AdviceProbeSpec(
      category: ProbeCategory.body,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '今天身体是否有头痛、关节痛或正在考虑吃止疼药？',
      matchingOption: '头痛酸痛想吃止疼药',
      targetPeriods: ['focus', 'afternoon', 'evening'],
      responseGuidance: '止疼药一个月别吃超过 15 天，超量极易诱发药物过量性头痛与消化道粘膜损伤。',
    ),
    402: const AdviceProbeSpec(
      category: ProbeCategory.body,
      signalLevel: ProbeSignalLevel.mandatory, // 低血糖头晕跌倒风险高，设为必须级强信号
      promptQuestion: '是否感到头晕、眼黑、手抖出冷汗，疑似低血糖？',
      matchingOption: '头晕手抖心慌',
      targetPeriods: ['morning', 'focus', 'afternoon', 'evening', 'night'],
      responseGuidance: '突发低血糖立即平坐平卧，迅速补充 15~20g 快速碳水化合物防摔伤摔倒。',
    ),

    // 2. 体形体重与用药门禁类
    474: const AdviceProbeSpec(
      category: ProbeCategory.weight,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '你目前是否正在减重，或正在查看手环手表的运动消耗卡路里？',
      matchingOption: '关注运动量化与减重',
      targetPeriods: ['focus', 'afternoon', 'evening'],
      responseGuidance: '不要指望手环/手表的运动量化帮你减重，减重本质取决于总体摄入与系统赤字。',
    ),
    333: const AdviceProbeSpec(
      category: ProbeCategory.weight,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '近期是否有吃减肥药或打司美格鲁肽针剂的打算？',
      matchingOption: '考虑使用减肥药或减重针',
      targetPeriods: ['afternoon', 'evening'],
      responseGuidance: '严格建立身高体重画像，非重度肥胖或明确糖尿病禁忌盲目用药。',
    ),
    335: const AdviceProbeSpec(
      category: ProbeCategory.weight,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '近期是否有吃减肥药或打司美格鲁肽针剂的打算？',
      matchingOption: '考虑使用减肥药或减重针',
      targetPeriods: ['afternoon', 'evening'],
      responseGuidance: '司美格鲁肽属于严格处方药，谨防胃肠道恶心、胰腺炎及停药反弹风险。',
    ),

    // 3. 心情与心理韧性类
    568: const AdviceProbeSpec(
      category: ProbeCategory.mood,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '今天的心情是否差到了抑郁消沉、提不起精神的程度？',
      matchingOption: '心情差到抑郁',
      targetPeriods: ['afternoon', 'evening', 'night'],
      responseGuidance: '心情差到抑郁的程度，就去走或者跑，运动抗抑郁效应显著且能打破反刍思维。',
    ),
    113: const AdviceProbeSpec(
      category: ProbeCategory.mood,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '情绪低落时，是否感到无力面对琐事？',
      matchingOption: '情绪低落提不起劲',
      targetPeriods: ['morning', 'afternoon', 'evening'],
      responseGuidance: '先做性价比最高的自救几件事：多见自然光、按时早睡、找信赖的人倾诉。',
    ),
    680: const AdviceProbeSpec(
      category: ProbeCategory.mood,
      signalLevel: ProbeSignalLevel.routine,
      promptQuestion: '感到孤独绝望，或者极度需要有人倾听陪着说话？',
      matchingOption: '孤独无助需要人倾听',
      targetPeriods: ['afternoon', 'evening', 'night'],
      responseGuidance: '拨打 12356 全国免费心理危机干预热线（青少年可拨 12355），无需独自硬扛。',
    ),

    // 4. 突发急救与高危安全类 (必须级别信号)
    422: const AdviceProbeSpec(
      category: ProbeCategory.urgent,
      signalLevel: ProbeSignalLevel.mandatory,
      promptQuestion: '疑似出现进食异物卡喉、无法发声呼吸困难？',
      matchingOption: '异物卡喉窒息',
      targetPeriods: ['morning', 'focus', 'afternoon', 'evening', 'night'],
      responseGuidance: '立即实施海姆立克急救手法，争分夺秒解除气道机械窒息。',
    ),
    423: const AdviceProbeSpec(
      category: ProbeCategory.urgent,
      signalLevel: ProbeSignalLevel.mandatory,
      promptQuestion: '出现突发胸骨后剧烈胸痛、压榨感、伴随大汗？',
      matchingOption: '剧烈胸痛压迫感',
      targetPeriods: ['morning', 'focus', 'afternoon', 'evening', 'night'],
      responseGuidance: '停止一切动作就地平卧，即刻拨打 120 急救电话，警惕急性心肌梗死。',
    ),
    424: const AdviceProbeSpec(
      category: ProbeCategory.urgent,
      signalLevel: ProbeSignalLevel.mandatory,
      promptQuestion: '出现突发面部不对称、单侧肢体无力、言语不清？',
      matchingOption: '疑似脑卒中/中风征兆',
      targetPeriods: ['morning', 'focus', 'afternoon', 'evening', 'night'],
      responseGuidance: 'FAST 原则识别中风，立刻拨打 120 并记录发病具体时间。',
    ),
  };
}
