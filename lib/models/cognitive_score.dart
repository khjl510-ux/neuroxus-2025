import 'dart:math';

class CognitiveScore {
  final int stabilityVsAggressive; // 0 (Stable) - 100 (Aggressive)
  final int logicVsEmotion; // 0 (Logic) - 100 (Emotion)
  final int overviewVsDetail; // 0 (Overview) - 100 (Detail)
  final int consistencyVsOpenness; // 0 (Consistency) - 100 (Openness)
  final int utilityVsCuriosity; // 0 (Utility) - 100 (Curiosity)
  final int temporalVsPerpetual; // 0 (Temporal) - 100 (Perpetual)

  CognitiveScore({
    required this.stabilityVsAggressive,
    required this.logicVsEmotion,
    required this.overviewVsDetail,
    required this.consistencyVsOpenness,
    required this.utilityVsCuriosity,
    required this.temporalVsPerpetual,
  });

  Map<String, dynamic> toMap() {
    return {
      'stabilityVsAggressive': stabilityVsAggressive,
      'logicVsEmotion': logicVsEmotion,
      'overviewVsDetail': overviewVsDetail,
      'consistencyVsOpenness': consistencyVsOpenness,
      'utilityVsCuriosity': utilityVsCuriosity,
      'temporalVsPerpetual': temporalVsPerpetual,
    };
  }

  factory CognitiveScore.fromMap(Map<String, dynamic> map) {
    return CognitiveScore(
      stabilityVsAggressive: map['stabilityVsAggressive'] ?? 50,
      logicVsEmotion: map['logicVsEmotion'] ?? 50,
      overviewVsDetail: map['overviewVsDetail'] ?? 50,
      consistencyVsOpenness: map['consistencyVsOpenness'] ?? 50,
      utilityVsCuriosity: map['utilityVsCuriosity'] ?? 50,
      temporalVsPerpetual: map['temporalVsPerpetual'] ?? 50,
    );
  }

  // Calculate Euclidean Distance between two scores (0 to ~245)
  double distanceTo(CognitiveScore other) {
    return sqrt(
      pow(stabilityVsAggressive - other.stabilityVsAggressive, 2) +
      pow(logicVsEmotion - other.logicVsEmotion, 2) +
      pow(overviewVsDetail - other.overviewVsDetail, 2) +
      pow(consistencyVsOpenness - other.consistencyVsOpenness, 2) +
      pow(utilityVsCuriosity - other.utilityVsCuriosity, 2) +
      pow(temporalVsPerpetual - other.temporalVsPerpetual, 2)
    );
  }
}
