class AdviceClassification {
  const AdviceClassification({
    required this.primaryTopic,
    required this.topicPaths,
    required this.domain,
    required this.lane,
  });

  final String primaryTopic;
  final List<String> topicPaths;
  final String domain;
  final String lane;

  static const laneLabels = {
    'daily': '每日计划',
    'cadence': '周期计划',
    'emergency': '紧急速查',
    'dormant': '按需储备',
  };

  factory AdviceClassification.fromJson(Map<String, dynamic> json) {
    final path = json['primaryTopic'] as String;
    final paths = (json['topicPaths'] as List).cast<String>();
    final lane = json['lane'] as String;
    if (paths.isEmpty || paths.first != path || !laneLabels.containsKey(lane)) {
      throw FormatException('Invalid advice classification: $json');
    }
    return AdviceClassification(
      primaryTopic: path,
      topicPaths: List.unmodifiable(paths),
      domain: json['domain'] as String,
      lane: lane,
    );
  }
}
