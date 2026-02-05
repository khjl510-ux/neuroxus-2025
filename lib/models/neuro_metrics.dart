class NeuroMetrics {
  final double scope; // 0 (Micro) - 100 (Macro)
  final double mode; // 0 (Passive) - 100 (Architect/Active)
  final double intensity; // 0 (Calm) - 100 (High Energy)

  NeuroMetrics({
    required this.scope,
    required this.mode,
    required this.intensity,
  });

  factory NeuroMetrics.fromJson(Map<String, dynamic> json) {
    return NeuroMetrics(
      scope: (json['scope'] as num?)?.toDouble() ?? 50.0,
      mode: (json['mode'] as num?)?.toDouble() ?? 50.0,
      intensity: (json['intensity'] as num?)?.toDouble() ?? 50.0,
    );
  }

  // Default neutral
  factory NeuroMetrics.neutral() {
    return NeuroMetrics(scope: 50, mode: 50, intensity: 50);
  }
}
