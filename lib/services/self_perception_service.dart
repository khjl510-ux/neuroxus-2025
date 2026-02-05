import 'dart:math';
import '../models/neuro_metrics.dart';

class SelfPerceptionService {
  // Singleton pattern (Optional, but good for global monitoring)
  static final SelfPerceptionService _instance = SelfPerceptionService._internal();
  factory SelfPerceptionService() => _instance;
  SelfPerceptionService._internal();

  // State
  final List<Map<String, dynamic>> _executionLogs = [];
  final List<NeuroMetrics> _metricsHistory = [];
  double _rationalityScore = 50.0; // 0-100

  // Constants
  static const int _historyLimit = 100;
  static const int _latencyThresholdMs = 3000; // 3 seconds warning

  // --- 1. Rationality Score Calculation ---
  void updateRationality(NeuroMetrics metrics) {
    _metricsHistory.add(metrics);
    if (_metricsHistory.length > _historyLimit) {
      _metricsHistory.removeAt(0);
    }

    // Logic: Rationality is balanced Intensity and High Mode (Architect),
    // but not too chaotic (High Scope + High Intensity).
    // This is a heuristic formulation.

    double stability = 100 - (metrics.intensity - 50).abs(); // Closer to 50 intensity is stable?
    // Or maybe High Mode (Architect) implies higher rationality?
    // Let's assume Rationality = (Mode + Scope) / 2 scaled by inverse Intensity variance.
    // Simple heuristic:
    double baseScore = (metrics.mode * 0.6) + (metrics.scope * 0.4);

    // Smooth update (Moving Average)
    _rationalityScore = (_rationalityScore * 0.8) + (baseScore * 0.2);
  }

  // --- 2. Monitoring (Latency & Tokens) ---
  void logExecution(String methodName, int durationMs, int inputTokens, int outputTokens) {
    final log = {
      'method': methodName,
      'duration': durationMs,
      'tokens': inputTokens + outputTokens,
      'timestamp': DateTime.now(),
    };

    _executionLogs.add(log);
    if (_executionLogs.length > _historyLimit) {
      _executionLogs.removeAt(0);
    }

    // Real-time check
    if (durationMs > _latencyThresholdMs) {
      print("⚠️ [Self-Perception] Latency Alert: $methodName took ${durationMs}ms");
    }
  }

  // --- 3. Efficiency Report ---
  String generateEfficiencyReport() {
    if (_executionLogs.isEmpty) return "No execution data available.";

    double totalDuration = 0;
    int totalTokens = 0;

    for (var log in _executionLogs) {
      totalDuration += log['duration'];
      totalTokens += log['tokens'] as int;
    }

    double avgDuration = totalDuration / _executionLogs.length;

    return """
[Neuroxus Efficiency Report]
- Rationality Score: ${_rationalityScore.toStringAsFixed(1)} / 100
- Recent Executions: ${_executionLogs.length}
- Avg Latency: ${avgDuration.toStringAsFixed(0)}ms
- Total Token Usage: $totalTokens
""";
  }

  // --- 4. Refactoring Suggestion (Meta-Cognition) ---
  String suggestRefactoring() {
    // Analyze patterns in logs
    if (_executionLogs.isEmpty) return "Insufficient data for refactoring suggestions.";

    int slowCalls = _executionLogs.where((l) => l['duration'] > _latencyThresholdMs).length;
    double slowRatio = slowCalls / _executionLogs.length;

    StringBuffer suggestion = StringBuffer();
    suggestion.writeln("=== [Self-Perception] Code Optimization Proposal ===");

    if (slowRatio > 0.2) {
      suggestion.writeln("CRITICAL: High latency detected in ${slowRatio * 100}% of calls.");
      suggestion.writeln("Proposal: Implement caching for 'fetchDocuments' or optimize Vector Search 'match_threshold'.");
    } else {
      suggestion.writeln("Status: System latency is within acceptable limits.");
    }

    if (_rationalityScore < 40) {
      suggestion.writeln("OBSERVATION: Rationality Score is Low ($_rationalityScore).");
      suggestion.writeln("Proposal: Review 'AiService._updateArchitectMode' triggers. The system might be too reactive (High Intensity).");
    }

    return suggestion.toString();
  }
}
