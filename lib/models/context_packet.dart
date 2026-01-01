
import 'dart:convert';

class ContextPacket {
  final double trustLevel;
  final String relationIdentity;
  final bool isArchitectMode;
  final List<String> noiseFilters;
  final String currentVision;
  final Map<String, dynamic> insightABC;
  final List<String> unresolvedQuestions;
  final String lastSummary;

  ContextPacket({
    required this.trustLevel,
    required this.relationIdentity,
    required this.isArchitectMode,
    required this.noiseFilters,
    required this.currentVision,
    required this.insightABC,
    required this.unresolvedQuestions,
    required this.lastSummary,
  });

  factory ContextPacket.empty() {
    return ContextPacket(
      trustLevel: 0.5,
      relationIdentity: 'Observer',
      isArchitectMode: false,
      noiseFilters: [],
      currentVision: '',
      insightABC: {},
      unresolvedQuestions: [],
      lastSummary: '',
    );
  }

  factory ContextPacket.fromJson(Map<String, dynamic> json) {
    return ContextPacket(
      trustLevel: (json['trustLevel'] as num?)?.toDouble() ?? 0.5,
      relationIdentity: json['relationIdentity'] as String? ?? 'Observer',
      isArchitectMode: json['isArchitectMode'] as bool? ?? false,
      noiseFilters: List<String>.from(json['noiseFilters'] ?? []),
      currentVision: json['currentVision'] as String? ?? '',
      insightABC: Map<String, dynamic>.from(json['insightABC'] ?? {}),
      unresolvedQuestions: List<String>.from(json['unresolvedQuestions'] ?? []),
      lastSummary: json['lastSummary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trustLevel': trustLevel,
      'relationIdentity': relationIdentity,
      'isArchitectMode': isArchitectMode,
      'noiseFilters': noiseFilters,
      'currentVision': currentVision,
      'insightABC': insightABC,
      'unresolvedQuestions': unresolvedQuestions,
      'lastSummary': lastSummary,
    };
  }
}
