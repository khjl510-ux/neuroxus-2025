import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation_node.dart';
import '../models/cognitive_score.dart';

class CognitiveAnalysisService {
  // Using the same API key as AiService
  // TODO: Set your Gemini API Key via --dart-define=GEMINI_API_KEY=...
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY_HERE');

  // Model configuration
  final String _modelName = 'gemini-3-flash-preview';

  Future<ConversationNode> analyzeText(String text) async {
    final model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final prompt = '''
Analyze the following text based on the 6 Cognitive Scales and extract the Logic Schema.
Return the result strictly in JSON format.

Text: "$text"

Output Schema:
{
  "scores": {
    "stabilityVsAggressive": (0-100), // 0: Stability/Risk Averse, 100: Challenge/Aggressive
    "logicVsEmotion": (0-100), // 0: Logic/Data, 100: Intuition/Emotion
    "overviewVsDetail": (0-100), // 0: Macro/Overview, 100: Micro/Detail
    "consistencyVsOpenness": (0-100), // 0: Consistency/Confirmation, 100: Openness/New Info
    "utilityVsCuriosity": (0-100), // 0: Utility/Result, 100: Curiosity/Exploration
    "temporalVsPerpetual": (0-100) // 0: Temporal/Volatile, 100: Perpetual/Principle
  },
  "logicSchema": "String (e.g., Contrast, Inductive, Deductive, Paradox, Analogy, etc.)",
  "reasoning": "Brief explanation of why these scores were assigned."
}
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final String? jsonText = response.text;

      if (jsonText == null) {
        throw Exception("Empty response from AI");
      }

      final Map<String, dynamic> parsedData = jsonDecode(jsonText);
      final scoresData = parsedData['scores'];

      final cognitiveScore = CognitiveScore(
        stabilityVsAggressive: scoresData['stabilityVsAggressive'] ?? 50,
        logicVsEmotion: scoresData['logicVsEmotion'] ?? 50,
        overviewVsDetail: scoresData['overviewVsDetail'] ?? 50,
        consistencyVsOpenness: scoresData['consistencyVsOpenness'] ?? 50,
        utilityVsCuriosity: scoresData['utilityVsCuriosity'] ?? 50,
        temporalVsPerpetual: scoresData['temporalVsPerpetual'] ?? 50,
      );

      return ConversationNode(
        id: const Uuid().v4(),
        content: text,
        timestamp: DateTime.now(),
        scores: cognitiveScore,
        logicSchema: parsedData['logicSchema'] ?? 'Unknown',
        metadata: {
          'reasoning': parsedData['reasoning'] ?? 'No reasoning provided.',
        },
      );

    } catch (e) {
      print("Cognitive Analysis Failed: $e");
      // Return a neutral node in case of failure
      return ConversationNode(
        id: const Uuid().v4(),
        content: text,
        timestamp: DateTime.now(),
        scores: CognitiveScore(
          stabilityVsAggressive: 50,
          logicVsEmotion: 50,
          overviewVsDetail: 50,
          consistencyVsOpenness: 50,
          utilityVsCuriosity: 50,
          temporalVsPerpetual: 50,
        ),
        logicSchema: "Error",
        metadata: {'error': e.toString()},
      );
    }
  }
}
