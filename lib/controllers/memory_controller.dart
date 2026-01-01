import 'package:uuid/uuid.dart';
import '../models/conversation_node.dart';
import '../models/cognitive_score.dart';
import '../services/cognitive_analysis_service.dart';
import '../services/ai_service.dart';
import '../services/identity_service.dart';
import 'nudge_controller.dart';

class MemoryController {
  // Singleton Pattern
  static final MemoryController _instance = MemoryController._internal();
  factory MemoryController() => _instance;
  MemoryController._internal();

  // Dependencies
  final CognitiveAnalysisService _analysisService = CognitiveAnalysisService();
  final AiService _aiService = AiService();
  final IdentityService _identityService = IdentityService();
  final NudgeController nudgeController = NudgeController(); // Public for UI access

  // L1: Working RAM (Current Session Buffer)
  final List<ConversationNode> _currentSessionBuffer = [];

  // L2: Virtual RAM (Current Session Profile)
  // Initialized with a neutral score
  CognitiveScore _currentSessionProfile = CognitiveScore(
    stabilityVsAggressive: 50,
    logicVsEmotion: 50,
    overviewVsDetail: 50,
    consistencyVsOpenness: 50,
    utilityVsCuriosity: 50,
    temporalVsPerpetual: 50,
  );

  // Getters
  List<ConversationNode> get currentSessionBuffer => List.unmodifiable(_currentSessionBuffer);
  CognitiveScore get currentSessionProfile => _currentSessionProfile;

  // Add a new message node to the session
  Future<ConversationNode> addMessage(String text) async {
    // 1. Analyze text using CognitiveAnalysisService
    final ConversationNode node = await _analysisService.analyzeText(text);

    // 2. Add to L1 Buffer
    _currentSessionBuffer.add(node);

    // 3. Update L2 Profile (Recalculate Moving Average)
    _updateSessionProfile();

    // 4. Trigger Nudge Detection (Step 4)
    // Fire and forget - don't block the return
    nudgeController.detectPotentialInsight(node);

    return node;
  }

  // Update the aggregated session profile based on the buffer
  void _updateSessionProfile() {
    if (_currentSessionBuffer.isEmpty) return;

    int stabilitySum = 0;
    int logicSum = 0;
    int overviewSum = 0;
    int consistencySum = 0;
    int utilitySum = 0;
    int temporalSum = 0;

    for (var node in _currentSessionBuffer) {
      stabilitySum += node.scores.stabilityVsAggressive;
      logicSum += node.scores.logicVsEmotion;
      overviewSum += node.scores.overviewVsDetail;
      consistencySum += node.scores.consistencyVsOpenness;
      utilitySum += node.scores.utilityVsCuriosity;
      temporalSum += node.scores.temporalVsPerpetual;
    }

    int count = _currentSessionBuffer.length;

    _currentSessionProfile = CognitiveScore(
      stabilityVsAggressive: (stabilitySum / count).round(),
      logicVsEmotion: (logicSum / count).round(),
      overviewVsDetail: (overviewSum / count).round(),
      consistencyVsOpenness: (consistencySum / count).round(),
      utilityVsCuriosity: (utilitySum / count).round(),
      temporalVsPerpetual: (temporalSum / count).round(),
    );
  }

  // End Session: Flush L1 to L3 (Supabase) and Update Identity
  Future<void> endSession() async {
    if (_currentSessionBuffer.isEmpty) return;

    // Capture state for async processing
    final List<ConversationNode> sessionNodes = List.from(_currentSessionBuffer);
    final CognitiveScore sessionProfile = _currentSessionProfile;

    // 1. Clear Memory Immediately (UI Reset)
    _currentSessionBuffer.clear();
    _currentSessionProfile = CognitiveScore(
      stabilityVsAggressive: 50,
      logicVsEmotion: 50,
      overviewVsDetail: 50,
      consistencyVsOpenness: 50,
      utilityVsCuriosity: 50,
      temporalVsPerpetual: 50,
    );

    // 2. Async Processing (Fire and Forget style, but awaited here for safety)
    try {
      // Step 2.1: Flush to L3 DB
      final tempSessionId = const Uuid().v4(); // Generate a temporary ID for this legacy controller flow
      await _aiService.flushSession(sessionNodes, sessionProfile, tempSessionId);

      // Step 2.2: Extract Identity & Update Persona (Async)
      _processIdentityUpdate(sessionNodes, sessionProfile);

      print("Session Ended. Flushed to L3. Identity update started.");
    } catch (e) {
      print("Failed to flush session: $e");
    }
  }

  // Separate async method for identity processing
  Future<void> _processIdentityUpdate(List<ConversationNode> nodes, CognitiveScore profile) async {
    try {
      final String identityDesc = await _identityService.extractUserIdentity(nodes);
      final String newInstruction = _identityService.updateInternalInstruction(identityDesc, profile);
      await _identityService.savePersona(identityDesc, newInstruction);
      print("Identity Updated: $identityDesc");
    } catch (e) {
      print("Identity Update Failed: $e");
    }
  }
}
