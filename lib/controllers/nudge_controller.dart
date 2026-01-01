import 'package:flutter/foundation.dart';
import '../models/conversation_node.dart';
import '../models/cognitive_score.dart';
import '../services/ai_service.dart';

class NudgeController extends ChangeNotifier {
  static final NudgeController _instance = NudgeController._internal();
  factory NudgeController() => _instance;
  NudgeController._internal();

  final AiService _aiService = AiService();

  // State
  bool _hasNudge = false;
  String? _nudgeContent;
  List<Map<String, dynamic>> _relatedMemories = [];

  bool get hasNudge => _hasNudge;
  String? get nudgeContent => _nudgeContent;
  List<Map<String, dynamic>> get relatedMemories => _relatedMemories;

  // Configuration
  static const double _insightThreshold = 30.0; // Distance threshold (lower is closer)
  static const double _triggerProbability = 0.4; // Scarcity factor (40% chance even if threshold met)

  // 1. Detect Potential Insight
  Future<void> detectPotentialInsight(ConversationNode currentNode) async {
    // Reset state
    _hasNudge = false;
    _nudgeContent = null;
    _relatedMemories = [];
    notifyListeners();

    try {
      // Step A: Broad Search (Vector Semantic) via AiService
      // Fetch more candidates to filter locally
      final candidates = await _aiService.searchMemoriesAsList(currentNode.content, limit: 10);

      if (candidates.isEmpty) return;

      // Step B: Filter & Rank (Structure/Score Similarity)
      List<Map<String, dynamic>> insightCandidates = [];

      for (var candidate in candidates) {
        // Parse candidate score
        final meta = candidate['metadata'] as Map<String, dynamic>? ?? {};
        if (meta['scores'] == null) continue;

        final candidateScore = CognitiveScore.fromMap(meta['scores']);
        final distance = currentNode.scores.distanceTo(candidateScore);
        final logicSchema = meta['logic_schema'] as String? ?? '';

        // Scoring Logic:
        // 1. Proximity in Cognitive Space (Distance)
        // 2. Logic Schema Match (Bonus)

        bool isStructureMatch = logicSchema.isNotEmpty && logicSchema == currentNode.logicSchema;

        // Threshold check:
        // If Logic Schema matches, we are more lenient with distance.
        // Otherwise, strict distance check.
        if (isStructureMatch || distance < _insightThreshold) {
          insightCandidates.add({
            ...candidate,
            'distance': distance,
            'isStructureMatch': isStructureMatch
          });
        }
      }

      // Step C: Scarcity & Trigger
      if (insightCandidates.isNotEmpty) {
        // Sort by relevance (Structure Match first, then Distance)
        insightCandidates.sort((a, b) {
          if (a['isStructureMatch'] && !b['isStructureMatch']) return -1;
          if (!a['isStructureMatch'] && b['isStructureMatch']) return 1;
          return (a['distance'] as double).compareTo(b['distance'] as double);
        });

        // Probabilistic Trigger (Scarcity)
        // We only trigger if random check passes, to avoid fatigue.
        // Exception: If it's a perfect structure match, we always trigger (high value).
        bool shouldTrigger = insightCandidates.first['isStructureMatch'] == true || (DateTime.now().millisecond % 100) < (_triggerProbability * 100);

        if (shouldTrigger) {
          _relatedMemories = insightCandidates.take(3).toList(); // Keep top 3 for context
          _hasNudge = true;
          // Pre-generate content or wait for user click?
          // Prompt says "generate when clicked", but we need to be ready.
          // Let's lazy load content on click, but signal is ready.
          notifyListeners();
          print("Nudge Triggered! Found ${insightCandidates.length} structural matches.");
        }
      }

    } catch (e) {
      print("Nudge Detection Failed: $e");
    }
  }

  // 2. Generate Nudge Content (On Click)
  Future<String> generateNudgeContent(ConversationNode currentNode) async {
    if (_relatedMemories.isEmpty) return "통찰을 불러오는 중 오류가 발생했습니다.";

    try {
      final topMemory = _relatedMemories.first;
      final pastContent = topMemory['content'] as String;
      final pastDate = topMemory['date'] ?? "과거";

      // Use AI to generate the connection insight
      final insight = await _aiService.generateConnectionInsight(currentNode.content, pastContent);

      _nudgeContent = insight ?? "현재의 생각과 과거의 기록($pastDate) 사이의 흥미로운 연결고리를 발견했습니다.";
      notifyListeners();

      return _nudgeContent!;
    } catch (e) {
      return "연결고리를 분석하는 데 실패했습니다.";
    }
  }

  // 3. Deep Analysis (Compare Knowledge)
  Future<String> getDeepAnalysis(String topic) async {
    if (_relatedMemories.isEmpty) return "비교할 데이터가 부족합니다.";

    // Extract titles or content sources
    List<String> sources = _relatedMemories.map((m) {
      final meta = m['metadata'] as Map<String, dynamic>? ?? {};
      return meta['source_title'] as String? ?? "Unknown Source";
    }).toSet().toList(); // Deduplicate

    if (sources.isEmpty) sources = ["Memory Log"];

    return await _aiService.compareKnowledge(sources, topic) ?? "심층 분석 결과를 생성하지 못했습니다.";
  }
}
